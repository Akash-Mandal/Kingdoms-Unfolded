# Kingdom Eternal 3D — Grand Plan (GDD + TDD)

> The single source of truth for design and engineering. A living document — update it per
> phase so it never drifts from the code.
>
> **Engine:** Godot 4.4 / GDScript · **Platform:** Android APK · **Build:** GitHub Actions
> (`godot-ci:4.4`), no PC required · **Status:** Phase 0 complete (CI green, first APK shipped).

---

# PART I — GAME DESIGN DOCUMENT

## 1. Vision & Pillars

A deeply immersive medieval kingdom simulation where every decision ripples through a living
3D world. The macro state (resources, diplomacy, tech) and the micro world (individual
citizens with lives) are *the same* simulation seen at two zoom levels.

**Four pillars**
1. **Visible causality** — if the CE says "unrest +12%", a crowd is forming somewhere the
   player can fly to and watch.
2. **Dual-clock depth** — monthly strategy turn *and* real-time lives, battles, and crises.
3. **AI as narrator, CE as referee** — prose from LLMs, rules from the engine; never blocks.
4. **Every kingdom is unique** — seeded worldgen + CE state + AI personalization = no two
   reigns tell the same story.

## 2. Core Game Loop

```
        ┌───────────────────────────────────────────┐
        │   OBSERVE   world · stats · events · map  │
        └─────────────────────┬─────────────────────┘
                              ▼
        ┌───────────────────────────────────────────┐
        │   DECIDE    policy · build · decree · war │
        └─────────────────────┬─────────────────────┘
                              ▼
        ┌───────────────────────────────────────────┐
        │   COMMIT    spend resources + willpower   │
        └─────────────────────┬─────────────────────┘
                              ▼
        ┌───────────────────────────────────────────┐
        │   ADVANCE   month → CE resolves cascades  │◄── real-time interludes
        └─────────────────────┬─────────────────────┘    (battles, court, crises)
                              ▼
        ┌───────────────────────────────────────────┐
        │   REACT     events · missions · letters   │
        └─────────────────────┬─────────────────────┘
                              ▼
                       (narrative moment)
```

Loop cadence: **one turn = one month**. A typical session interleates several turns with
real-time interludes (a border skirmish, a court judgment, a festival). The player may pause
at any moment.

## 3. Player Verbs (action taxonomy)

| Domain | Verbs |
|---|---|
| Economic | set tax rate · allocate budget · commission building · zone land use · open/close trade route · embargo · mint coinage |
| Military | raise levies · train units · appoint commander · march army · fortify · raid · declare war · sue peace |
| Diplomatic | send envoy · gift · propose alliance/marriage · sign treaty · break pact · spy · assassinate |
| Civic | decree policy · host festival · suppress heresy · appoint official · judge court cases |
| Technological | fund research branch · assign scholars · adopt unlocked reform |
| Personal | rest · tour realm · hold court · pursue ambition · educate heir · choose marriage |
| Temporal | pause · ×1 · ×4 · ×12 · advance month · skip-to-event |

**Two resources of intent:** *resources* (gold/food/etc., finite) and **willpower** (a per-turn
action-point budget scaling with ruler age & health — prevents turn-bloat, models attention).

## 4. Win / Lose & End States

The game is **dynastic endurance**, not a single win condition.

| State | Trigger | Outcome |
|---|---|---|
| **Dynastic milestone** | surviving N generations OR prestige ≥ Legendary | "triumph" ending (narrated) |
| **Total collapse** | revolt deposes ruler *and* no heir, OR capital conquered | game over |
| **Fragmentation** | realm splits into vassal states | soft-lose; play on diminished |
| **Cultural victory** | Renaissance scenario: knowledge + culture thresholds | triumph |
| **Early death** | ruler dies with no successor | succession crisis mini-arc |

There is no "you win" screen mid-campaign — milestones unlock narrated chronicle chapters;
the player continues until collapse or chooses to retire the dynasty.

## 5. Session & Reign Structure

- **A turn** = 1 month. **A year** = 12 turns. **A reign** = one ruler's lifetime (≈ 30–60
  years). **A dynasty** = a chain of reigns via succession.
