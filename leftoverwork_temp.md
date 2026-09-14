# leftoverwork_temp.md — TEMPORARY HANDOVER FOR NEW CHAT
> TEMP working doc — created 2026-09-14 to migrate remaining production work to a fresh chat. Delete after promotion to docs/. Do NOT commit long-term; this is a handover ledger.

## 0. Where we are
- Project: `/storage/emulated/0/Coding/projects/Kingdoms_Unfolded` — Godot 4.7.2, Mobile renderer, 1280x720 canvas_items/keep, ~9MB assets → ~60MB APK.
- Branch: `main`, NOT pushed per `AGENTS.md` (§ manual-only builds). All recent work is local commits only.
- Latest commits (newest first):
  - `e8ff906` Long batch: failed-mission filter, tutorial reset, 44px targets, release AAB job, tech/battle analytics, save .bak
  - `babd52e` Remaining: AI war raid damage scaled by army power
  - `71e6333` Remaining: save v5 migrate, maintenance sink, train analytics
  - `6147222` Continue remaining: placement collision, crash log, analytics hook
  - `2fa328d` Production cont: mission repeat cap 3x, analytics track turn/game_over
  - `a52a121` Production F-G: analytics opt-in bus, story flags, quick-start
  - `94a7fa5` Production P0-D: auto-degrade potato, targetSdk 35, privacy draft
  - `99b676a` Production P0-B: food caps, tribute income, gift cooldown, difficulty start mult
  - `e768857` Production P0-A: victory/defeat director, mortality, atomic saves, start mult, scenario hook, game-over UI
  - `5b4d684` Fix swarm findings: boot, saves, military/jobs, NPC, terrain, UI, net/audio (first swarm)
- Swarm sources: docs/PRIVACY_TEMP.md (draft), tmp/KU_production_gaps_TEMP.md (full P0/P1/P2 map). This doc is the executable remainder.

## 1. How to resume in new chat
1. Load `AGENTS.md` (manual-only builds: `workflow_dispatch` + `v*` only, no push-to-main build).
2. `export HOME=/data/data/com.termux/files/home` before any git.
3. Check `git log --oneline -10` and `git status --short` — expect ~9 unpushed commits.
4. Read this file top-to-bottom; work in §4 order (P0 → P1 → P2). One commit per section, no auto-push.
5. After each fix: `git add -A && git commit -m "...";` only `git push` when whole task done and user says to.

## 2. Ground rules
- Keep commits batched (whole task = 1 commit). Never push after every edit.
- No `push` until user approves end of task. Docs/config pushes use `[skip ci]`.
- Builds only on `workflow_dispatch` or `v*` tag — never re-add `push: branches: [main]`.
- Research-only swarms already ran (13 agents). This doc is FIX execution.

## 3. Done (do not redo)
- Boot: watchdog 8s+4s, cover always hides, string connects for typed signals, _build_all sync guards, _connect_graphics early, sun shadow/glow/fog_mult, continue fail fatal, HUD meta-before-add, scenario panel wired.
- Saves: succession/scenario/sideStories persisted, cooldown uses Game map, pop_capacity recomputed, contrib sanitized, clamp 999999, snapshot duplicate, train n<=0, autosave not clobber slot_0, turn0 skip, succession empty-heir guard, fail_story true, game_over signals.
- Combat/econ: free-troop deduct fixed, disband negative fixed, auto_resolve alias fixed, restore clamp, food cap food_stock/housing*2, maintenance sink 0.1/building, targetSdk 35, quick-start button, story_flags on choice, gift cooldown 6 turns, war raid damage scaled by army, placement 4m anti-stack, crash log to user://logs/error.log, mission repeat cap 3x, failed-mission filter, tutorial reset on new game, 44px targets, release-AAB tag job, save .bak, analytics bus created + turn/game_over/battle/tech/train hooks.

## 4. Remaining — exact work by priority

### P0-1 Victory fail-paths + duration enforcement
- **Problem**: `data/catalog/main_quest.json` all 10 acts `branch: {success: next, fail: null}` — no failure recovery. `scenarios.json` duration_turns/victory flavor only, not enforced as win/lose branches.
- **Files**: `scripts/core/missions.gd:177-209`, `data/catalog/main_quest.json:16-143`, `scripts/core/game.gd:206-251`, `docs/GRAND_PLAN.md:§3`.
- **Do**: 1) Add `fail` path to at least act_08 (e.g., act_08_fail_recovery). 2) In `missions.gd:advance_act`, handle `fail` via `is_act_failed()` (plague/revolt not survived). 3) In `game.gd:_check_game_over`, add fail-branch defeat (e.g., 3 crisis without survival → fail). Keep linear for now, just add 1 fail act to prove path.
- **Test**: Set `main_quest.json` act_08 to have fail branch, force crisis, verify fail act loads.

