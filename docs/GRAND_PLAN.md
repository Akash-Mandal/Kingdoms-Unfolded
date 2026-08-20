# Kingdom Eternal 3D — Grand Plan

> Living engineering plan for a deep medieval kingdom simulation on Android.
> Built in **Godot 4.4 / GDScript**, code on phone (Termux), APKs built in the cloud.
> Status: **Phase 0 complete** — the foundation, save system, and CI build pipeline are live.

---

## 1. North Star

A living 3D medieval world on a phone where **every number is visible** and **every citizen is
simulated**. Two simulation clocks breathe together:

- **Macro CE (The State)** — kingdoms, resources, diplomacy, tech, events (the original
  `KingdomUnfolded.md` design, fully preserved).
- **Micro WC (The People)** — thousands of individuals with needs, jobs, schedules,
  relationships, and memory, visibly living in the 3D world.

AI narrates; the simulation is the referee. The game is fully playable offline; cloud LLMs are
optional polish.

---

## 2. Locked Decisions

| Area | Decision | Why |
|---|---|---|
| Platform | Android APK (sideload → later Play Store) | target device |
| Engine | Godot 4.4+, GDScript, **Mobile renderer** (Vulkan) | mobile-first 3D, text-friendly dev |
| Renderer toggle | high-end devices get optional Forward+ | graphics quality knob |
| Art style | stylized low-poly + premium lighting | "great graphics" without asset cost |
| Assets | CC0 packs (Quaternius, Kenney) + procedural | downloadable on phone, free |
| Dev flow | code on phone (Termux); **never run editor locally** | no PC available |
| Build backend | GitHub Actions CI (godot-ci:4.4) primary; Manus fallback | proven working 2026-08-20 |
| Sim clocks | real-time micro world + monthly macro turn | coherent dual-clock rule |
| AI narrative | `NarrativeProvider`: Local templates (offline) + Gemini + OpenAI-compatible + Ollama | hybrid, multi-provider, configurable |
| Monetization | deferred; personal-polished project first | no billing code |
| Phone footprint | ~150–450 MB, all inside one folder, tracked in `INSTALL_LOG.md` | reversible |

---

## 3. Design Principles

1. **Realism over simplicity** — every number cascades into others (food shortage → empty market
   → hungry faces → crowd → revolt).
2. **AI as narrator, CE as referee** — Gemini makes it feel alive; the CE makes it accurate.
   AI never blocks gameplay — every call has a local fallback.
3. **No dead screens** — every tab has dynamic content, charts, and at least one AI element.
4. **Visible causality** — if the CE says "unrest +12%", a crowd must be forming somewhere
   the player can fly to and see.
5. **Respect the player's time** — pausable at any turn; nothing expires without warning.
6. **Vertical slices** — the game stays buildable and fun at every phase milestone.
7. **Reversibility** — `INSTALL_LOG.md` lets the whole venture be torn down to zero footprint.

---

## 4. Architecture — Three Layers + Persistence

```
┌──────────────────────────────────────────────────────────┐
│  PRESENTATION   3D world · camera · HUD · menus · charts │
└────────────────────────────┬─────────────────────────────┘
┌────────────────────────────▼─────────────────────────────┐
│  SIMULATION (dual-clock)                                  │
│  ┌──────────────────┐        ┌──────────────────────────┐ │
│  │  MICRO WC        │◄──────►│  MACRO CE                │ │
│  │  NPC agents      │ sync   │  resources · pop · mil   │ │
│  │  jobs · needs    │        │  diplo · tech · events   │ │
│  │  battles (real-t)│        │  monthly turn            │ │
│  └──────────────────┘        └──────────────────────────┘ │
│  real-time tick               1 month = 1 turn             │
└────────────────────────────┬─────────────────────────────┘
┌────────────────────────────▼─────────────────────────────┐
│  NARRATIVE   NarrativeProvider (pluggable)                │
│  LocalEngine │ Gemini │ OpenAI-compat │ Ollama            │
└────────────────────────────┬─────────────────────────────┘
┌────────────────────────────▼─────────────────────────────┐
│  PERSISTENCE   save system · settings vault · telemetry  │
└──────────────────────────────────────────────────────────┘
```

**Dual-clock rule (canonical):** the micro world runs continuously in real time; at the end of
each in-game month the CE snapshots world state, rolls events, and produces the turn. Real-time
battles happen in-world; outcomes feed the CE military module. Nothing ever blocks on the
network — every AI call resolves to local prose on timeout/failure.

