# Architecture

ProjectEVO modules:

- **UI (Flutter)** — chat, memory, research, settings
- **InferenceEngine** — replaceable; stub/Gemma placeholder
- **MemoryRepository** — SQLite facts/summaries (not weight training)
- **ResearchService** — authorized search; web text untrusted
- **PersonalityEngine** — simulated tone variables
- **EvaluationEngine** — heuristic quality checks
- **ChatOrchestrator** — memory retrieval → prompt → inference → eval

See the repository README for limitations on a 6 GB phone.
