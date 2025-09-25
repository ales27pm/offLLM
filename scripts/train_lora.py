import argparse
import json
import os

import torch
from datasets import load_dataset
from peft import LoraConfig, get_peft_model, prepare_model_for_kbit_training
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    DataCollatorForLanguageModeling,
    Trainer,
    TrainingArguments,
)


def format_example(example: dict) -> str:
    system_prompt = (
        "You are an assistant that decides when to call tools. If a tool is needed, "
        "output JSON 'tool_call' then 'final_answer'."
    )
    user_prompt = (
        "INSTRUCTION:\n{instruction}\nCONTEXT:\n{context}\nTOOL_SCHEMA:\n{schema}".format(
            instruction=example.get("instruction", ""),
            context=example.get("context", ""),
            schema=example.get("tool_schema", ""),
        )
    )
    tool_call = json.dumps(example.get("expected_tool_call", {}), ensure_ascii=False)
    assistant = (
        "tool_call: {tool}\nfinal_answer: {answer}".format(
            tool=tool_call,
            answer=example.get("expected_answer", ""),
        )
    )
    return f"<s>[SYSTEM]{system_prompt}\n[USER]{user_prompt}\n[ASSISTANT]{assistant}</s>"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base_model", required=True)
    parser.add_argument("--train_file", required=True)
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--max_steps", type=int, default=50)
    args = parser.parse_args()

    if not os.path.isfile(args.train_file):
        raise FileNotFoundError(f"Dataset not found: {args.train_file}")

    tokenizer = AutoTokenizer.from_pretrained(args.base_model, use_fast=True)
    tokenizer.pad_token = tokenizer.eos_token

    dataset = load_dataset("json", data_files=args.train_file, split="train")

    def _validate(record: dict) -> dict:
        if {
            "instruction",
            "expected_tool_call",
            "expected_answer",
        } - record.keys():
            raise ValueError(
                "Each JSONL record must include 'instruction', 'expected_tool_call', and 'expected_answer'."
            )
        return record

    dataset = dataset.map(_validate)
    dataset = dataset.map(lambda record: {"text": format_example(record)})

    model = AutoModelForCausalLM.from_pretrained(
        args.base_model,
        torch_dtype="auto",
        device_map=None,
    )
    model = prepare_model_for_kbit_training(model)

    lora_config = LoraConfig(
        r=8,
        lora_alpha=16,
        target_modules=[
            "q_proj",
            "k_proj",
            "v_proj",
            "o_proj",
            "gate_proj",
            "up_proj",
            "down_proj",
        ],
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
    )
    model = get_peft_model(model, lora_config)

    def tokenize_batch(batch: dict) -> dict:
        return tokenizer(
            batch["text"],
            truncation=True,
            max_length=1024,
            padding="max_length",
        )

    tokenized_dataset = dataset.map(
        tokenize_batch,
        batched=True,
        remove_columns=dataset.column_names,
    )
    collator = DataCollatorForLanguageModeling(tokenizer, mlm=False)

    training_args = TrainingArguments(
        output_dir=args.output_dir,
        per_device_train_batch_size=1,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        warmup_steps=5,
        max_steps=args.max_steps,
        fp16=False,
        bf16=False,
        logging_steps=5,
        save_steps=args.max_steps,
        save_total_limit=1,
        report_to=[],
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_dataset,
        data_collator=collator,
    )
    trainer.train()
    model.save_pretrained(args.output_dir)
    tokenizer.save_pretrained(args.output_dir)


if __name__ == "__main__":
    main()
