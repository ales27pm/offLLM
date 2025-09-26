import os
import json
import argparse
import numpy as np
import torch
import warnings
import coremltools as ct
import coremltools.optimize as cto
from transformers import AutoModelForCausalLM, AutoConfig
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


def convert(hf_model_path: str, out_prefix: str):
    cfg = AutoConfig.from_pretrained(hf_model_path)
    base = AutoModelForCausalLM.from_pretrained(hf_model_path, torch_dtype=torch.float16)
    base.eval()

    num_layers = getattr(cfg, "num_hidden_layers", len(base.model.layers))
    num_kv = getattr(cfg, "num_key_value_heads", base.config.num_key_value_heads)
    head_dim = cfg.hidden_size // cfg.num_attention_heads
    bs, ctx = 1, 256
    kv_shape = (num_layers, bs, num_kv, ctx, head_dim)

    class Wrapper(torch.nn.Module):
        def __init__(self, m):
            super().__init__()
            self.m = m
            self.kv = SliceUpdateKeyValueCache(shape=kv_shape, dtype=torch.float16)

        @torch.no_grad()
        def forward(self, input_ids, attention_mask, cache_position):
            out = self.m(
                input_ids=input_ids,
                attention_mask=attention_mask,
                past_key_values=self.kv,
                cache_position=cache_position,
                use_cache=True,
            )
            return out.logits

    w = Wrapper(base).eval()
    ex_ids = torch.zeros((bs, 1), dtype=torch.int32)
    ex_mask = torch.ones((bs, 1), dtype=torch.int32)
    ex_pos = torch.tensor([0], dtype=torch.int32)

    with torch.inference_mode():
        traced = torch.jit.trace(w, (ex_ids, ex_mask, ex_pos), check_trace=False)

    seq = ct.RangeDim(lower_bound=1, upper_bound=ctx, default=1)
    inputs = [
        ct.TensorType("input_ids", (bs, seq), np.int32),
        ct.TensorType("attention_mask", (bs, seq), np.int32),
        ct.TensorType("cache_position", (seq,), np.int32),
    ]
    outputs = [ct.TensorType("logits", dtype=np.float16)]

    ml = ct.convert(
        traced,
        inputs=inputs,
        outputs=outputs,
        convert_to="mlprogram",
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        minimum_deployment_target=ct.target.iOS18,
        skip_model_load=True,
    )

    artifacts = []

    def save_pkg(model, suffix):
        name = f"{out_prefix}-{suffix}.mlpackage"
        model.save(name)
        artifacts.append({"file": name, "bytes": os.path.getsize(name)})

    save_pkg(ml, "fp16")

    op_cfg_8 = cto.coreml.OpLinearQuantizerConfig(mode="linear_symmetric")
    cfg_8 = cto.coreml.OptimizationConfig(global_config=op_cfg_8)
    ml_int8 = cto.coreml.linear_quantize_weights(ml, config=cfg_8)
    save_pkg(ml_int8, "int8")

    op_cfg_4 = cto.coreml.OpPalettizerConfig(mode="kmeans", nbits=4)
    cfg_4 = cto.coreml.OptimizationConfig(global_config=op_cfg_4)
    ml_int4 = cto.coreml.palettize_weights(ml, config=cfg_4)
    save_pkg(ml_int4, "int4-lut")

    with open("coreml_artifacts.json", "w") as f:
        json.dump({"artifacts": artifacts}, f, indent=2)
    print("Artifacts:", json.dumps(artifacts, indent=2))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--hf_model", required=True)
    ap.add_argument("--out_prefix", required=True)
    args = ap.parse_args()
    convert(args.hf_model, args.out_prefix)