**CE ↔ WC sync points (snapshot at month-end):**
- food produced by farmers (WC) → `resources.food.stock` (CE)
- population counts per class (WC headcount) → `population.<class>.count` (CE)
- battle outcome (WC) → `military.units_lost` + `diplomacy.relation` delta (CE)
- mood of citizens (WC avg happiness) → `population.happiness` (CE)
- CE policy changes (tax↑) → WC job demand + mood delta next tick

---

## 5. Coordination Engine (CE) — Macro Simulation

The offline referee. Currently skeleton in `scripts/core/game.gd`. Each module below is a
phase deliverable; all are pure GDScript, fully unit-testable headless (`smoke_test.gd` runs
in CI today).

### 5.1 Tick Engine
- `turn: int` (1 turn = 1 month), `year`, `month` (1–12).
- `advance()` → applies flows → rolls events → emits `turned`.
- Real-time micro tick runs separately; month boundary triggers CE snapshot.

### 5.2 Resource record (data contract)
```gdscript
resources[key] = {
    "stock":   float,   # current amount
    "prod":    float,   # per-turn production (from WC production chains)
    "cons":    float,   # per-turn consumption
    "capacity":float,   # storage cap; overflow decays
    "trade":   float,   # net per-turn trade balance
}
# keys: food, gold, wood, stone, iron, cloth, horses, knowledge
```
Shortage cascade: `food stock ≤ 0 → population.happiness -= 5 → revolt chance += 0.2 →
army.morale -= 10 (desertion)`. Each step emits a CE event the WC visualizes.

### 5.3 Population engine (macro classes)
```gdscript
population[class] = {
    "count":     int,    # headcount (authoritative = WC census)
    "happiness": float, 0..1
    "loyalty":   float, 0..1
    "productivity": float, 0..1
    "birth_rate":  float, per turn
    "death_rate":  float, per turn
}
# classes: peasants, merchants, clergy, nobles, soldiers, scholars
```

### 5.4 Military engine
- Unit types: infantry, archers, cavalry, siege, navy, elite_guards.
- Per unit: `count, morale, supply, experience, commander_id`.
- Battle resolution: weighted probability + terrain modifiers; **real-time 3D battle scene**
  (Phase 3) with optional auto-resolve.

### 5.5 Diplomacy engine
- AI kingdoms with **memory** (betrayals, alliances, gifts → opinion deltas).
- `relations[kingdom_id] = { score: int, treaty: String, trust: float, last_event: turn }`.
- Treaties: non-aggression, alliance, vassalage, confederation, royal marriage.

### 5.6 Technology tree
- Branches: agriculture, military, commerce, architecture, arcane, governance.
- Research unlock → cascades new game options + stat bonuses + **visible world upgrades**
  (e.g., agriculture tech → field tileset change + yield).

### 5.7 Event probability engine
- Every tick rolls: disasters, plagues, revolts, discoveries, random events.
- Probability weighted by current state (`food < 20 → plague chance ×3`).
- Passes `{type, severity, context, history}` to NarrativeProvider for prose.

### 5.8 CE → Narrative handoff protocol
```
CE detects: {event_type, severity, kingdom_context, last_5_events, ruler_traits, hooks}
   → NarrativeProvider.generate(prompt) → {narrative_text, choices[], story_hooks[]}
   → CE applies player choice → updates state → emits event_occurred
```

---

## 6. World Simulation (WC) — Micro / NPC

The flagship "realistic simulation" layer (Phase 2+). Lives in `scripts/npc/` and
`scripts/world/`.

### 6.1 Agent model (the NPC)
```gdscript
agent = {
    "id":         int,
    "name":       String,
    "class":      String,         # one of the 6 population classes
    "pos":        Vector3,        # world position (LOD-managed)
    "needs":      {hunger, rest, safety, social, faith, wealth},  # 0..1
    "traits":     [String, ...],  # personality tags
    "skills":     {String: float},
    "schedule":   Array[{hour, action, target}],
    "job":        String,         # assigned by labor demand system
    "household":  int,            # household id
    "relations":  {agent_id: opinion},  # bounded graph
    "memory":     RingBuffer,     # last N salient events
    "age":        float,
    "lifecycle":  String,        # child | worker | elder
    "goals":      Queue,
}
```

### 6.2 Decision system
- **Utility AI**: score candidate actions against needs + job + world context each tick;
  pick highest; re-evaluate on interrupt (event, danger).
- **Job assignment**: labor demand from buildings/economy → NPCs bid by skill → assigned;
  idle NPCs drift to taverns/plazas (visible unemployment).

