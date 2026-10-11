# ProjectEVO

Personal AI assistant for Android that evolves through **memory**, **research**, **evaluation**, and on-device inference.

> Software simulation of personality only — **not** conscious or sentient.

## Features (v0.3)

- **On-device chat** via Flutter Edge AI + MediaPipe (Gemma 3 270M Instruct `.task`)
- **Honest fallback** when the model is missing or fails (replies clearly labeled)
- **Persistent memory** via SQLite (facts, summaries, research notes)
- **Research** via DuckDuckGo Instant Answer API (limited coverage; web text is untrusted)
- **Simulated personality** settings (tone variables only — not real emotions)
- **Self-evaluation** heuristics on replies
- **Safety** filters for common prompt-injection phrases
- **GitHub Actions** release APK build (arm64)

## Device target

Designed for phones such as **POCO X3 Pro (6 GB RAM)**. See `docs/MODELS.md`.

## Install APK from CI

1. Open the **Actions** tab on GitHub
2. Open the latest green **Build APK** run
3. Download artifact `projectevo-release-apk`
4. Install on your Android phone (allow unknown sources if needed)

## Enable real on-device Gemma

1. Open **Settings** in the app
2. Accept the Gemma license on Hugging Face if the model is gated, and paste a read token
3. Tap **Download & install** (~300 MB)
4. When status is **ready**, chat replies without a `⚠️ Fallback` prefix are from the local model

Model weights are **not** stored in this repository.

## Phone-friendly development

- Edit on GitHub mobile / Codespaces if needed
- Prefer CI for builds (no PC required)
- Never commit PATs, HF tokens, or API keys

## Memory disclaimer

Stored memory is **local database content**, not model-weight training.

## License

See LICENSE.
