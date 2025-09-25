import argparse
import json
import os
import warnings

import coremltools as ct
import numpy as np
import torch
from transformers import AutoModelForCausalLM
from transformers.cache_utils import Cache

warnings.filterwarnings("ignore", category=FutureWarning)


class SliceUpdateKeyValueCache(Cache):
    def __init__(self, *, shape, dtype=torch.float32):
        super().__init__()
        self.register_buffer("k", torch.zeros(shape, dtype=dtype))
        self.register_buffer("v", torch.zeros(shape, dtype=dtype))
        self.register_buffer(
            "_current_length",
            torch.zeros(shape[0], dtype=torch.int32),
            persistent=False,
        )

    def __len__(self):
        return int(self._current_length.max().item())

    def update(self, k_state, v_state, layer_idx, cache_kwargs=None):
        position = (cache_kwargs or {}).get("cache_position", None)
        if position is None:
            raise ValueError("cache_position required")
        position = torch.as_tensor(position)
        if position.ndim > 1:
            position = position.reshape(-1)
        start = int(position.min().item())
        end = int(position.max().item() + 1)
        seq_len = k_state.shape[2]
        if end - start != seq_len:
            raise ValueError(
                "cache_position must describe a contiguous range matching the incoming sequence length"
            )
        if end > self.k.shape[3]:
            raise ValueError("cache_position exceeds allocated cache size")
        self.k[layer_idx, :, : k_state.shape[1], start:end, :] = k_state
        self.v[layer_idx, :, : v_state.shape[1], start:end, :] = v_state
        current = max(int(self._current_length[layer_idx].item()), end)
        self._current_length[layer_idx] = torch.tensor(
            current,
            device=self._current_length.device,
            dtype=self._current_length.dtype,
        )
        return (
            self.k[layer_idx, :, :, :current, :],
            self.v[layer_idx, :, :, :current, :],
        )

    def get_seq_length(self, _=0):
        return int(self._current_length.max().item())


def convert(hf_model_path: str, out_prefix: str, artifacts_path: str) -> None:
    base_model = AutoModelForCausalLM.from_pretrained(
        hf_model_path,
        torch_dtype=torch.float16,
    )
    base_model.eval()

    num_layers = len(base_model.model.layers)
    num_kv_heads = base_model.config.num_key_value_heads
    head_dim = base_model.config.hidden_size // base_model.config.num_attention_heads
    batch_size, cache_ctx = 1, 256
    kv_shape = (num_layers, batch_size, num_kv_heads, cache_ctx, head_dim)

    class Wrapper(torch.nn.Module):
        def __init__(self, module: torch.nn.Module):
            super().__init__()
            self.module = module
            self.kv = SliceUpdateKeyValueCache(shape=kv_shape, dtype=torch.float16)

        @torch.no_grad()
        def forward(self, input_ids, attention_mask, cache_position):
            output = self.module(
                input_ids=input_ids,
                attention_mask=attention_mask,
                past_key_values=self.kv,
                cache_position=cache_position,
                use_cache=True,
            )
            return output.logits

    wrapper = Wrapper(base_model).eval()
    example_ids = torch.zeros((batch_size, 1), dtype=torch.int32)
    example_mask = torch.ones((batch_size, 1), dtype=torch.int32)
    example_pos = torch.tensor([0], dtype=torch.int32)

    with torch.inference_mode():
        traced = torch.jit.trace(
            wrapper,
            (example_ids, example_mask, example_pos),
            check_trace=False,
        )

    seq_dim = ct.RangeDim(lower_bound=1, upper_bound=cache_ctx, default=1)
    inputs = [
        ct.TensorType("input_ids", (batch_size, seq_dim), np.int32),
        ct.TensorType("attention_mask", (batch_size, seq_dim), np.int32),
        ct.TensorType("cache_position", (seq_dim,), np.int32),
    ]
    outputs = [ct.TensorType("logits", dtype=np.float16)]

    mlmodel = ct.convert(
        traced,
        inputs=inputs,
        outputs=outputs,
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        minimum_deployment_target=ct.target.iOS18,
        skip_model_load=True,
    )

    artifacts = []

    def save(model, suffix: str) -> None:
        filename = f"{out_prefix}-{suffix}.mlmodel"
        model.save(filename)
        artifacts.append({"file": filename, "bytes": os.path.getsize(filename)})

    save(mlmodel, "fp16")

    from coremltools.optimize.coreml import linear_quantize_weights

    int8_model = linear_quantize_weights(
        mlmodel,
        nbits=8,
        quantization_mode="linear_symmetric",
        granularity="per_channel",
    )
    save(int8_model, "int8")

    int4_model = linear_quantize_weights(
        mlmodel,
        nbits=4,
        quantization_mode="linear_symmetric",
        granularity="per_block",
        block_size=32,
    )
    save(int4_model, "int4b32")

    with open(artifacts_path, "w", encoding="utf-8") as handle:
        json.dump({"artifacts": artifacts}, handle, indent=2)
    print(
        f"Artifacts written to {artifacts_path}:",
        json.dumps(artifacts, indent=2),
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--hf_model", required=True)
    parser.add_argument("--out_prefix", required=True)
    parser.add_argument(
        "--artifacts_path",
        default="coreml_artifacts.json",
        help=(
            "Path to write coreml_artifacts.json (default: current working "
            "directory/coreml_artifacts.json)"
        ),
    )
    arguments = parser.parse_args()
    convert(arguments.hf_model, arguments.out_prefix, arguments.artifacts_path)
