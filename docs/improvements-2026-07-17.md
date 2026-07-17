# Programming Improvements

Date: 2026-07-17

This is a senior-developer pass over the current project. The focus is programming structure, correctness, maintainability, and runtime safety rather than product features.

## Highest Priority

1. Fix the allocator lifetime bug in `init_state_allocator`.

   `main.odin:102` creates a local `mem.Arena`, initializes it, then returns `mem.arena_allocator(&arena)`. That allocator points at a stack-local arena that is invalid after the function returns. Move the arena storage into a longer-lived owner, such as application state, and destroy/free it explicitly during shutdown.

2. Stop sharing one Lua state across threads without synchronization.

   `main.odin:148` starts `start_event_loop` on another thread with the same Lua state created in `main.odin:141`. Lua states are not safe to use concurrently unless all access is serialized. Even if rendering does not currently call Lua, this design will become fragile quickly. Either keep Lua evaluation on the main thread, protect all Lua access with a mutex, or use a message queue where the file watcher only reports reload requests.

3. Replace the detached event thread with an owned lifecycle.

   The event loop in `main.odin:43` and `main.odin:84` runs forever and is never joined or signaled to stop. When the window closes, the process relies on exit cleanup rather than a controlled shutdown. Add a `running` flag, join the thread, and close file-watch resources intentionally.

4. Implement state replacement atomically.

   The current Lua path starts parsing slide data but `relua/lua.odin:36` still panics for text items, and render state only stores `slides: string` in `restate/state.odin:8`. Define a real slide model in Odin, parse Lua into a temporary model, validate it, then swap the whole render state under the mutex. Avoid mutating partially parsed state.

5. Use blocking locks or state snapshots instead of dropping frames silently.

   `reray/raylib.odin:19` uses `mutex_try_lock`; if the lock is busy, `text` remains the zero value and rendering continues with stale or empty data. Prefer taking a short lock to copy a render snapshot, then draw outside the lock. This makes rendering deterministic and avoids hiding synchronization problems.

## Correctness And Safety

6. Fix Lua table indexing.

   `relua/lua.odin:67` iterates `0..<length` and calls `lua.geti` with `i`. Lua arrays are conventionally 1-based, so index `0` will not read the first slide item. Iterate from `1..=length` or explicitly document and enforce a zero-based Lua convention.

7. Validate Lua data before dispatching.

   `handle_slide_item` assumes every item has a string `type` field. Add checks for required fields, field types, and useful error messages that include the slide key/index. This will make script authoring much easier to debug.

8. Preserve the Lua stack deliberately.

   Several Lua helper functions push/pop values manually. Add small stack discipline conventions, such as documenting expected stack effects per function or checking stack height in debug builds. Lua C API bugs are otherwise hard to localize.

9. Convert panics into recoverable errors where appropriate.

   `main.odin` and `relua/lua.odin` contain panics for normal operational failures, including file watching, Lua initialization, and TODO code paths. Panics are fine for impossible programmer errors, but file IO, script errors, missing dependencies, and unsupported script shapes should return errors and keep the editor alive when possible.

10. Replace placeholder panic/error text with actionable messages.

    Examples include `main.odin:59`, `main.odin:64`, `main.odin:80`, and `relua/lua.odin:22`. Error text should say what failed, which path/resource was involved, and the OS error when available.

11. Avoid repeated per-frame string allocation in rendering.

    `reray/raylib.odin:30` clones the displayed text to a C string every frame. For temporary text this may be acceptable, but it is still unnecessary churn. Cache C-compatible text in render state, use a fixed buffer for simple labels, or only convert when content changes.

12. Handle file watcher event coalescing and partial writes.

    Editors often save via truncate/write/rename or multiple write events. The current watcher reloads on every modify event immediately. Add debouncing and consider watching the directory as well as the file so atomic-save workflows are handled correctly.

13. Make reload behavior transactional.

    If `script.lua` has an error, `eval_script` logs the error but the state update strategy is not yet defined. Keep the previous good render state when a reload fails, and only publish the new state after full parse and validation succeeds.