- **Campaign target:** reach a dynastic milestone (default: 5 generations or 200 years).
- New ruler on succession is **generated from upbringing** (heir's education, mentor traits,
  childhood events) → emergent personality, not random.

## 6. Difficulty Model

| Difficulty | Event severity | Rival aggression | Start resources | Plague freq | Willpower |
|---|---|---|---|---|---|
| Peaceful Ruler | ×0.6 | ×0.5 | +30% | ×0.5 | +1 |
| Iron Fist | ×1.0 | ×1.0 | baseline | ×1.0 | baseline |
| Chaos | ×1.4 | ×1.3 | −10% | ×1.5 | −1 |
| Legendary | ×1.8 | ×1.5 | −20% | ×2.0 | −1 |

Difficulty is set at kingdom creation and locked per save (respecced only on New Game).

## 7. Economy & Balance (formulas)

**Production (per resource, per turn)**
```
prod[key] = Σ(workers_on_chain × productivity × tech_mult × land_quality) − decay
```
**Consumption**
```
cons_food = population × 0.25 × (1 + army_ratio × 0.5) × (winter ? 1.3 : 1.0)
cons_gold = upkeep(military) + civil_services + court
```
**Happiness** (0..1, class-weighted)
```
happiness = clamp(
    0.45
  + 0.30 × food_ratio                          # food_stock / cons_food
  + 0.15 × (1 − tax_rate)
  + 0.10 × safety_index                        # walls, garrison, peace
  − 0.25 × war_fatigue                         # months at war / 24
  − 0.20 × (1 − liberty_index)                 # oppressive decrees
  + 0.10 × festival_recency_bonus
, 0, 1)
```
**Population growth** (logistic, per class)
```
K = carrying_capacity(food_supply, housing, jobs)   # ceiling
dP = P × r × (1 − P/K) − deaths(plague, war) ± net_migration(loyalty, neighbors)
r = base_birth_rate × (happiness − 0.4)            # unhappy → negative growth
```
**Revolt risk** (rolled per turn)
```
P(revolt) = clamp((1 − happiness − loyalty) × 0.5 + tax_excess + famine_turns × 0.1, 0, 0.9)
```
**Battle power** (per side)
```
power = Σ(units × count × type_strength × morale × terrain_mult × commander_trait)
result = weighted_random(power_a : power_b) × flanking_bonus × supply_factor
```

Tuning lives in `data/catalog/balance.json` so designers can iterate without code changes.

## 8. Content Bible (scope & counts)

| Category | Count | Catalog file |
|---|---|---|
| Buildings | 40 (8 econ · 10 military · 8 civic · 6 religious · 8 special) | `buildings.json` |
| Unit types | 6 × 3 tiers = 18 | `units.json` |
| Tech nodes | 6 branches × ~10 = 60 | `tech.json` |
| Event templates | ~120 (weighted, state-conditional) | `events.json` |
| Main-quest acts | 10 | `main_quest.json` |
| Side mission templates | 6 categories × 8 = 48 | `missions.json` |
| Side stories | 6 (multi-chapter, AI-personalized) | `side_stories.json` |
| Side games | 7 | `side_games.json` |
| Scenarios | 7 presets + custom prompt | `scenarios.json` |
| Ruler traits | 24 (16 positive, 8 negative) | `traits.json` |
| NPC names | procedural per culture pool | `names/<culture>.json` |
| Diplomatic treaties | 6 | `treaties.json` |

All catalogs are **data-driven JSON** loaded at runtime; the CE reads them, the WC visualizes
their effects. This makes the game moddable and balances code-vs-content.

## 9. World Generation Spec

**Pipeline** (seeded, reproducible — `scripts/world/terrain.gd` today):
1. Domain-warped fBm heightmap → elevation [-1, 1].
2. Second noise → moisture; combined with elevation & latitude → **biome**
   (deep water / shallow / sand / plains / forest / hills / rock / snow).
3. **Springs** at high-moisture high-elevation points; trace downhill to sea → carve rivers
   (width by flow accumulation).
4. **Habitable mask** = non-water, slope < threshold → candidate settlement cells.
5. Place player capital at best habitable cell; place N rival capitals with min-spacing
   constraint (Poisson-disc on habitable mask).