### P0-2 Real AI war resolution
- **Problem**: `diplomacy.gd:428 war` only does score/trust + raid steal 4-10g/2-6f (`_apply_raid_damage`). No army vs army, no tribute demand, no peace cost.
- **Files**: `scripts/core/diplomacy.gd:428-489`, `scripts/core/military.gd:186-206`.
- **Do**: In war branch, after raid: if `relations[kingdom_id].power` vs `Game.military` (via `Game.military_power()`), call `Military.auto_resolve({kingdom_power}, {player_power}, terrain)` on duplicated dicts, apply 50% of losses to `Game.military` (or at least push war event with casualties). Gate by `treaty == alliance/nap` 72% block already there. Add `power` growth: `tick()` `power = clampf(power + randf_range(-2,5), 30, 200)`.
- **Test**: Low army → raid steals more; high army → less.

### P0-3 Difficulty full wiring
- **Problem**: `balance.json` has willpower_bonus/rival_aggression/plague_frequency/start_resources_mult/event_severity — only start mult wired (`game.gd:785`). Diplomacy has zero difficulty refs, happiness still stub.
- **Files**: `data/catalog/balance.json:83+`, `scripts/core/game.gd:210-230,296-300`, `scripts/core/diplomacy.gd`, `scripts/core/events.gd:142-161`.
- **Do**: 1) `game.gd:_difficulty` helper: `plague_prob_mult = balance.difficulty.<diff>.plague_frequency` → multiply in `Events.roll`. 2) `diplomacy.gd:tick` multiply AI `war` desire by `rival_aggression`. 3) Happiness: at least add `tax` stub (0) so formula is pluggable, log telemetry.
- **Test**: Legendary triggers more plague/war than peaceful.

### P0-4 Hosted policy + Data Safety + consent UI
- **Problem**: `docs/PRIVACY_TEMP.md` is repo-only draft. Play needs hosted URL + Data Safety + in-app disclosure/consent + delete UI. KeyVault is XOR+UID, not Keystore.
- **Files**: `docs/PRIVACY_TEMP.md`, `scripts/net/key_vault.gd:29-53`, `scripts/ui/narrative_settings.gd`, `export_presets.cfg:68,137`, `README.md:62`.
- **Do**: 1) Host `PRIVACY_TEMP.md` content as `https://.../privacy.html` (GitHub Pages). 2) Add `PRIVACY_URL` constant, link in `narrative_settings.gd` + `start_screen.gd` footer. 3) Add `Clear Keys` button (exists in code `clear_all()` but no UI evidence). 4) Fill Data Safety draft doc: internet=true, LLM prompt data, no ads, encryption at rest = XOR (disclose). Update `keystore/README.md` stub.
- **Test**: Settings shows privacy link + clear works.

### P0-5 Signing/AAB + version policy
- **Problem**: CI has `build-release-aab` tag job but secrets empty, `version/code` 3/4 split same 1.0.0, `keystore/release.keystore` placeholder.
- **Files**: `.github/workflows/build.yml:25-80`, `export_presets.cfg:33-34,102-103`, `keystore/README.md`.
- **Do**: 1) Create upload keystore once: `keytool -genkey ... -keystore keystore/release.keystore`, backup offline, `base64 keystore/release.keystore` → `ANDROID_KEYSTORE_BASE64`, plus `ANDROID_KEYSTORE_PASSWORD/ALIAS/KEY_PASSWORD` secrets. 2) Freeze policy: `version/code` AAB-only incrementing, debug APK never uploaded. Document in `keystore/README.md` (fix drift: says 2, is 3/4). Do NOT commit real keystore.
- **Test**: `git tag v1.0.0-test && git push origin v1.0.0-test` triggers AAB job (skip if no secrets, expect skip message).

### P1-1 Content flags coherence + post-mission follow_up
- **Problem**: `story_flags` written (`game.gd:593`) but never read. `missions.json` only one `follow_up` (`military_train_elite`).
- **Files**: `scripts/core/game.gd:593`, `scripts/core/missions.gd:253-295`, `data/catalog/missions.json:215`, `data/catalog/events.json`.
- **Do**: 1) At least 2 events with `flag` in choice (e.g., `flag: spared_priests`). 2) In `events.gd: weighted_pick`, boost weight if `story_flags` has prereq. 3) Make one mission chain have real follow_up reward.
- **Test**: Choose flag, see weighted follow-up appear.

### P1-2 Tutorial completeness + help/codex
- **Problem**: Tutorial 5 steps Farm→Turn→Event only, no spotlight, restart resets, no help/codex.
- **Files**: `scripts/ui/tutorial.gd:1-158`, `scripts/ui/hud.gd`, `scripts/core/scenarios.gd`.
- **Do**: 1) Add steps for mill/bakery chain, tech, build menu. 2) Add spotlight arrow (use `ColorRect` highlight over target control). 3) Add `Help` CanvasLayer (simple `PanelContainer` with 3 tabs: Build Chain / Tech / Diplomacy, 200-word each). Wire `?` button in HUD top row.
- **Test**: New game shows extended tutorial, help opens.

