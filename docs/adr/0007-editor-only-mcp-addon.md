# Vendor the editor-only Godot MCP addon despite the no-addons rule

`addons/godot_mcp/` (the Godot Editor MCP addon, MIT, version 2026.11.04) is committed and enabled in `project.godot`, so an agent working through the Godot MCP server can inspect the open project, parse-check scripts and drive the editor without per-machine setup. It is the one exception to the README's "no addons or GDExtensions" rule, and it holds only because the addon is editor tooling: no game script, scene or test references it, and the exported game does not need it.

**Status:** accepted. Recorded on 2026-11-18.

## Consequences

- The addon's version must match the MCP server's (`uvx godot-editor-mcp doctor` checks it). Update both together and never hand-edit the vendored files.
- The plugin only connects out to `ws://127.0.0.1:9080` when the editor runs; headless test runs (`-s tests/run_tests.gd`) don't load editor plugins, so CI is unaffected.
- Its runtime probe (`MCPRuntimeProbe`) is not registered as an autoload. Live runtime and input tools need it, and registering it would make the game depend on the addon, which takes a new decision.
- Game addons and GDExtensions remain off-limits.