6. **Resource nodes**: ore in mountains, timber in forests, fish on coasts, fertile soil in
   plains — density from biome.
7. **Roads**: A* on habitable mask between cities, weighted by slope; major vs minor.
8. **Climate bands** by latitude → temperature → seasons severity (snow vs mild winter).

## 10. UI/UX & Information Architecture

**Primary surface:** full-screen 3D world. Everything else is layered.

| Layer | Purpose | Mobile ergonomics |
|---|---|---|
| 3D world | the simulation you can fly through | orbit/pinch/pan |
| Top status bar | kingdom, turn, 8 resources (current `hud.gd`) | glanceable |
| Bottom action bar | context actions (build radial, next turn) | **right-thumb zone** |
| Bottom sheet | contextual detail panel (selected building/NPC/battle) | one-hand reach |
| Event modal | narrative card + choices | dismissible |
| Minimap toggle | strategic 2D overlay (borders, armies, routes) | top-right |
| Hamburger menu | deep screens (Court, Diplomacy, Tech, Stats, Chronicle) | secondary |

**One-hand rule:** every core verb reachable with the right thumb at default hold. Deep
management screens are optional detours, never gates.

**Information hierarchy:** world shows *state*; sheets show *detail*; menus show *depth*.
Never duplicate the same number in three places.

## 11. Art Direction Bible

- **Style:** stylized low-poly, warm directional key + cool sky fill, soft shadows, fog,
  filmic tonemap, subtle glow. "Great graphics" via direction, not asset cost.
- **Palette:** earth tones base; kingdom banner = player accent; hostile = desaturated red;
  neutral NPC = muted; quest NPC = warm gold rim.
- **Silhouette > detail:** readable shapes at 10m, 50m, 200m (ties to LOD tiers).
- **Scale:** 1 grid unit = 4 m (matches `terrain.gd` SPACING). Human ≈ 1.8 m. City block ≈ 40 m.
- **Materials:** toon-ish albedo + rim light; water additive transparent; foliage billboards.
- **Animation set:** idle (breathing), walk, work-cycle per job, fight, cheer, mourn. Blend
  spaces; ~6 anims reused via retarget.
- **Asset sources:** CC0 (Quaternius medieval UltraPack, Kenney) + procedural assembly;
  recorded in `INSTALL_LOG.md`.

## 12. Audio Direction

- **Adaptive layered score:** calm base bed → tension layer fades in at war → triumph stinger
  on victory; mourning layer on ruler death. Layers driven by CE mood signals.
- **Diegetic:** market chatter, smith hammering, battle clangs, festival music — emitted by
  in-world sources (positional `AudioStreamPlayer3D`).
- **UI SFX:** pooled, non-positional; distinct timbre per verb family.
- **Accessibility:** master/music/sfx/sfx-3d sliders; subtitles for all diegetic speech.

## 13. Onboarding & Progressive Disclosure

- **First 5 minutes:** you inherit a small village. An advisor overlays contextual hints:
  place a farm → advance a month → resolve your first event. Then hints fade.
- **Progressive unlock:** tabs unlock as systems become relevant (Research appears when a
  scholar arrives; Diplomacy when first rival is met). Prevents front-loaded overwhelm.
- **Advisor density slider:** off / hint / hand-hold — player-tunable.

## 14. Accessibility

- Text size scaling (×0.8 / ×1 / ×1.3 / ×1.6).
- Colorblind palettes (deutan/protan/tritan).
- Slow-mode (×0.5 sim speed) + full pause.
- Autoplay-combat toggle (skip real-time battles → auto-resolve).
- Haptics for events, taps, danger.
- Subtitles for all AI narration and diegetic speech.

## 15. Localization

- Godot's `res/values-*` already scaffolded by the Android build template.
- All player-facing strings via `tr()` + CSV translation tables.
- Ship with English; community translations via CSV PRs.

---

# PART II — TECHNICAL DESIGN DOCUMENT