### 6.3 Production chains (WC → CE)
```
field(farmer) → grain → mill → flour → bakery → bread → market → food stock
mine(miner) → ore → smelter → iron bar → smithy → tools
forest(lumberjack) → log → sawmill → plank → construction
```
Each link is a 3D building with worker slots and throughput; disruptions physically appear
(mill burnt → no flour → empty bakery → bread shortage → CE food drop → hunger).

### 6.4 Daily schedule system
- Hour grid (0–23): sleep (22–6), breakfast, work shift (6–18 w/ breaks), leisure/tavern,
  supper, sleep. Festivals when morale high; mourning after disasters.

### 6.5 Relationships & dynasties
- Per-agent bounded memory (ring buffer, ~32 events).
- Opinion graph → families, feuds, loves, betrayals → feeds Court, Espionage, Succession.
- Ruler is an NPC with court, guards, heir; death (disease/assassination/old age) triggers
  real-time succession → CE ruler swap + narrative scene.

### 6.6 Crowd LOD (performance)
| tier | distance | render | sim |
|---|---|---|---|
| A | near (<30m) | full skeletal animation | full utility AI + needs |
| B | mid (30–120m) | baked billboard / imposter | lite AI (job only) |
| C | far (>120m) | none / crowd texture | aggregate stat only |
- Cap ~800 tier-A agents; remainder aggregate. `MultiMeshInstance3D` for repeated meshes.

---

## 7. Rendering & Performance Budget

**Art direction:** stylized low-poly with warm directional lighting, soft shadows, fog,
filmic tonemap, subtle glow — "great graphics" via art direction, not asset cost.

| Target | Budget |
|---|---|
| Mid-range Android | 30 FPS floor, 60 target |
| Draw calls | < 400/frame |
| Tier-A agents | ≤ 800 |
| Sim tick | ≤ 4 ms (threaded via `WorkerThreadPool`) |
| Memory | < 1 GB resident |
| APK (debug) | ~55 MB today; release target < 80 MB |

**Techniques:** `MultiMeshInstance3D` for crowds/trees, object pooling, spatial-hash agent
queries, baked GI on static geometry, texture atlases, `Mobile` renderer default (Forward+
toggle for high-end in Settings). Day/night, seasons, weather driven by shaders; terrain by
seeded heightmap + biome splat (`scripts/world/terrain.gd` today).

---

## 8. AI Narrative Layer (Multi-Provider)

Single interface, pluggable adapters, configured in Settings:

| Adapter | Endpoint | Use |
|---|---|---|
| `LocalEngine` | — (default, offline, free) | procedural template prose; always works |
| `Gemini` | Google native endpoint | user key |
| `OpenAI-compatible` | any base URL (OpenRouter, DeepSeek, Moonshot…) | broadest compat |
| `Ollama` | LAN server on PC/Manus | fully private, offline |

**Governance:** request queue, timeout + retry w/ backoff, token-budget meter, response cache
(similarity), JSON-schema-forced outputs. **API keys stored encrypted on-device, never in
save files or git.** Every call must resolve to `LocalEngine` on failure → game never blocks.

Powers: event narratives, character dialogue, Chronicle, mission briefs, side stories,
death/succession scenes, diplomacy letters, battle narration.

Prompt architecture (from `KingdomUnfolded.md`):
```
[SYSTEM CONTEXT] kingdom, era, turn, pop, gold, mil, last 5 events, traits, hooks
[TASK] specific generation request
[FORMAT] structured output (JSON or prose schema)
```

---

## 9. Systems cross-reference (original doc → 3D implementation)

All 20 original tabs survive, reorganized as: **3D world (main)** → **HUD/contextual menus**
(build radial, event cards, battle view) → **strategy screens** (Kingdom/Diplomacy/Tech/
Statistics, custom-drawn charts in Godot) → **narrative screens** (Chronicle, Stories, Codex).
Side games (tournament, duel) render in-world. Statistics dashboard (6 sub-tabs) ported as
custom chart widgets.

---

## 10. Build & Dev Pipeline (proven working)

```
Termux phone:  write .gd code → git push
      ↓
GitHub Actions (godot-ci:4.4 Docker):
   import → copy templates+editor settings to $HOME
          → unzip android_source.zip into android/build
          → godot --export-debug "Android" → signed APK
      ↓
Phone browser: download artifact → install → playtest
Manus AI: manual/interactive exports as fallback
```

