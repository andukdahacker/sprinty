# Story 1.7: sqlite-vec & Embedding Spike — Benchmark Results

**Date:** 2026-03-18
**Platform:** iOS Simulator (ARM64 Mac, Apple M-series)
**Note:** Simulator numbers are conservative. Physical device will be faster (Neural Engine for inference, optimized storage I/O).

## Components Validated

| Component | Version | Status |
|---|---|---|
| sqlite-vec | v0.0.14 (via SQLiteVecKit local package) | Working |
| GRDB | v7.10.0 | Compatible (separate connections) |
| all-MiniLM-L6-v2 | Core ML (float32, 85.8MB) | Working |
| WordPiece tokenizer | Custom Swift (~100 lines) | Working |

## Vector Search Performance (sqlite-vec)

### Insert Latency

| Vectors | Total Time | Per Vector |
|---|---|---|
| 1,000 | 0.763s | 0.763ms |
| 5,000 | 3.923s | 0.785ms |
| 10,000 | 6.209s | 0.621ms |

### Query Latency (Top-5 Cosine Similarity)

| Vectors | Avg Query Time | NFR5 (<500ms) |
|---|---|---|
| 1,000 | 2.5ms | PASS |
| 5,000 | 9.9ms | PASS |
| 10,000 | 17.7ms | PASS |

### Memory Usage (Approximate)

| Vectors | Memory Delta |
|---|---|
| 1,000 | ~0 MB (within noise) |
| 5,000 | ~6.5 MB |
| 10,000 | ~30.6 MB |

## Embedding Model Performance

| Metric | Value |
|---|---|
| Model size | 85.8 MB (float32 mlpackage) |
| Compiled model size | ~43 MB (mlmodelc) |
| Embedding dimensions | 384 |
| Inference time (Simulator) | ~100ms per text |
| Vocab size | 30,522 tokens |
| Max sequence length | 128 tokens |
| Semantic similarity | Verified (similar > dissimilar) |

## Go/No-Go Decision

### **GO** — Proceed with sqlite-vec + Core ML embedding pipeline

**Rationale:**
- Query latency at 10K vectors: **17.7ms** (28x under the 500ms NFR5 threshold)
- Linear scaling from 1K→10K suggests viability well beyond 10K
- Memory footprint at 10K: ~30MB — acceptable for iOS
- Embedding model produces semantically meaningful vectors
- sqlite-vec integrates cleanly with GRDB via separate connections (Option 1)

### Key Constraints Discovered

1. **GRDB + sqlite-vec coexistence:** Both bundle sqlite3.c. Resolved via local `SQLiteVecKit` package with opaque C wrapper API that hides internal SQLite headers from GRDB's module map
2. **Core ML float32 required:** Float16 conversion produces `overflow in cast` → all-NaN embeddings. Must use `compute_precision=FLOAT32` in coremltools. This doubles model size (~86MB vs ~43MB)
3. **Model conversion toolchain:** Requires Python 3.11 + coremltools 7.2 + torch 2.2 (newer versions have incompatibilities)
4. **Tokenization:** Implemented Option B (minimal WordPiece tokenizer in Swift with bundled vocab.txt). Works correctly for spike; production may benefit from swift-transformers for edge cases

### Recommendations for Story 3.2

- Use the `VectorSearchProtocol` and `EmbeddingServiceProtocol` as production foundations
- Consider implementing batch insert for ConversationSummary embeddings (currently ~0.7ms/insert)
- The dual-storage pattern (GRDB for metadata + sqlite-vec virtual table for vectors) is validated
- Investigate Float16 model issue further — 86MB model size is large for iOS bundle
- If Float16 fix is found, model size drops to ~43MB which is more acceptable
