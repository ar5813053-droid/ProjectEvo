# ProjectEVO

Personal AI assistant for Android that evolves through **memory**, **research**, **evaluation**, and controlled updates.

> Software simulation of personality only — **not** conscious or sentient.

## Features (v0.1)

- **Chat** with a replaceable inference backend (honest stub until a small on-device model is configured)
- **Persistent memory** via SQLite (facts, summaries, research notes)
- **Research** via DuckDuckGo Instant Answer API (limited coverage; web text is untrusted)
- **Simulated personality** settings (tone variables)
- **Self-evaluation** heuristics on replies
- **Safety** filters for common prompt-injection phrases
- **GitHub Actions** release APK build

## Device target

Designed for phones such as **POCO X3 Pro (6 GB RAM)**. Full-size Gemma is not practical on-device; see `docs/MODELS.md`.

## Install APK from CI

1. Open the **Actions** tab on GitHub
2. Open the latest green **Build APK** run
3. Download artifact `projectevo-release-apk`
4. Install on your Android phone (allow unknown sources if needed)

## Phone-friendly development

- Edit on GitHub mobile / Codespaces if needed
- Prefer CI for builds (no PC required)
- Never commit PATs or API keys

## Memory disclaimer

Stored memory is **local database content**, not model-weight training.

## License

See LICENSE.
