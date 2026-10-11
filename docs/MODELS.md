# On-device models (ProjectEVO)

## Chosen model (v0.3)

| Field | Value |
|-------|--------|
| **Name** | Gemma 3 270M Instruct (q8) |
| **Format** | MediaPipe `.task` |
| **Approx. download** | ~300 MB |
| **Runtime** | `flutter_edge_ai` + `flutter_edge_ai_mediapipe` |
| **ModelType** | `ModelType.gemmaIt` |
| **Host** | [litert-community/gemma-3-270m-it](https://huggingface.co/litert-community/gemma-3-270m-it) |
| **File** | `gemma3-270m-it-q8.task` |
| **License** | Gemma Terms of Use (accept on Hugging Face if gated) |
| **Target device** | POCO X3 Pro class (6 GB RAM), Android 13+, arm64 |

### Why this model

- Smallest official instruction-tuned Gemma 3 variant shipped as a MediaPipe task for mobile.
- Far more likely to load without OOM on 6 GB phones than Gemma 3 1B or Gemma 4 E2B.
- Quality is limited (270M params) — expect short, simple answers, not frontier-level reasoning.

### Not claimed

- Real-device inference has **not** been verified on your specific POCO X3 Pro in this CI environment.
- Web research, SQLite memory, and personality settings **do not** change model weights.
- Fallback stub replies are always prefixed with `⚠️ Fallback` when the real model is unavailable.

## Install flow (on phone)

1. Install the release APK from GitHub Actions artifact `projectevo-release-apk`.
2. Open **Settings**.
3. If the Hugging Face repo is gated: create a free HF account, accept the Gemma license on the model page, create a read token, paste it into Settings (stored only in secure storage).
4. Tap **Download & install** (~300 MB; needs Wi‑Fi and free storage).
5. Wait until phase shows **ready**.
6. Return to **Chat** and send a message. Replies without the `⚠️ Fallback` prefix come from the on-device model.

## Runtime notes

- Model files live in app storage managed by Flutter Edge AI — **not** in the Git repository.
- The engine keeps the model loaded across messages; it is closed on engine dispose.
- Generation runs off the UI isolate path provided by the plugin; failures fall back to the labeled stub.
- `minSdk` is 26; APK is arm64-only to reduce size.

## Alternatives (future)

| Model | Size | Notes |
|-------|------|--------|
| Gemma 3 1B IT `.task` | ~0.5 GB | Better quality; higher RAM risk on 6 GB |
| Qwen3 0.6B `.litertlm` | ~586 MB | Needs `flutter_edge_ai_litertlm`, minSdk 30 |
| Gemma 4 E2B | ~2.4 GB | Too large for 6 GB class phones |
