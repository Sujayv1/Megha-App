# Workspace Rules: Flutter Optimization & Megha RAG Guidelines

1. **Optimization Guidelines**: All development, refactoring, and code generation MUST strictly follow the guidelines defined in [flutter_optimization_rules.md](file:///c:/Users/shivu/OneDrive/Desktop/plant_project/.agents/rules/flutter_optimization_rules.md).
2. **Direct RAG Integration**: RAG features connecting Chroma Cloud (`megha` database, `megharag_docs` collection) and `gemini-3.6-flash` + `gemini-embedding-001` MUST follow [flutter_rag_rules.md](file:///c:/Users/shivu/OneDrive/Desktop/plant_project/.agents/rules/flutter_rag_rules.md).

## Mandatory AI Pre-Implementation Rule
Before implementing or modifying any feature, evaluate the change against the 20 pre-implementation questions:
1. Unnecessary rebuilds prevented? (`const`, narrow scope, `RepaintBoundary`).
2. Memory leaks avoided? (Dispose controllers, streams, tickers, timers, `if (mounted)` checks).
3. CPU load optimized? (Non-blocking async, `compute()` for heavy tasks).
4. Network calls optimized? (Persistent `http.Client` pooling, debouncing, TTL caching).
5. Lists virtualized? (`SliverList.separated` / `ListView.builder`, no eager `shrinkWrap` lists).
6. Shaders optimized? (Zero-blur bypass when blur <= 0).
7. Error handling resilient? (`_safeDouble` parsing, fallback states, tight timeouts).
8. Verification complete? (`flutter analyze` -> 0 errors, 0 warnings).