- Workflow: `.github/workflows/build.yml`. Triggers: push to `main`, `v*` tags, manual.
- Smoke test (`scripts/tests/smoke_test.gd`) gates the APK build on every push.
- **CI traps fixed and documented in `docs/BUILD.md`** — the silent `etc2_astc` failure,
  HOME mismatch, android_source.zip layout, keystore preset fields.
- Signing: debug today; release keystore as GitHub secret when Play Store is targeted.

---

## 11. Project Structure

```
├── project.godot            config (Mobile renderer, etc2_astc, autoloads)
├── export_presets.cfg       Android preset (gradle, target 33, debug keystore)
├── scenes/                  minimal .tscn (world built in code)
├── scripts/
│   ├── core/game.gd         CE autoload — tick, resources, save/load
│   ├── world/               main.gd, terrain.gd, camera_controller.gd
│   ├── ui/hud.gd            HUD overlay
│   ├── npc/                 agent sim (Phase 2)
│   ├── net/                 NarrativeProvider + adapters (Phase 4)
│   └── tests/smoke_test.gd  headless CE test (CI-gated)
├── assets/                  CC0 art packs (tracked in INSTALL_LOG.md)
├── data/saves/              save files
├── .github/workflows/      CI
├── docs/                    BUILD.md, this plan, changelog
└── INSTALL_LOG.md           download/install ledger (reversible)
```

---

## 12. Roadmap — playable every phase

| Phase | Scope | Acceptance criterion (personal-playtest-fun) |
|---|---|---|
| **0 · Foundations** ✅ | skeleton, terrain gen, camera, HUD, CE turn, save, CI | flying over a generated kingdom is satisfying — DONE |
| **1 · Living World** | day/night, seasons, weather, first 3 buildings, economy chains | watching the village grow over months is satisfying |
| **2 · The People** | NPC agents, needs/utility-AI, jobs, schedules, relationships, crowd LOD | you recognize individual citizens and their stories |
| **3 · Systems** | military + 3D battles, diplomacy, tech tree, events, missions | full strategy loop is engaging |
| **4 · AI Soul** | NarrativeProvider, local prose engine, LLM adapters, Chronicle, dialogue | AI narration feels like a living chronicle |
| **5 · Depth** | side stories, scenarios, minigames, Court & succession, espionage | parity with `KingdomUnfolded.md` reached |
| **6 · Launch** | performance hardening, tutorial, onboarding, signed AAB | release-quality personal build |

Each phase = vertical slice: game stays buildable and fun at every milestone.

### Near-term Phase 1 task breakdown
1. Day/night cycle: directional light angle from sim-hour; sky color gradient; ambient.
2. Season system: 4 seasons × 3 months; leaf/snow shader params; crop yield modifier.
3. Weather: rain/snow/fog particle layers; visibility + mood effects.
4. Building system: placeable footprints, 3 tiers (house, farm, mill); grows with CE pop.
5. Economy chain: grain→flour→bread visible flow; shortage visibly empties market.
6. Time controls: pause, ×1, ×4, ×12; month-end CE summary card.

---

## 13. Risk Register

| Risk | Mitigation |
|---|---|
| Realistic assets unaffordable | low-poly art direction + CC0 + procedural |
| Mid-range phone perf | early profiling per phase; 3-tier LOD; Mobile renderer |
| LLM cost / latency / blocking | Local-first engine, caching, queue, offline fallback |
| Scope explosion | vertical slices only; sim depth gated by perf budget |
| Phone↔PC workflow friction | single git repo; CI is the "PC in the cloud"; `docs/BUILD.md` |
| CI silent failures | smoke test gates APK; `etc2_astc` + template layout documented |
| Save-format drift | `SAVE_VERSION` in `game.gd`; migration hook stubbed |

---

## 14. Glossary

- **CE** — Coordination Engine (macro, monthly, the referee).
- **WC** — World Clock / micro sim (real-time, individual NPCs).
- **NarrativeProvider** — abstraction over Local + cloud LLMs.
- **Tier-A/B/C agent** — near/mid/far simulation LOD.
- **Dual-clock rule** — real-time micro + monthly macro, synced at month boundary.

---

## 15. Changelog

- **2026-08-20** — Phase 0 complete. CI green; first APK artifact (54 MB). Plan migrated to
  repo as `docs/GRAND_PLAN.md`; traps documented in `docs/BUILD.md`; tracker in
  `INSTALL_LOG.md`.

*This plan is the single source of truth. Update it when a phase completes or a decision
changes; do not let it drift from the code.*