### P1-3 Accessibility a11y + font scale
- **Problem**: `core/accessibility.gd` + `ui/accessibility.gd` scale only HUD res, `_load` never applies, no OS respect, colorblind/SR missing.
- **Files**: `scripts/core/accessibility.gd:5-10,88`, `scripts/ui/accessibility.gd:17-46`, `scripts/ui/ui_theme.gd:8-16`.
- **Do**: 1) On `_load`, call `_apply_to_tree()`. 2) Add colorblind toggle (swap `ui_theme.GREEN/RED` to `+ icon` redundant cue). 3) Add `accessibility_description` to icon-only buttons `☰✕⋯🐢DBG`. Low effort stubs.
- **Test**: xlarge 1.6 scales all panels, toggle changes palette.

### P1-4 Analytics 15 events wiring
- **Problem**: Bus exists, only 5 tracked: turn_advanced, game_over, building_placed, unit_trained, tech_completed, battle_resolved. Missing fute/step, mission, act, event choice, save/load, crash, fps.
- **Files**: `scripts/core/analytics.gd`, `scripts/core/game.gd:192,243`, `scripts/core/missions.gd`, `scripts/world/main.gd`.
- **Do**: Add `Analytics.track` in: `missions.gd:complete_mission`, `act_completed`, `events.gd:apply_choice`, `game.gd:save_to_file/load`, `debug_overlay.gd` fps sample every 10s. Keep local-only.
- **Test**: `user://logs/analytics.jsonl` grows.

### P1-5 Memory/perf leftovers
- **Problem**: Ghost material `StandardMaterial3D.new()` every frame while placing, notifier closures, terrain rebuild spikes, LOD double-loop.
- **Files**: `scripts/world/building_manager.gd:192-196,295-301`, `scripts/world/terrain.gd:100-106,277-280`, `scripts/npc/agent_manager.gd:330-394`, `scripts/ui/debug_overlay.gd`.
- **Do**: 1) Cache ghost material (reuse one `StandardMaterial3D`). 2) Disconnect notifiers on pool release. 3) Terrain `build_trees` defer to `call_deferred` after first frame or add progress bar stub. Auto-degrade already added.
- **Test**: Place 20 buildings, no mat growth via `Performance.MEMORY_STATIC`.

### P1-6 Asset bloat + notchsafe
- **Problem**: `assets/models/kenney_*` 5.5MB never loaded (`building_manager.gd:336` builds Box/Plane only), `export_filter="all_resources"` ships them.
- **Files**: `export_presets.cfg:9,78`, `assets/models/`, `assets/textures/medieval_rts`, `scripts/world/building_manager.gd:336-345`.
- **Do**: Either 1) wire one Kenney GLB as alt for `house` (load + LOD), or 2) set `export_filter` to `exclude_filter="assets/models/kenney_*"` until wired. Also fix notch: `start_screen` and modals ignore safe area (only HUD does).
- **Test**: APK size drops ~5MB if excluded, or visual confirms GLB appears.

### P2 Polish queue (do after P1)
- Localization: no `tr()`, English prompts, binary gender concat (`succession.gd:68`), stereotype names.
- Tech dead bonuses: `military_mult/trade_mult/spoilage` still orphan in `tech.gd` getters.
- Save: live-leak on missing keys (no `reset()` before restore), slot_info exists:false no recovery, quick_load prefers slot_0.
- Ultra==high, 32-bit dropped, themed icon empty, MSAA dead fallback, 18 autoloads, press_feedback leak, RNG JSON precision.
- Docs: `docs/STORE.md` missing (track internal→closed→open), `keystore/README.md` drift.

## 5. Commit plan for new chat
- Commit 1: P0-1 fail-paths (missions + game over).
- Commit 2: P0-2 AI war + power growth.
- Commit 3: P0-3 difficulty wiring.
- Commit 4: P1-1 flags coherence.
- Commit 5: P1-2 tutorial + help.
- Commit 6: P1-3 a11y.
- Commit 7: P1-4 analytics 15 events.
- Commit 8: P1-5 perf/memory.
- Commit 9: P1-6 asset + safe area.
- Commit 10: P0-4/5 store gate (policy + signing) — host + secrets.

## 6. Verification after each
- `timeout 90 godot --headless --path . --script res://scripts/tests/smoke_test.gd` (currently covers sim only; extend to catalog + balance).
- Manual smoke: New Game → Quick Start → End Turn 3× → check crash log `user://logs/error.log`, analytics `user://logs/analytics.jsonl`, save `.bak` exists.
- No push until user says `release` or `push`.

> END TEMP — promote to docs/GRAND_PLAN.md + docs/STORE.md when settled, then delete this and tmp/KU_production_gaps_TEMP.md.