## Architecture

14. Separate file watching, Lua evaluation, state parsing, and rendering.

    `main.odin` currently owns platform watching and wires directly into Lua evaluation. `relua` both exposes Lua bindings and parses state. `reray` both owns the window loop and reads shared state. Small boundaries would make the system easier to test: watcher emits reload events, Lua loader produces a parsed document, state module owns validation/swap, renderer consumes immutable snapshots.

15. Introduce an application state struct.

    Right now core resources are loose locals in `main`: Lua state, render state, allocator, event-loop context, and renderer state. An explicit `App` or `Editor` struct would make ownership, shutdown order, and cross-module dependencies clearer.

16. Define the slide/document data model before extending rendering.

    `todo.md` already points at parsing and styling. Before adding more drawing code, create typed Odin structs for document, slide, item, style, and layout inputs. That will prevent the renderer from becoming coupled to raw Lua tables.

17. Prefer immutable render snapshots.

    Rendering should ideally consume a complete snapshot for the current frame. Mutable shared state with internal strings and allocator ownership will get harder as slide data grows. Use copy-on-swap or double-buffered state so the render thread never sees half-written data.

18. Keep OS-specific watcher implementations behind one interface.

    Linux and Darwin code live inline in `start_event_loop`. Move each backend into a small platform-specific function returning common events. This will keep `main` readable and make unsupported platforms fail cleanly.

## Build And Tooling

19. Make the `Makefile` portable.

    `Makefile:14` hardcodes `/opt/homebrew/opt/lua@5.4/lib`, which is macOS/Homebrew-specific despite this workspace running on Linux. Use `pkg-config` consistently for Lua flags, or split platform-specific flags with `ODIN_OS`/environment overrides.

20. Add a development verification target.

    There is `make check`, but no single target for formatting, checking, and optionally running a smoke test. Add a `make verify` target once the project grows. It should be the command contributors run before committing.

21. Document setup and runtime requirements.

    There is no `README.md`. Add minimal instructions for dependencies, build commands, running, and how `script.lua` hot reload works. This reduces onboarding friction and records assumptions that currently only live in the code.

22. Add small tests around Lua parsing.

    The highest-value tests are not rendering tests yet. Test that valid Lua documents parse into expected Odin state, malformed documents report useful errors, and failed reloads keep the previous good state.

## Code Quality

23. Remove unused imports.

    `main.odin` imports `core:os` and `core:time` but does not use them. `relua/lua.odin` imports `core:sync` but does not use it. Keeping imports tight makes warnings and reviews cleaner.

24. Normalize naming and formatting.

    There is a mix of semicolon usage, comments with conversational placeholders, and inconsistent blank lines in Lua parsing code. Running a formatter and tightening comments would make the code easier to scan.

25. Replace TODO comments with tracked issues or precise comments.

    Comments like `this constantly reads this is not good we need poll here` and placeholder panics are useful during exploration but should become concrete tasks or targeted comments before the codebase grows.

26. Register Lua functions through a table-driven list.

    `relua/lua.odin:27` already notes this. Define a small array of `{name, proc}` registrations so adding script APIs does not require repeated push/setglobal code.

27. Avoid global runtime context where possible.

    `relua/lua.odin:17` defines `lua_ctx: runtime.Context`, and `update_state` assigns `context = lua_ctx`. Make allocator/context dependencies explicit instead. Hidden global context makes threaded behavior and testing harder to reason about.

28. Be explicit about string ownership in shared state.

    `Shared_Render_State.slides` is a `string` plus allocator, but the current code does not make ownership rules obvious. As state grows, document whether strings are borrowed, arena-owned, copied, or temp-allocated, and enforce that consistently.

## Suggested Order Of Work

1. Fix allocator ownership and Lua thread ownership first.
2. Create typed document/slide/item structs and parse Lua into a temporary document.
3. Add transactional state swap with deterministic locking/snapshots.
4. Clean up file watching lifecycle and debounce reloads.
5. Make the `Makefile` portable and add minimal `README.md` setup docs.
6. Add focused parser tests before expanding renderer features.
