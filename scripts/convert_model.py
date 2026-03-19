#!/usr/bin/env python3
"""
Convert all-MiniLM-L6-v2 sentence transformer to Core ML format.

Requirements (Python 3.11+ recommended):
    pip install 'coremltools>=7.2,<9.0' 'torch>=2.2,<2.8' transformers sentence-transformers

Note: Validated with coremltools 7.2 + torch 2.2 + Python 3.11.
      CRITICAL: Must use compute_precision=FLOAT32 — Float16 causes all-NaN embeddings.

Usage:
    python scripts/convert_model.py

Output:
    ios/sprinty/Resources/MiniLM.mlpackage
    ios/sprinty/Resources/vocab.txt
"""

import os
import sys
import shutil
import numpy as np

def main():
    try:
        import coremltools as ct
        import torch
        from transformers import AutoModel, AutoTokenizer
    except ImportError as e:
        print(f"Missing dependency: {e}")
        print("Install: pip install 'coremltools>=8,<9' 'torch>=2.5,<2.8' transformers sentence-transformers")
        sys.exit(1)

    model_name = "sentence-transformers/all-MiniLM-L6-v2"
    output_dir = os.path.join(os.path.dirname(__file__), "..", "ios", "sprinty", "Resources")
    os.makedirs(output_dir, exist_ok=True)

    print(f"Loading model: {model_name}")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModel.from_pretrained(model_name)
    model.eval()

    # Export vocab.txt for Swift tokenizer
    vocab_path = os.path.join(output_dir, "vocab.txt")
    vocab = tokenizer.get_vocab()
    sorted_vocab = sorted(vocab.items(), key=lambda x: x[1])
    with open(vocab_path, "w") as f:
        for token, _ in sorted_vocab:
            f.write(f"{token}\n")
    print(f"Saved vocab.txt ({len(sorted_vocab)} tokens) to {vocab_path}")

    max_seq_length = 128

    class MiniLMWrapper(torch.nn.Module):
        """Wrapper returning mean-pooled 384-dim embeddings."""
        def __init__(self, base_model):
            super().__init__()
            self.base_model = base_model

        def forward(self, input_ids, attention_mask):
            outputs = self.base_model(input_ids=input_ids, attention_mask=attention_mask)
            token_embeddings = outputs.last_hidden_state  # [1, seq, 384]
            mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
            sum_embeddings = torch.sum(token_embeddings * mask_expanded, dim=1)
            sum_mask = torch.clamp(mask_expanded.sum(dim=1), min=1e-9)
            return sum_embeddings / sum_mask  # [1, 384]

    wrapper = MiniLMWrapper(model)
    wrapper.eval()

    print("Tracing model...")
    sample = tokenizer(
        "Sample sentence for tracing.",
        padding="max_length",
        truncation=True,
        max_length=max_seq_length,
        return_tensors="pt",
    )

    with torch.no_grad():
        traced = torch.jit.trace(
            wrapper,
            (sample["input_ids"], sample["attention_mask"]),
        )

    print("Converting to Core ML (float32 precision)...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, max_seq_length), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, max_seq_length), dtype=np.int32),
        ],
        outputs=[
            ct.TensorType(name="embedding", dtype=np.float32),
        ],
        compute_precision=ct.precision.FLOAT32,
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17,
    )

    mlpackage_path = os.path.join(output_dir, "MiniLM.mlpackage")
    if os.path.exists(mlpackage_path):
        shutil.rmtree(mlpackage_path)

    mlmodel.save(mlpackage_path)
    print(f"Saved Core ML model to {mlpackage_path}")

    # Verify output
    print("\nVerification:")
    result = mlmodel.predict({
        "input_ids": sample["input_ids"].numpy().astype(np.int32),
        "attention_mask": sample["attention_mask"].numpy().astype(np.int32),
    })
    embedding = result["embedding"]
    print(f"  Embedding shape: {embedding.shape}")
    assert embedding.shape[-1] == 384, f"Expected 384 dims, got {embedding.shape[-1]}"
    print(f"  Non-zero values: {np.count_nonzero(embedding)}")

    # Model size
    total_size = sum(
        os.path.getsize(os.path.join(dp, f))
        for dp, _, fns in os.walk(mlpackage_path)
        for f in fns
    )
    print(f"  Model size: {total_size / (1024 * 1024):.1f} MB")
    print("\nDone! Model ready for iOS integration.")


if __name__ == "__main__":
    main()
