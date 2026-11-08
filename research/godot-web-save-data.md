# How Godot web builds save data

Research for [#89](https://github.com/pkopczynski/lunar-lander/issues/89) (map [#87](https://github.com/pkopczynski/lunar-lander/issues/87)). Checked against Godot **4.7.2-stable** source and the 4.7 stable docs, November 2026.

Abbreviations: `S/<path>` means `https://github.com/godotengine/godot/blob/4.7.2-stable/<path>`.

## 1. Where `user://` lives on the Web

- On Web, `user://` "will refer to a virtual filesystem stored on the device via IndexedDB" ([Godot docs: File paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)).
- In detail, the engine runs on Emscripten's in-memory filesystem (MEMFS). The loader mounts Emscripten's **IDBFS** at `/userfs` (`persistentPaths: ['/userfs']` in [S/platform/web/js/engine/config.js](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/engine/config.js)). At startup `GodotFS.init` calls `FS.syncfs(true, …)`, which copies everything from IndexedDB into memory before the game starts. If that fails, the log prints `IndexedDB not available: …` and persistence stays off for the session ([S/platform/web/js/libs/library_godot_os.js](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/js/libs/library_godot_os.js), `GodotFS.init`).
- The path: `OS_Web::get_user_data_dir()` returns `"/userfs/" + <dir>` ([S/platform/web/os_web.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/os_web.cpp)). `<dir>` is the usual `godot/app_userdata/<application/config/name>`, or `<custom_user_dir_name>` when `application/config/use_custom_user_dir` is on ([S/core/os/os.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/core/os/os.cpp), `OS::get_user_data_dir`). This project's `config/name` is `lunar-lander`, so `user://` is `/userfs/godot/app_userdata/lunar-lander`. **Renaming the project in Project Settings moves `user://`, and old saves seem to vanish.**
- In the browser: one IndexedDB database named `/userfs` (the mount point) per origin, with object store `FILE_DATA`. Each file is one record keyed by its full path, holding `{timestamp, mode, contents}` ([Emscripten `libidbfs.js`](https://github.com/emscripten-core/emscripten/blob/main/src/lib/libidbfs.js)). Every Godot game served from the same origin shares that database and is kept apart only by the `<dir>` path.
- `OS.is_userfs_persistent()` returns whether that IndexedDB mount succeeded ([OS docs](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-is-userfs-persistent)). The export docs warn it "can give false positives in some cases" ([Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)). It only reports whether the IndexedDB mount succeeded. Private windows typically let IndexedDB open and then discard it when the window closes, so they plausibly report `true` (inferred from the code, not tested).
- Neither the engine nor the default HTML shell calls `navigator.storage.persist()` (I grepped the 4.7.2 `platform/web/js` and `misc/dist/html`). Storage stays in the browser's default "best-effort" mode.

## 2. When writes reach IndexedDB

From [S/platform/web/os_web.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/os_web.cpp) and [S/drivers/unix/file_access_unix.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/unix/file_access_unix.cpp):

1. `FileAccess.store_*()` and `flush()` write only to the in-memory FS. `flush()` doesn't sync on Web, because it never calls the close hook.
2. When a `FileAccess` opened for writing is **closed** (explicit `close()`, or the object being freed when its last reference goes out of scope), `FileAccessUnix::_close()` calls `OS_Web::file_access_close_callback`. That sets `idb_needs_sync = true` if the path starts with `/userfs`. Removing a file or directory (`DirAccess`) does the same.
3. At the start of the **next main-loop iteration**, `OS_Web::main_loop_iterate()` starts `godot_js_os_fs_sync` → `FS.syncfs(false, …)` if no sync is already running. The main loop is `emscripten_set_main_loop(…, -1, …)`, i.e. `requestAnimationFrame` ([S/platform/web/web_main.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/web_main.cpp)). Browsers throttle or pause that in background tabs, so a sync can wait until the tab is visible again.
4. The sync is asynchronous. IDBFS compares memory and IndexedDB by mtime and writes every changed file in **one `readwrite` IndexedDB transaction**, so each sync is all-or-nothing. A quota error aborts the whole transaction. Godot then only logs `Failed to save IDB file system: …` (`GodotFS.sync`), and `OS_Web::fs_sync_callback` ignores the error. **The game is never told that a save didn't persist.**
5. On a clean quit (`get_tree().quit()`), `GodotOS.finish_async` waits for the pending sync and then runs a final `GodotFS.sync()` (`library_godot_os.js`). Nothing hooks `beforeunload`/`pagehide`/`visibilitychange`. **If the player closes the tab or reloads before the next frame's sync finishes, the last write is lost.** Users hit exactly this: a save made in the same frame as closing was lost, and waiting one frame after saving fixed it ([godotengine/godot#56640](https://github.com/godotengine/godot/issues/56640), 3.x but the same mechanism).
6. `JavaScriptBridge.force_fs_sync()` only sets the same `idb_needs_sync` flag. Its docs say it is "only useful for modules or extensions that can't use FileAccess" ([JavaScriptBridge docs](https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html)).

What the game has to do: **close the file** (`ConfigFile.save()` and `FileAccess` going out of scope both do), then let at least one frame run. Nothing else is needed. The game can't await completion from GDScript without its own JavaScript.

Atomic file replace: off by default in exported games (`FileAccess.backup_save = false`, [S/core/io/file_access.h](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/file_access.h)). `OS.set_use_file_access_save_and_swap(true)` turns it on: write to a temp file, then rename on close ([S/core/core_bind.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/core/core_bind.cpp)). On Web the rename happens in memory before the sync, so it guards against a half-written file in memory. It doesn't guard against the tab closing, which the single IDB transaction already covers.

## 3. What loses the data

| Cause | What happens | Source |
|---|---|---|
| Private/incognito window | Storage works during the session but "is usually deleted when the private browsing mode ends". Godot docs: private mode "prevents persistence". `is_userfs_persistent()` likely still returns true (§1). | [MDN quotas](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [Exporting for the Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) |
| Cookies/site data blocked | IndexedDB unavailable → mount fails → no persistence for the session. Docs: "Users must allow cookies (specifically IndexedDB)". | Exporting for the Web |
| User clears site data / cookies | The origin's whole IndexedDB is deleted. On itch.io that is everything from the shared `html-classic.itch.zone` origin. | MDN quotas |
| Storage pressure (LRU eviction) | Best-effort origins are evicted least-recently-used first, "all of its data, not parts of it". Origins granted `navigator.storage.persist()` are skipped. | MDN quotas, [WebKit storage policy](https://webkit.org/blog/14403/updates-to-storage-policy/) |
| Safari ITP 7-day cap | With tracking prevention on, all script-writable storage (IndexedDB included) is deleted "after seven days of Safari use without user interaction on the site". Home-screen web apps have their own counter. | [WebKit: full third-party cookie blocking](https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/), MDN quotas |
| `navigator.storage.persist()` | The only opt-out from eviction. Firefox shows a permission prompt. Chrome and Safari grant or deny silently on heuristics (engagement, home-screen app). Godot never calls it. Calling it would need `JavaScriptBridge.eval` or a custom shell. | MDN quotas, WebKit storage policy |
| Tab closed right after saving | Async sync not finished → last write lost (§2). | os_web.cpp, #56640 |
| Changing host (itch.io ↔ GitHub Pages ↔ own domain) | Storage is per origin, so a new host starts empty. Moving players means an export/import path. | MDN quotas (per-origin) |
| Same host, different embedding page | Storage partitioning keys third-party iframe storage by (top-level site, iframe origin). The same game embedded on two different top-level sites sees two separate saves. Chrome 115+ partitions IndexedDB. Firefox (103+) double-keys IndexedDB. Safari gives cross-origin frames their own partition. | [Chrome storage partitioning](https://privacysandbox.google.com/cookies/storage-partitioning), [MDN State Partitioning](https://developer.mozilla.org/en-US/docs/Web/Privacy/Guides/State_Partitioning), WebKit storage policy |
| Renaming `application/config/name` | `user://` path changes (§1). | os.cpp |

### itch.io specifics

- HTML5 games run in an iframe pointing at itch.io's HTML CDN ([itch.io HTML5 docs](https://itch.io/docs/creators/html5)). leafo (itch.io admin) said only `html-classic.itch.zone` and `html.itch.zone` will serve HTML games, with "no plans to add account-specific subdomains" ([itch.io thread](https://itch.io/t/3099694/notice-for-html-game-devs-upcoming-change-to-cdn-domain), [post](https://itch.io/post/8502982)).
- So **every HTML game on itch.io shares one origin**, and with it one IndexedDB `/userfs` database (per top-level partition) and one quota. Two Godot games with the same `config/name` (`lunar-lander` is generic) write to the same `user://` directory. A unique `custom_user_dir_name` avoids that.
- Uploads are served under per-upload paths on the same origin, so a new upload keeps the origin and the saves. Players reported this both ways on [an older thread](https://itch.io/t/2346400/html5-local-storage-is-lost-at-every-update), from before the domain migration. This is not confirmed by itch.io staff.
- Neither `itch.io` nor `itch.zone` is on the [Public Suffix List](https://publicsuffix.org/list/public_suffix_list.dat). The top-level site for the partition is therefore `itch.io` for both `user.itch.io/game` and `itch.io/embed/…`. An itch embed on a third-party site is a different partition.
- The Godot docs' line "When playing a game presented in an iframe, third-party cookies must also be enabled" predates storage partitioning. Today browsers mostly give third-party iframes partitioned storage rather than none. Firefox's "block all third-party cookies" setting still blocks some storage APIs in third-party frames (MDN State Partitioning), and Safari's ITP still applies. Iframe saves on iOS used to fail outright until Godot stopped hard-requiring IndexedDB ([godotengine/godot#38498](https://github.com/godotengine/godot/issues/38498), fixed in 3.2.2).

### GitHub Pages specifics

`github.io` **is** on the Public Suffix List, so `pkopczynski.github.io` is its own site and origin. Every Pages project of that user (`/lunar-lander`, `/other-repo`) shares one origin and one `/userfs` database. The game is top-level there, not in an iframe, so partitioning doesn't apply.

## 4. Size limits

- No Godot-side limit. IDBFS stores whole files as records, and each sync rewrites every changed file in full.
- Browser quotas per origin (MDN quotas, WebKit storage policy). Firefox best-effort: the smaller of 10% of disk or 10 GiB (group limit). Firefox persistent: up to 50% of disk. Chrome: up to 60% of disk. Safari 17+: up to about 60% of disk for the browser app, about 15% for other WebKit apps. A cross-origin iframe in Safari gets **10% of the main frame's quota**. Private mode may have smaller quotas.
- On itch.io the quota is shared by all HTML games on `html-classic.itch.zone` (in that partition).
- A save file of a few KB to a few hundred KB is far below every limit. A quota failure would be silent (§2.4).

## 5. Choosing a format, versioning and migration

**Formats:**

- **JSON** (`JSON.stringify` / `JSON.parse_string`). Human-readable. Types are limited: no `Vector2`, `Color` etc. ([Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)). **All numbers come back as `float`**: "converting a Variant to JSON text will convert all numerical values to float types" ([JSON docs](https://docs.godotengine.org/en/stable/classes/class_json.html)), and the parser always yields a `double` ([S/core/io/json.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/json.cpp)). Integers such as money need explicit `int()` on load, and above 2^53 they lose precision. `JSON.from_native()` / `JSON.to_native()` (4.3+) round-trip engine types, and `to_native` refuses objects unless `allow_objects`. The parser never builds objects, so plain JSON is safe on untrusted input.
- **ConfigFile.** INI-style sections and keys, values written in Godot's text Variant format, so `int` stays `int` and `Vector2`/`Color` round-trip. The docs pitch it for settings, not game state ([Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html), [ConfigFile docs](https://docs.godotengine.org/en/stable/classes/class_configfile.html)). **Not safe on untrusted input:** its parser (`VariantParser`) builds any engine class written as `Object(Class, "prop": …)` and sets arbitrary properties. It calls `ResourceLoader::load()` for `Resource("path")`, and there is no `allow_objects` switch ([S/core/variant/variant_parser.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/core/variant/variant_parser.cpp), [S/core/io/config_file.cpp](https://github.com/godotengine/godot/blob/4.7.2-stable/core/io/config_file.cpp)). The ConfigFile docs carry no warning about this.
- **Binary `FileAccess.store_var` / `get_var`.** Compact. `get_var(allow_objects = false)` by default. The docs warn: "Deserialized objects can contain code which gets executed. Do not use this option if the serialized object comes from untrusted sources" ([FileAccess docs](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)). The format is opaque and harder to debug or hand-migrate.
- **Resource (`.tres`/`.res` via `ResourceSaver`/`ResourceLoader`).** Typed, and the editor can inspect it. Loading a Resource can run code: the file can embed or reference a script. There is no supported "load without scripts" mode; proposals [godot-proposals#4925](https://github.com/godotengine/godot-proposals/issues/4925) and [#10968](https://github.com/godotengine/godot-proposals/issues/10968) are open. A maintainer there says fixing it on the loading side is "a game of whack-a-mole". Resource loading also caches by path (`ResourceLoader` cache modes), which complicates reloading a save. The "Saving games" docs don't present Resources as a save format at all.
- The risk only matters if a save can come from someone else: shared or imported save files, or a cloud copy. A browser-only `user://` file is written only by the game itself, or by someone with access to the player's own browser devtools.

**Versioning and migration** (Godot has no built-in mechanism. This is the common pattern, not a Godot doc):

- Put an integer schema version in the file (e.g. `"version": 1`). On load, run step-by-step migrations `v1→v2→…→current` on the plain Dictionary before building game state. Write back only in the current version.
- Treat a missing key as "use the default", so additive changes need no migration. With JSON, convert numbers back to `int` explicitly.
- Decide what happens with a file from a *newer* version (downgrade after a rollback) and with a corrupt or unparseable file (keep a copy rather than overwrite).
- Nothing here can recover from the storage-loss cases in §3. Only an export/import path (copy text, download a file via `JavaScriptBridge.download_buffer()`) or a server can.

## Implications for saving the career

Facts only. The decisions belong to the "Saving the career" ticket.

- Saving to `user://` works on Web with no setup. The file lands at `/userfs/godot/app_userdata/lunar-lander/…` in IndexedDB, unless `config/name` or `custom_user_dir_name` changes.
- A save persists only after the `FileAccess` is closed **and** the next frame's async sync finishes. A save made at the moment the player closes the tab can be lost, and a failed sync (e.g. quota) is invisible to GDScript.
- Browser saves are best-effort. Private windows, clearing site data, LRU eviction, and Safari's 7-day no-interaction cap can each wipe the whole career, and the game can't detect this except by finding no file. Only `navigator.storage.persist()` (via JavaScript) opts out of eviction, and browsers may refuse it.
- The save is tied to the host. itch.io, GitHub Pages and any other host each have separate storage, and an itch embed on a different top-level site is a separate partition. On itch.io the origin, database and quota are shared with every other HTML game, and the generic `config/name` `lunar-lander` could collide.
- JSON turns every number into a float (money needs `int()` on load). ConfigFile keeps types but will instantiate objects and load resources from the file. Resources can run code on load. `get_var` is safe only with `allow_objects = false`. Only JSON is inert on untrusted input.
- Godot gives no versioning. A schema version field plus explicit migrations is up to the game.
