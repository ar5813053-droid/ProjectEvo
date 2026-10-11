# Models

On-device Gemma is **not bundled**. A POCO X3 Pro (6 GB RAM) needs a small quantized model and a verified Android runtime (e.g. LiteRT-LM when available).

Steps for a future release:

1. Choose a license-compatible model ≤ device RAM budget.
2. Verify checksum after download.
3. Wire `GemmaInferenceEngine` to the native runtime.
4. Keep `StubInferenceEngine` as fallback.

Never commit multi-GB weights to Git.
