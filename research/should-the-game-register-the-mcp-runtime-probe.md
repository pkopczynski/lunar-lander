# Should the game register the MCP runtime probe?

Research for [#126](https://github.com/pkopczynski/lunar-lander/issues/126) (the decision [ADR 0007](../docs/adr/0007-editor-only-mcp-addon.md) defers). Checked against Godot **4.7.2-stable** source, the vendored addon `addons/godot_mcp/` (2026.11.04) and the upstream [hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp) docs, November 2026. Claims marked **(tested)** were run on the local `Godot 4.7.2.stable.official.ed1daf0bf` against a throwaway project or a copy of this repo.

Abbreviations: `S/<path>` means `https://github.com/godotengine/godot/blob/4.7.2-stable/<path>`; `A/<file>` means `addons/godot_mcp/<file>` in this repo; `U/<path>` means `https://github.com/hybridindie/godot-mcp/blob/main/<path>`.

## 1. What the probe is and what it pulls in

- `A/mcp_runtime_probe.gd` is a plain `extends Node` script, no `class_name`, no `@tool`. Its header: "Add this script as an autoload in the *consuming* game's project … It does nothing outside a debug session, so it is safe to leave enabled (it no-ops in exported/non-debug builds)."
- Its only static dependency is `const Coerce := preload("type_coerce.gd")` (`A/type_coerce.gd`, `class_name MCPTypeCoerce extends RefCounted`, no preloads of its own; it calls `load(path)` only when coercing a resource-path argument). Shipping the probe means shipping those two files, about 1 200 lines of GDScript. The editor-side files (`godot_mcp.gd`, `mcp_debugger.gd`, `command_router.gd`, …) are not referenced by the probe.
- `_ready()` always sets `process_mode = PROCESS_MODE_ALWAYS`. Everything else (`EngineDebugger.register_message_capture("godot_mcp", …)`, the output `Logger`, the `godot_mcp:ready` message) sits behind `if EngineDebugger.is_active()`. Outside a debug session the node still exists: `_process` runs every frame but returns early (no frame pending, no monitor), and `_input` returns early unless recording. So "no-op" means "idle node under `/root`", not "absent".
- The editor side finds the probe only through the debugger channel. `A/mcp_debugger.gd` sets `_probe_ready` when the game sends `godot_mcp:ready`; `A/mcp_guards.gd` `require_live_probe()` refuses runtime tools with `PRECONDITION_FAILED` / `runtime_probe` until then. Nothing looks the probe up by node name or global, so the autoload **does not need to be a singleton** (`*` prefix); a plain autoload works the same and keeps `MCPRuntimeProbe` out of GDScript's global scope.
- The probe calls `register_message_capture` in `_ready` and never unregisters it in `_exit_tree`. A second instance in the same process would try to register the same capture again. It is built to live exactly once per game process, at `/root`, i.e. as an autoload.

## 2. Does the addon register the probe itself? (option 3)

No.

- `A/godot_mcp.gd` (the `EditorPlugin`) implements only `_enter_tree`/`_exit_tree`; there is no `_enable_plugin`, `_disable_plugin` or `_build`. `_enter_tree` adds the dock, the `MCPDebugger` (`add_debugger_plugin`) and the WebSocket bridge. Nothing in the addon calls `add_autoload_singleton` for the probe.
- `A/command_router.gd` exposes `add_autoload_singleton`/`remove_autoload_singleton` only for the MCP tool `godot_resources_edit_register_autoload`, which an agent calls explicitly.
- When the probe is missing, the addon's hint says to "add it as an autoload (addons/godot_mcp/mcp_runtime_probe.gd) in the game" (`A/mcp_guards.gd`, `probe_never_connected_hint`).

## 3. Engine mechanisms for an editor-only autoload

### `override.cfg` works, and the editor never sees it

- **The game process reads `res://override.cfg`.** When a project is loaded from a folder, `ProjectSettings::_setup` loads `project.godot` and then `current_dir.path_join("override.cfg")` unless `p_ignore_override` is set ([S/core/config/project_settings.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/core/config/project_settings.cpp), `_setup`). An editor play session starts the game as a separate process with `--path <project> --remote-debug <uri> …` ([S/editor/run/editor_run.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/run/editor_run.cpp), `EditorRun::run`), so it takes this path. `OVERRIDE_ENABLED` is on unless the engine is built with `disable_overrides=yes` ([S/SConstruct](https://github.com/godotengine/godot/blob/4.7.2-stable/SConstruct)); official builds have it on.
- **Autoloads are ordinary settings there.** `_set` turns every `autoload/<Name>` key into an `AutoloadInfo`, whichever file it came from (`ProjectSettings::_set`), and `Main::start` instantiates the autoload list for any game run ([S/main/main.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp), `// autoload` block). Godot's own docs: "Any project setting can be overridden by creating a file named override.cfg in the project's root directory" ([ProjectSettings class description](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)). Modders use exactly this to inject an autoload ([godotengine/godot#71589](https://github.com/godotengine/godot/issues/71589); the one caveat there, override autoloads always load last, doesn't matter for the probe).
- **(tested)** A project with no `[autoload]` and an `override.cfg` containing `MCPRuntimeProbe="*res://probe.gd"`: a `--headless --path .` run printed `ROOT CHILDREN: ["MCPRuntimeProbe", "Main"]`. Without the file: `["Main"]`.
- **The editor ignores it, so it can't leak into `project.godot`.** `Main::setup` calls `globals->setup(project_path, main_pack, false, editor)`; the last argument is `p_ignore_override` (`S/main/main.cpp`). This came from [PR #55230 "Ignore override.cfg when in editor"](https://github.com/godotengine/godot/pull/55230), which fixed [#30912 "override.cfg gets pulled into project.godot"](https://github.com/godotengine/godot/issues/30912); the reload-on-external-change variant ([#92583](https://github.com/godotengine/godot/issues/92583)) was fixed by [#92633](https://github.com/godotengine/godot/pull/92633). Side effects: the editor's Autoload panel and the MCP tool `godot_inspection_get_project_info` won't list the probe, and the editor's own play-time reads of display settings ignore the file ([#111846](https://github.com/godotengine/godot/issues/111846), [#112688](https://github.com/godotengine/godot/issues/112688), [#123210](https://github.com/godotengine/godot/issues/123210): window size/embedding only, not autoloads). #111846 confirms the file "is properly loaded when running the game from the editor".
- **Not exported by default.** `override.cfg` is not a resource, so "export all resources" leaves it out unless a preset's *include filter* names it (`EditorExportPlatform::export_project_files`, [S/editor/export/editor_export_platform.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform.cpp)). The exported `project.binary` is written from the editor's `ProjectSettings` (`save_custom(…, custom_map, …)`), which never loaded the override, so the export carries no probe autoload. An exported game *does* read an `override.cfg` packed into the PCK or placed next to the binary, which is why the file must stay out of the export.
- **Headless `-s` runs also read it.** The test runner (`godot --headless --path . -s tests/run_tests.gd`) is a game run, not an editor run, so it loads `override.cfg` and its autoloads: `Main::start` loads autoloads `if (!game_path.is_empty() || !script.is_empty())`. **(tested)** with the override present, a `-s` SceneTree script saw `["MCPRuntimeProbe"]` under `/root`. See §6 for what that means for tests.
- `application/config/project_settings_override` (a path to another override file) does the same, but the setting itself would have to be committed in `project.godot`; it only adds indirection over `res://override.cfg`.

### Feature-tag overrides do not gate autoloads

- A key like `autoload/MCPRuntimeProbe.editor` looks like it would register the probe only where the `editor` feature is present. It doesn't: `_set` records the feature override **and** registers an autoload named after everything past `autoload/`, and the autoload list never consults `get_setting_with_override` (`S/core/config/project_settings.cpp`). **(tested)** It produced an autoload named `MCPRuntimeProbe_editor` in a plain run. Also, a game run from the editor binary reports both `editor` and `editor_runtime` features **(tested)**, and so do CI's headless test runs, so feature tags could not tell an editor play session from a test run anyway.

### Adding and removing the autoload at play time from an EditorPlugin

- `EditorPlugin.add_autoload_singleton` goes through `EditorAutoloadSettings::autoload_add`, which sets `autoload/<name>` with undo/redo and emits `autoload_changed`, which the Project Settings editor connects to `queue_save` (`S/editor/plugins/editor_plugin.cpp`, [S/editor/settings/editor_autoload_settings.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/settings/editor_autoload_settings.cpp), [S/editor/settings/project_settings_editor.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/settings/project_settings_editor.cpp)). The game process reads `project.godot` from disk, so a play-time registration has to **write `project.godot`** before every run and revert it after. That means a dirty working tree during every session, and a leftover entry whenever the editor crashes or the revert is missed. It would also need our own editor plugin, because the vendored addon must not be hand-edited (ADR 0007). `override.cfg` gets the same result with none of that.

## 4. Registering in `project.godot` and keeping it out of the export (option 2)

- **Missing script at runtime: three errors, then the game runs.** `Main::start` uses `ERR_CONTINUE_MSG` for a failed autoload load, so it skips it and continues. **(tested)** with `autoload/MCPRuntimeProbe="*res://missing/probe.gd"`, a run printed `ERROR: Attempt to open script … 'File not found'`, `ERROR: Failed loading resource`, `ERROR: Failed to instantiate an autoload, can't load from path …`, then ran the main scene and exited 0. On Web those three lines would land in the browser console on every page load. With the `*` prefix, the global `MCPRuntimeProbe` is still declared (first pass) and stays `null`.
- **Excluding the addon needs an exclude filter.** With "export selected scenes/resources", the exporter **adds every autoload and its dependencies automatically** (`// Add autoload resources and their dependencies` in `export_project_files`). The preset's `exclude_filter` is applied after that, so `addons/godot_mcp/*` would still remove them. With the default "export all resources", the whole addon (editor scripts included) is exported today too, probe or not. Whichever preset #126's follow-up or the Web export ticket adds, `addons/godot_mcp/*` belongs in its exclude filter.
- **No hook strips one setting from the exported `project.binary`.** `EditorExportPlugin` can skip files (`_export_file` + `skip()`), add features and customise resources and scenes (`_get_export_features`, `_customize_resource`, …; [S/editor/export/editor_export_plugin.h](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_plugin.h)), but no virtual edits project settings. Only a platform's C++ `get_custom_project_settings` does that (`S/editor/export/editor_export_platform.h`). Feature-tag overrides can't blank an autoload either (§3). So option 2 always ships the `autoload/` key; the only choice is between shipping the two probe scripts (inert in a release build: no debugger, so `is_active()` is false) and shipping three errors per launch.
- Option 2 also puts the probe into CI's test runs, exactly as §6 describes for a committed `override.cfg`.

## 5. Registering from game code in debug builds (option 4)

- It would be something like `if EngineDebugger.is_active(): get_tree().root.add_child.call_deferred(load("res://addons/godot_mcp/mcp_runtime_probe.gd").new())` in a game script, once per process. It must not go under the main scene: ADR 0003 reloads the scene on restart, and a second probe would re-register the debugger capture (§1).
- Against ADR 0007 it is the worst fit: the ADR's premise is "no game script, scene or test references it", and README says "game code never depends on it". A `load("res://addons/…")` string in game code is exactly that dependency, even if it is dead in release. It also means the game must survive the addon being absent (guard with `ResourceLoader.exists`), and an export filter would still be needed to drop the files.
- `OS.is_debug_build()` is the wrong gate: CI's headless test runs use a debug (editor) binary. `EngineDebugger.is_active()` is the right one (true only with `--remote-debug`, which editor play sessions pass), so tests would be unaffected.
- What it buys over `override.cfg`: nothing an agent needs. Both register the probe only for editor runs; option 4 just moves the switch into game code.

## 6. Effect on the headless test runner

- CI runs `godot --headless --path . --fixed-fps 60 -s tests/run_tests.gd` (`.github/workflows/test.yml`), with no `--remote-debug`, so `EngineDebugger.is_active()` is false and the probe never registers its capture or `Logger`. ADR 0007's "headless test runs don't load editor plugins" stays true; but **autoloads are not editor plugins**, and a `-s` run loads them (§3). Any option that registers the probe where CI can see it (option 2, or a committed `override.cfg`) adds one idle `PROCESS_MODE_ALWAYS` node to `/root` in every test run.
- Tests reach nodes through `main()` and fixed paths under it (`tests/scene_test.gd`, `test_*.gd`), never `/root`'s children, and the runner counts logged errors with its own `Logger` (`tests/run_tests.gd`). An idle probe logs nothing.
- **(tested)** On a copy of `main` at `be589e3` with an `override.cfg` registering the real probe (`*res://addons/godot_mcp/mcp_runtime_probe.gd`), the full suite ran with CI's command: `354 passed, 0 failed`, exit 0, no `ERROR` lines, 4 min 18 s on a laptop. A plain (non-`*`) entry also registers the node under `/root` (tested on the throwaway project).
- Not tested: an actual editor play session with the probe connected (needs the GUI editor). The source path is the same as the headless `--path` run plus `--remote-debug`.
- A gitignored `override.cfg` keeps CI unchanged: CI checks out a clean tree. Locally, it also applies to test and `tools/capture.gd` runs on the machine that has it, with the same idle-node effect.

## 7. What upstream recommends

- Upstream treats the probe as an opt-in autoload in `project.godot` and says nothing about exports: "A runtime probe (`mcp_runtime_probe.gd`) that you add as an autoload in your game's project. It runs in the game, no-ops outside a debug session, and is safe to leave enabled" ([U/docs/site/architecture/addon.md](https://github.com/hybridindie/godot-mcp/blob/main/docs/site/architecture/addon.md)); the same in [U/docs/architecture.md](https://github.com/hybridindie/godot-mcp/blob/main/docs/architecture.md) ("the consuming project opts in by adding … as an autoload"), the tutorial (`godot_resources_edit_register_autoload(name="MCPRuntimeProbe", …)`, "safe to leave enabled permanently", [U/docs/tutorial.md](https://github.com/hybridindie/godot-mcp/blob/main/docs/tutorial.md)) and the example project, which has `MCPRuntimeProbe="*res://addons/godot_mcp/mcp_runtime_probe.gd"` in `[autoload]` ([U/examples/vampire/project.godot](https://github.com/hybridindie/godot-mcp/blob/main/examples/vampire/project.godot)).
- Upstream's play-test skill and server prompts tell the agent to check `godot_inspection_get_project_info()` for `MCPRuntimeProbe` and, if missing, **register it with `godot_resources_edit_register_autoload`** ([U/skills/godot-playtest-and-debug/SKILL.md](https://github.com/hybridindie/godot-mcp/blob/main/skills/godot-playtest-and-debug/SKILL.md) step 2, [U/mcp_server/prompts/prompts.py](https://github.com/hybridindie/godot-mcp/blob/main/mcp_server/prompts/prompts.py)). Because the editor ignores `override.cfg`, that check reports the probe as missing even when it is registered through the override, and following the skill would write it into `project.godot`. Any option other than 2 needs a README line telling agents not to do that, and to confirm the probe with the dock's "(probe connected)" or a runtime tool instead.
- No upstream issue covers export exclusion or `override.cfg` (searched the issues for "override.cfg", "probe autoload export", "probe register automatically": no results).

## Recommendation

**Option 3, as a committed `res://override.cfg`** holding only

```ini
[autoload]

MCPRuntimeProbe="res://addons/godot_mcp/mcp_runtime_probe.gd"
```

(no `*`, so no global name any game script could start using).

Why:

- `project.godot` stays without autoloads, as `docs/architecture/overview.md` and the README's "no autoload" rule describe. The editor never loads the file, so it can't leak into `project.godot`, and the export leaves it out unless someone adds it to an include filter.
- No game script, scene or test references the addon, so ADR 0007's core premise holds. Every editor play session (and the MCP `play_scene` tools) gets the probe with no per-machine setup, including in fresh clones and agent worktrees.
- Option 2 needs an export filter *and* still ships the autoload key: errors on every Web load, or the scripts. Option 4 breaks "game code never depends on it". Play-time registration by a plugin churns `project.godot`. Feature tags don't gate autoloads.

Costs to accept, and the variant if they're unwelcome:

- CI's test runs load the probe as an idle node (§6). If that is unwanted, **gitignore `override.cfg` instead** and give the README a one-line way to create it. CI is then untouched, at the price of per-checkout setup (agents in fresh worktrees would have to create it).
- A future Web export preset must keep `override.cfg` out of its include filter, and should exclude `addons/godot_mcp/*` anyway (today's default would export the whole addon).
- README's MCP line must change: runtime tools work, and agents must **not** register the probe via `godot_resources_edit_register_autoload` even though `get_project_info` won't list it (§7).

**ADR candidate:** yes. This amends ADR 0007: its consequence "Its runtime probe … is not registered as an autoload" becomes "registered for game runs through `res://override.cfg`, never in `project.godot` or the export", and "headless test runs don't load editor plugins, so CI is unaffected" gains "but they do load the probe as an idle autoload" (committed variant only). README's MCP bullet and file index (a new top-level `override.cfg`) need updating in the same PR.
