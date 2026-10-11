# Memory vs training

| Memory (this app) | Fine-tuning |
|-------------------|-------------|
| SQLite rows | Model weight updates |
| Instant, on-device | Needs curated data + usually cloud GPU |
| User can delete | New model artifact + evaluation |

Saying “Remember that…” saves text. It does **not** train Gemma.