## 16. Architecture — Three Layers + Persistence

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
│  PERSISTENCE   save system · settings vault · telemetry   │
└──────────────────────────────────────────────────────────┘
```

**Dual-clock rule (canonical):** the micro world runs continuously in real time; at each
in-game month-end the CE snapshots world state, rolls events, and produces the turn. Real-time
battles happen in-world; outcomes feed the CE military module. Nothing ever blocks on the
network — every AI call resolves to local prose on timeout/failure.

**CE ↔ WC sync points (snapshot at month-end):**
- food produced by farmers (WC) → `resources.food.stock` (CE)
- population counts per class (WC headcount) → `population.<class>.count` (CE)
- battle outcome (WC) → `military.units_lost` + `diplomacy.relation` delta (CE)
- mean citizen mood (WC happiness) → `population.happiness` (CE)
- CE policy (tax↑) → WC job demand + mood delta next tick

## 17. Coordination Engine (CE) — macro simulation

Pure GDScript, fully unit-testable headless (`scripts/tests/smoke_test.gd` gates CI today).
Autoload `Game` (`scripts/core/game.gd`).

### 17.1 Tick Engine
`turn, year, month`; `advance()` → `_apply_flows()` → `_roll_events()` → emit `turned`,
`resources_changed`, `event_occurred`.

### 17.2 Resource record (data contract)
```gdscript
resources[key] = {
    "stock":   float, "prod":  float, "cons":  float,
    "capacity":float, "trade": float,
}
# keys: food, gold, wood, stone, iron, cloth, horses, knowledge
```
Shortage cascade: `food ≤ 0 → happiness −0.05 → revolt_risk +0.2 → army morale −10
(desertion)`. Each step emits a CE event the WC visualizes.

### 17.3 Population (macro classes)
```gdscript
population[class] = {
    "count": int, "happiness": float, "loyalty": float,
    "productivity": float, "birth_rate": float, "death_rate": float,
}
# classes: peasants, merchants, clergy, nobles, soldiers, scholars
```

### 17.4 Military — unit record & battle resolution
```gdscript
units[type] = { "count": int, "morale": float, "supply": float,
                 "experience": float, "commander_id": int }
