# Master Flutter Industry-Level Optimization Rule

Before building, modifying, or reviewing any feature or code in this Flutter application, ALWAYS enforce the following 30-point industry-level optimization checklist and decision model.

---

## Core Execution Model (Mandatory Pre-Implementation Check)

Before implementing any feature, ask:

1. **Will this cause unnecessary rebuilds?** (Use `const`, narrow scopes, `RepaintBoundary`, `ValueListenableBuilder`/fine-grained state).
2. **Will this increase memory usage?** (Dispose controllers, streams, animation tickers, timers, avoid retaining large lists/images).
3. **Is this CPU-intensive?** (Avoid heavy calculations inside `build()`, use `compute`/isolates for heavy JSON/data transformations).
4. **Is this doing unnecessary network work?** (Reuse persistent `http.Client`, use in-memory TTL caching, debounce search).
5. **Is this doing unnecessary database/storage work?** (Avoid reading storage inside `build()`, cache read data).
6. **Can this be lazy-loaded?** (Use `SliverList.separated` / `ListView.builder` / `GridView.builder` instead of `shrinkWrap` eager lists).
7. **Can this be cached?** (In-memory TTL cache for API data, SharedPreferences for persistent state).
8. **Can this be paginated?** (Fetch data in batches instead of loading thousands of items at once).
9. **Can this work happen asynchronously?** (Never block main UI isolate thread).
10. **Does this need to happen immediately?** (Defer non-critical startup tasks & background initializations).
11. **Will this scale to 10x the current data?** (Design schemas, lists, and state models for scale).
12. **Will this work on a low-end device?** (Bypass heavy `BackdropFilter` shaders when blur <= 0, isolate paint subtrees).
13. **Will this work on slow networks?** (Set tight timeouts, handle retry/fallbacks gracefully, display offline states).
14. **Does this increase app size?** (Remove unused assets/packages, compress images).
15. **Does this introduce an unnecessary dependency?** (Prefer standard library or mature packages).
16. **Is this secure?** (No hardcoded secrets, use HTTPS, validate data safely).
17. **Is this testable?** (Separate business logic from UI widgets).
18. **Is this accessible?** (Sufficient contrast, touch targets, screen reader labels).
19. **Is this responsive across screen sizes?** (Use flexible layouts, handle soft keyboard `viewInsets`).
20. **Can I measure and verify the performance impact?** (Run `flutter analyze`, test in profile mode).

---

## 30 Master Optimization Pillars

### 1. Architecture
* Keep UI, business logic, services, and models strictly separated.
* Keep API/database logic completely out of UI widgets.
* Keep features modular, scalable, and maintainable.

### 2. Widget Performance
* Always use `const` constructors wherever possible.
* Keep `build()` methods lightweight; never perform expensive operations inside `build()`.
* Break large widget trees into small, isolated reusable widgets.
* Rebuild only the smallest portion of the UI that changes.

### 3. State Management
* Use fine-grained state updates to avoid full-screen rebuilds.
* Dispose all state, listeners, controllers, and subscriptions properly when widgets unmount.
* Keep transient UI state separate from business logic.

### 4. List Performance
* Always use `SliverList.separated`, `ListView.builder`, or `GridView.builder` for collections.
* Never use eager `ListView(shrinkWrap: true)` inside scrollable viewports for large lists.
* Use pagination for large datasets.
* Wrap list items in `RepaintBoundary` to isolate list scrolling repaints.

### 5. Image & Asset Optimization
* Never load high-res images unnecessarily; use appropriate dimensions (`cacheWidth`/`cacheHeight`).
* Use WebP or compressed formats.
* Provide fallback `errorBuilder` and placeholder indicators for all remote/asset media.

### 6. Memory Management
* Always dispose `TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode`, `StreamSubscription`, and `Timer` in `dispose()`.
* Avoid unbounded caches or retaining unused large objects globally.

### 7. CPU / Heavy Computation
* Never block the main UI thread with expensive calculations.
* Use `compute()` or background Isolates for heavy parsing or data crunching.

### 8. UI Rendering
* Isolate subtrees with `RepaintBoundary` where layout or animation repaints occur.
* Avoid excessive `BackdropFilter` blur shaders on low-end hardware; bypass when blur <= 0.
* Avoid unnecessary opacity layers or complex nested clipping.

### 9. Animation
* Keep animations lightweight using `AnimatedBuilder`, implicit animations, or isolated tickers.
* Avoid rebuilding large widget subtrees during every animation frame.

### 10. Network Optimization
* Reuse persistent `http.Client` singletons for connection pooling (Keep-Alive TCP).
* Debounce search inputs to prevent API hammering.
* Implement strict timeouts (e.g. 8–10s) and fallback mechanisms for poor network conditions.
* Use in-memory TTL caching for repeated network calls.

### 11. API Design & Data Parsing
* Use safe double/int/string parsers (`_safeDouble`) to prevent `TypeError` when handling API responses.
* Handle missing, null, or malformed fields gracefully.

### 12. Database & Local Storage
* Avoid querying storage inside `build()`.
* Read local storage asynchronously and cache in-memory during session lifecycle.

### 13. Caching Policy
* Cache expensive or static data with clear expiration rules (TTL).
* Invalidate stale cache appropriately without blocking UI.

### 14. Startup Performance
* Defer non-critical SDK, analytics, or service initializations after time-to-first-frame.

### 15. Navigation
* Avoid reloading expensive data on every screen focus unless required.
* Use smooth page transitions without unhandled route stack leaks.

### 16. App Size & Dependencies
* Regularly audit dependencies; avoid multiple packages solving the same problem.
* Keep assets compressed.

### 17. Async Programming
* Use non-blocking async/await.
* Handle lifecycle changes to avoid calling `setState` on unmounted widgets (`if (mounted)` checks).

### 18. Error Handling & Resilience
* Wrap all async calls in try-catch blocks with clear fallback user feedback.
* Never expose raw technical stack traces to end users.

### 19. Security
* Never hardcode secrets or private API keys in client-side code.
* Enforce HTTPS for all external API endpoints.

### 20. Production Logging
* Strip verbose debug logs in production builds.

### 21. Responsive & Adaptive UI
* Handle soft keyboard insets (`MediaQuery.of(context).viewInsets.bottom`) in modals/forms.
* Use flexible, scrollable containers to prevent pixel overflow errors on small screens.

### 22. Verification
* Always verify code quality with `flutter analyze` (target: **0 errors, 0 warnings**).