```
Battle: `power = Σ(count × strength × morale × terrain × commander)`; outcome via
`weighted_random(power_a : power_b)` with flanking/supply modifiers. Real-time 3D scene in
Phase 3; auto-resolve always available.

### 17.5 Diplomacy — memory-driven AI
```gdscript
relations[kingdom_id] = {
    "score": int,          # opinion, signed-ish
    "trust": float,        # decays toward 0
    "treaty": String,      # none|nap|alliance|vassalage|confederation|marriage
    "memory": RingBuffer, # betrayals, gifts, slights (weighted by recency)
    "last_event": int,     # turn
}
```
AI decision: utility over {war, trade, marry, betray, gift} scored from `score`, `trust`,
relative power, ambition trait.

### 17.6 Technology tree — 6 branches × ~10 nodes
Each unlock: stat bonuses + new game options + **visible world upgrade** (e.g., agriculture
node → field tileset change + yield ×1.1).

### 17.7 Event probability engine
Per turn: roll disasters/plagues/revolts/discoveries/random; probability weighted by state
(`food < 20 → plague ×3`). Emits `{type, severity, context, last_5_events}` to
NarrativeProvider.

### 17.8 CE → Narrative handoff
```
CE → {event_type, severity, kingdom_context, last_5_events, traits, hooks}
NarrativeProvider.generate(prompt) → {narrative_text, choices[], hooks[]}
CE applies player choice → state update → emit event_occurred
```

## 18. World Simulation (WC) — micro / NPC

Lives in `scripts/npc/` and `scripts/world/`.

### 18.1 Agent model
```gdscript
agent = {
    "id": int, "name": String, "class": String, "pos": Vector3,
    "needs":   {hunger, rest, safety, social, faith, wealth},  # 0..1
    "traits":  [String, ...], "skills": {String: float},
    "schedule":Array[{hour, action, target}], "job": String,
    "household": int, "relations": {agent_id: opinion},
    "memory":  RingBuffer, "age": float, "lifecycle": String, "goals": Queue,
}
```

### 18.2 Decision — utility AI
```
score(action) = Σ(weight_k × need_satisfaction_k) × job_affinity × context_mult
pick argmax; re-evaluate on interrupt (event, danger, new job).
```

### 18.3 Production chains (WC → CE)
```
field(farmer) → grain → mill → flour → bakery → bread → market → food stock
mine(miner)   → ore   → smelter → iron → smithy → tools → productivity+
forest        → log   → sawmill → plank → construction
```
Each link = a 3D building with worker slots + throughput; disruptions physically appear
(mill burnt → no flour → empty bakery → bread shortage → CE food drop → hunger).

### 18.4 Daily schedule — hour grid 0–23
sleep (22–6) · breakfast · work shift (6–18 w/ breaks) · leisure/tavern · supper · sleep.
Festivals when morale high; mourning after disasters; conscription pulls men from work.

### 18.5 Relationships & dynasties
Per-agent bounded memory (ring buffer ~32). Opinion graph → families, feuds, loves, betrayals
→ feeds Court, Espionage, Succession. Ruler is an NPC with court, guards, heir; death
(disease/assassination/old age) triggers real-time succession → CE ruler swap + narrative scene.

### 18.6 Crowd LOD (performance)

| tier | distance | render | sim |
|---|---|---|---|
| A | near (<30 m) | full skeletal anim | full utility AI + needs |
| B | mid (30–120 m) | baked billboard / imposter | lite AI (job only) |
| C | far (>120 m) | none / crowd texture | aggregate stat |

Cap ~800 tier-A agents; remainder aggregate. `MultiMeshInstance3D` for repeated meshes.

## 19. Rendering & Performance Budget

| Target | Budget |
|---|---|
| Mid-range Android | 30 FPS floor, 60 target |
| Draw calls | < 400 / frame |
| Tier-A agents | ≤ 800 |
| Sim tick | ≤ 4 ms (threaded `WorkerThreadPool`) |
| Memory | < 1 GB resident |
| APK (debug) | ~55 MB today; release target < 80 MB |

**Techniques:** `MultiMeshInstance3D` for crowds/trees, object pooling, spatial-hash agent
queries, baked GI on static geometry, texture atlases, `Mobile` renderer default (Forward+
toggle for high-end). Day/night, seasons, weather shader-driven; terrain by seeded heightmap
+ biome splat (`terrain.gd`).

**Profiling methodology (per-phase gate):**
1. Capture `--render-thread` frame time on a reference mid-range device profile.
2. Record draw-call count, agent count, sim ms via an in-game `DebugOverlay` (F1 toggle).
3. Regression gate: APK must hold 30 FPS on the Phase-N scenario before advancing.
4. `WorkerThreadPool` for NPC updates; main thread only reads results.

## 20. AI Narrative Layer (multi-provider)

| Adapter | Endpoint | Use |
|---|---|---|
| `LocalEngine` | — (default, offline, free) | procedural template prose; always works |
| `Gemini` | Google native endpoint | user key |
| `OpenAI-compatible` | any base URL (OpenRouter, DeepSeek, Moonshot…) | broadest compat |
| `Ollama` | LAN server on PC/Manus | fully private, offline |

**Governance:** request queue · timeout + retry w/ backoff · token-budget meter · response
cache (similarity) · JSON-schema-forced outputs. **Keys encrypted on-device, never in saves or
git.** Every call falls back to `LocalEngine` on failure → game never blocks.

Powers: event narratives, dialogue, Chronicle, mission briefs, side stories, death/succession
scenes, diplomacy letters, battle narration.

Prompt architecture:
```
[SYSTEM CONTEXT] kingdom, era, turn, pop, gold, mil, last 5 events, traits, hooks
[TASK] specific generation request
[FORMAT] structured output (JSON or prose schema)
```

## 21. Data-Driven Content Pipeline

All content lives as JSON under `data/catalog/`:
```
data/catalog/
├── buildings.json    units.json    tech.json    events.json
├── traits.json      treaties.json scenarios.json
├── balance.json     main_quest.json  missions.json
├── side_stories.json  side_games.json
└── names/{northern,southern,eastern,desert,island}.json
```
Loaded once at startup into typed dictionaries; CE reads rules, WC reads visuals mapping.
**Benefit:** balance/content iterate without code changes; moddable; CI smoke test can load
catalogs to validate JSON schema.

## 22. Save System & Migration

Format (JSON; see `KingdomUnfolded.md`):
```json
{ "meta": {…}, "gameState": {…}, "eventHistory": […], "missionLog": […],
  "storyProgress": {…}, "chronicle": […], "settings": {…}, "ceState": {…} }
```
- `SAVE_VERSION` constant in `game.gd`; `_restore()` calls `migrate(from, data)` chain when
  version bumps (each migration is a pure function).
- 5 named slots + autosave every 5 turns.
- Export/import `.kingdom` JSON for portability.
- API keys live in an encrypted settings vault, **never** serialized into saves.

## 23. Build & Dev Pipeline (proven working)

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
- Workflow `.github/workflows/build.yml`; triggers: push to `main`, `v*` tags, manual.
- `scripts/tests/smoke_test.gd` gates the APK build on every push.
- **CI traps fixed & documented in `docs/BUILD.md`** (silent `etc2_astc` failure, HOME
  mismatch, android_source.zip layout, keystore preset fields).
- Signing: debug today; release keystore as GitHub secret when Play Store targeted.

## 24. Testing Strategy

| Layer | Tool | Coverage |
|---|---|---|
| CE pure functions | GUT (GDScript unit) | economy math, event rolls, save round-trip |
| Catalogs | JSON-schema validator | all `data/catalog/*.json` load cleanly |
| WC agent logic | property-based tests | needs converge, no degenerate schedules |
| Smoke (headless) | `smoke_test.gd` (CI today) | CE turn advance + save/load |
| Visual playtest | per-phase checklist | fun + perf gate |
| Regression | per-phase FPS capture | hold 30 FPS on reference device |

## 25. Project Structure & Conventions

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
├── data/catalog/            data-driven JSON content
├── assets/                  CC0 art packs (tracked in INSTALL_LOG.md)
├── .github/workflows/       CI
├── docs/                    BUILD.md, this plan, changelog
└── INSTALL_LOG.md           download/install ledger (reversible)
```
**Conventions:** GDScript `snake_case`; signals past-tense (`turned`, `event_occurred`);
typed where cheap; `:=` only for non-Variant inference; warnings-as-errors for
`INFERENCE_ON_VARIANT` (CI enforces). No comments unless asked.

## 26. Telemetry (opt-in)

Local-only first; exportable. Per-session: turns survived, collapse cause, resource curves,
time-in-tab. Used for balance hotspots. Off by default; explicit consent; never networked
unless the player exports a save to share.

## 27. Versioning & Release Strategy

- `0.x` during development (we are at `0.1.0`).
- `1.0.0` at Phase 6 launch (Play Store sideload build for self/friends).
- Semver after 1.0; each release ships a `v*` tag → triggers CI → signed AAB.
- Personal-polished first; monetization revisited only post-1.0.

---

# PART III — DELIVERY

## 28. Roadmap (playable every phase)

| Phase | Scope | Acceptance criterion (personal-playtest-fun) |
|---|---|---|
| **0 · Foundations** ✅ | skeleton, terrain gen, camera, HUD, CE turn, save, CI | flying over a generated kingdom is satisfying — **DONE** |
| **1 · Living World** | day/night, seasons, weather, first 3 buildings, economy chains | watching the village grow over months is satisfying |
| **2 · The People** | NPC agents, needs/utility-AI, jobs, schedules, relationships, crowd LOD | you recognize individual citizens and their stories |
| **3 · Systems** | military + 3D battles, diplomacy, tech tree, events, missions | full strategy loop is engaging |
| **4 · AI Soul** | NarrativeProvider, local prose engine, LLM adapters, Chronicle, dialogue | AI narration feels like a living chronicle |
| **5 · Depth** | side stories, scenarios, minigames, Court & succession, espionage | parity with `KingdomUnfolded.md` reached |
| **6 · Launch** | performance hardening, tutorial, onboarding, signed AAB | release-quality personal build |

**MVP definition:** end of Phase 3 = a complete, if unpolished, strategy game loop:
generate kingdom → build → grow → fight → lose. Phases 4–6 are depth + polish, not core.

## 29. Phase task breakdowns

### Phase 1 — Living World
1. Day/night cycle: directional light angle from sim-hour; sky color gradient; ambient.
2. Season system: 4 seasons × 3 months; leaf/snow shader params; crop-yield modifier.
3. Weather: rain/snow/fog particle layers; visibility + mood effects.
4. Building system: placeable footprints; 3 tiers (house, farm, mill); grows with CE pop.
5. Economy chain: grain→flour→bread visible flow; shortage visibly empties market.
6. Time controls: pause, ×1, ×4, ×12; month-end CE summary card.

### Phase 2 — The People
1. Agent spawn/despawn w/ LOD tiers; spatial hash.
2. Needs + utility-AI tick (threaded).
3. Job assignment from labor demand.
4. Schedules + navmesh movement.
5. Households + relations graph + memory.
6. Crowd rendering (MultiMesh, billboards).

### Phase 3 — Systems
1. Military: units, commanders, march, garrison.
2. Real-time battle scene + auto-resolve.
3. Diplomacy: rival AI, treaties, letters.
4. Tech tree: research + visible upgrades.
5. Events: state-weighted rolls + narrative handoff stub.
6. Missions: main-quest act 1 + side templates.

### Phase 4 — AI Soul
1. `NarrativeProvider` interface + `LocalEngine`.
2. Gemini + OpenAI-compat + Ollama adapters.
3. Chronicle prose turn-by-turn.
4. Dialogue system for NPCs + court.
5. Caching/queue/fallback governance.
6. Settings UI for providers + keys.

### Phase 5 — Depth
Side stories, scenarios, minigames (tournament/duel/battle-sim in-world), Court &
succession, espionage. Full `KingdomUnfolded.md` parity.

### Phase 6 — Launch
Perf hardening, tutorial, onboarding, icon/splash, signed AAB, Play Store sideload.

## 30. Risk Register

| Risk | Mitigation |
|---|---|
| Realistic assets unaffordable | low-poly art direction + CC0 + procedural |
| Mid-range phone perf | early profiling per phase; 3-tier LOD; Mobile renderer |
| LLM cost / latency / blocking | Local-first, caching, queue, offline fallback |
| Scope explosion | vertical slices; sim depth gated by perf budget; MVP = Phase 3 |
| Phone↔PC workflow friction | git + CI-as-PC; `docs/BUILD.md` |
| CI silent failures | smoke test gates APK; `etc2_astc` + template layout documented |
| Save-format drift | `SAVE_VERSION` + migration chain (pure functions) |
| Balance cliff | data-driven `balance.json`; opt-in telemetry; per-phase playtests |
| AI hallucination breaking rules | CE validates all LLM JSON output; rejects → LocalEngine |

## 31. Glossary

- **CE** — Coordination Engine (macro, monthly, the referee).
- **WC** — World Clock / micro sim (real-time, individual NPCs).
- **NarrativeProvider** — abstraction over Local + cloud LLMs.
- **Tier-A/B/C agent** — near/mid/far simulation LOD.
- **Dual-clock rule** — real-time micro + monthly macro, synced at month boundary.
- **Willpower** — per-turn action-point budget (ruler attention).
- **Reign / Dynasty** — one ruler's lifetime / chain of reigns via succession.

## 32. Decision Log (ADR-style)

- **ADR-001** Godot 4.4 + Mobile renderer — mobile-first 3D, text-friendly dev, broad device support.
- **ADR-002** CI-as-PC (GitHub Actions godot-ci) — no PC available; proven 2026-08-20.
- **ADR-003** Hybrid AI (Local + multi-provider) — fully playable offline; cloud = polish, never a gate.
- **ADR-004** Dual-clock (real-time micro + monthly macro) — coherence over faking it.
- **ADR-005** Data-driven JSON catalogs — iterate balance/content without code; moddable.
- **ADR-006** Stylized low-poly art — "great graphics" via direction, not asset cost.
- **ADR-007** Personal-polished, no monetization pre-1.0 — keeps build simple; revisit later.

## 33. Changelog

- **2026-08-20** — Phase 0 complete. CI green; first APK artifact (54 MB). Plan expanded to full
  GDD+TDD with formulas, content bible, art/audio bibles, data-driven pipeline, testing
  strategy, ADR log. Traps in `docs/BUILD.md`; tracker in `INSTALL_LOG.md`.

---

*This plan is the single source of truth. Update it when a phase completes or a decision
changes; do not let it drift from the code.*
