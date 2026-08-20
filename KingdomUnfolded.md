# Kingdom Eternal — Master Game Design Plan

## Vision Statement

A deeply immersive, AI-driven text-based kingdom simulation where every decision ripples through a living, breathing world — powered by Gemini AI for narrative generation and a local Coordination Engine for simulation accuracy.

---

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Framework | React (JSX artifact) | Single-file, rich UI, recharts built-in |
| AI Backend | Google Gemini API (user-supplied key) | Narrative, events, missions, stories |
| Charts | Recharts + D3 | Statistics dashboards |
| Storage | Artifact persistent storage (key-value) | Save/load system |
| Coordination Engine | In-app JS engine | Offline simulation logic |
| Styling | Tailwind + custom glassmorphism | Premium aesthetic |

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              KINGDOM ETERNAL                │
│                                             │
│  ┌─────────────┐    ┌──────────────────┐   │
│  │ Coordination│◄──►│  Gemini AI Layer │   │
│  │   Engine    │    │  (Narrative Gen) │   │
│  │  (JS/Offline│    │  Flash / Pro     │   │
│  │  Simulation)│    └──────────────────┘   │
│  └──────┬──────┘                           │
│         │                                  │
│  ┌──────▼──────────────────────────────┐   │
│  │          Game State Core            │   │
│  │  Resources · Population · Military  │   │
│  │  Diplomacy · Technology · Events    │   │
│  └──────┬──────────────────────────────┘   │
│         │                                  │
│  ┌──────▼──────────────────────────────┐   │
│  │         React UI Layer              │   │
│  │  Tabs · Charts · Modals · Stories   │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌──────────────────────────────────────┐   │
│  │    Save System (Import/Export JSON)  │   │
└──┴──────────────────────────────────────┴──┘
```

---

## The Coordination Engine (CE) — Core Design

This is the offline brain that runs every game tick, completely independent of AI:

### CE Modules

**1. Tick Engine**
- Game runs in "turns" (each turn = 1 month in-game)
- Every tick recalculates ~80 interdependent variables
- Processes queued actions from the player

**2. Resource Simulation**
- Food, Gold, Wood, Stone, Iron, Cloth, Horses, Knowledge
- Each resource has: production rate, consumption rate, decay rate, trade value
- Shortage cascades: low food → population unhappiness → tax revolt → army desertion

**3. Population Engine**
- Classes: Peasants, Merchants, Clergy, Nobles, Soldiers, Scholars
- Each class has: loyalty, happiness, productivity, birth/death rate
- Disease, famine, war, and prosperity all affect population dynamically

**4. Military Engine**
- Unit types: Infantry, Archers, Cavalry, Siege, Navy, Elite Guards
- Morale, supply lines, experience levels, commander traits
- Battle simulation using a weighted probability model with terrain modifiers

**5. Diplomacy Engine**
- AI kingdoms with memory (they remember betrayals, alliances, gifts)
- Relationship scores affect trade rates, war likelihood, marriage proposals
- Treaties, non-aggression pacts, vassalage, confederations

**6. Technology Tree Engine**
- 6 branches: Agriculture, Military, Commerce, Architecture, Arcane, Governance
- Research unlocks cascade into new game options and statistical bonuses

**7. Event Probability Engine**
- Every tick rolls for: natural disasters, plagues, revolts, discoveries, random events
- Probability weighted by current kingdom state (low food = higher plague chance)
- Passes event context to Gemini for rich narrative generation

**8. CE ↔ Gemini Handoff Protocol**
```
CE detects: [Event Type + Severity + Kingdom Context + History]
       ↓
Sends structured prompt to Gemini
       ↓
Gemini returns: [Narrative Text + Flavor Choices + Story Hooks]
       ↓
CE processes player choice + updates game state
```

---

## Game Start — Kingdom Creation

### Screen 1: The World
- Choose **World Seed** (generates map name, climate, continent size)
- **Era**: Ancient (500 BC), Medieval (1100 AD), Renaissance (1450 AD), Custom
- **Difficulty**: Peaceful Ruler / Iron Fist / Chaos / Legendary

### Screen 2: Kingdom Identity
- Kingdom Name, Banner Color, Sigil (text-described)
- **Government Type**: Monarchy, Oligarchy, Theocracy, Republic, Tribal Confederation
- **State Religion**: Christianity, Islam, Paganism, Sun Worship, Atheist, Custom
- **Primary Culture**: Northern, Southern, Eastern, Western, Desert, Island, Forest

### Screen 3: Ruler Creation
- Ruler Name, Age, Gender
- **Backstory** (AI-generated based on your choices): orphan heir, warrior king, scholar queen, merchant lord, etc.
- **Traits** (pick 3 positive, 1 negative): Charismatic, Tactician, Economist, Cruel, Just, Paranoid, Visionary, Coward, etc.
- **Starting Bonuses** (choose 1 of 5 legacy paths): Militarist, Diplomat, Builder, Scholar, Trader

### Screen 4: Starting Conditions
- Territory Size: Village / Town / City-State / Small Kingdom / Established Kingdom
- Starting Resource Distribution (sliders for each resource)
- **Rivals**: 2–5 AI kingdoms (auto-named + AI-generated personality summaries)
- **Special Scenario** toggle (see Scenarios section)

---

## UI Layout & Navigation

### Main Layout
```
┌─[☰ Menu]──────────────────[Kingdom Name]──[Turn: Month/Year]─┐
│                                                               │
│  [Alerts Banner — scrolling events]                          │
│                                                              │
│  [Main Content Area — active tab]                            │
│                                                              │
│  [Bottom Status Bar: Gold | Food | Pop | Military | Mood]    │
└───────────────────────────────────────────────────────────────┘
```

### Hamburger Menu — All Tabs

| # | Tab | Description |
|---|---|---|
| 1 | 🏰 Kingdom Overview | Dashboard with all key stats + charts |
| 2 | 👥 Population | Class breakdown, happiness, demographics |
| 3 | 💰 Treasury | Income/expense ledger, trade, taxation |
| 4 | 🌾 Resources | All 8 resources with production/consumption graphs |
| 5 | ⚔️ Military | Army composition, battles, commanders |
| 6 | 🤝 Diplomacy | Foreign relations map, treaties, espionage |
| 7 | 🏗️ Construction | Buildings, infrastructure, city planning |
| 8 | 🔬 Research | Technology tree, active research, discoveries |
| 9 | 📜 Events & Decisions | Active events, AI-generated choices |
| 10 | 🗺️ World Map | Text-based map with territories, borders |
| 11 | 📖 Chronicle | Full AI-narrated history of your kingdom |
| 12 | 🎯 Missions | Main quests + side missions |
| 13 | 📚 Side Stories | Standalone AI story arcs |
| 14 | 🎮 Side Games | Mini-games (Battle Simulator, Trade Game, etc.) |
| 15 | 👑 Court | Advisors, nobles, marriages, succession |
| 16 | 🕵️ Espionage | Spies, sabotage, intelligence reports |
| 17 | 📊 Statistics | Deep analytics dashboard |
| 18 | 🌍 Scenarios | Scenario selector + timeline viewer |
| 19 | ⚙️ Settings | Gemini API key, model selector, game settings |
| 20 | 💾 Save / Load | Save slots, export/import JSON |

---

## Statistics Dashboard — Full Design

This is a flagship section with 6 sub-tabs:

### Sub-tab 1: Economic Overview
- Line chart: Gold over 24 turns
- Stacked bar: Income sources (taxes, trade, tribute)
- Area chart: Resource stockpile history
- Pie chart: Budget allocation

### Sub-tab 2: Population Analytics
- Line chart: Total population over time
- Grouped bar: Class distribution each era
- Happiness index gauge
- Birth/death rate curves

### Sub-tab 3: Military Strength
- Radar chart: Army vs 3 rivals (strength dimensions)
- Bar chart: Unit type breakdown
- Line: Battle win/loss ratio
- Heatmap: War frequency by region

### Sub-tab 4: Diplomacy Tracker
- Relationship score cards for each kingdom
- Line chart: Relation scores over time
- Sankey diagram: Trade flow between kingdoms

### Sub-tab 5: Kingdom Scorecard
- Composite "Kingdom Power Score" over time
- Leaderboard vs AI kingdoms
- Attribute spider chart: Economy, Military, Culture, Research, Happiness

### Sub-tab 6: Historical Timeline
- Visual scrollable timeline of major events
- Color-coded: Wars (red), Alliances (blue), Disasters (orange), Discoveries (green)

---

## AI Integration — Gemini Layer

### Settings Tab
- API Key input (masked, stored locally)
- Model selector dropdown:
  - `gemini-2.5-flash` (recommended — balanced)
  - `gemini-2.5-flash-lite` (fast, low cost)
  - `gemini-2.5-pro` (deep narratives)
- Temperature slider (creativity level)
- Test connection button

### How Gemini Powers Each Section

| Section | Gemini Role |
|---|---|
| Events | Generates 3-paragraph event narrative + 3 choice options with consequence hints |
| Missions | Generates full mission brief, objectives, story arc, resolution text |
| Chronicle | Narrates your kingdom's history turn-by-turn in epic prose |
| Side Stories | Full multi-chapter stories set in your kingdom |
| Court | Generates advisor personalities, dialogue, betrayal plots |
| Diplomacy | Generates foreign king/queen personalities and letters |
| Side Games | Generates scenario text for Battle Sim, Trial of Kings mini-game |
| World Events | Generates global news dispatches from other kingdoms |
| Death/Succession | Generates death scene + heir's personality + kingdom reaction |

### Prompt Architecture
Every Gemini call includes:
```
[SYSTEM CONTEXT]
Kingdom: {name}, Era: {era}, Turn: {turn}
Population: {pop}, Gold: {gold}, Military: {mil}
Recent events: {last 5 events}
Ruler traits: {traits}
Active storylines: {hooks}

[TASK]
{specific generation request}

[FORMAT]
{structured output format}
```

---

## Missions System

### Main Quest Line (AI-generated, era-specific)
- 10-act story arc: Rise → Conflict → Crisis → Triumph (or Fall)
- Each act has 3–5 objectives tracked by CE
- Branching endings based on your decisions

### Side Missions (dynamically generated)
Categories:
- **Political**: Expose a corrupt noble, broker a royal marriage
- **Military**: Defend a border village, train an elite unit
- **Economic**: Build a trade route, recover from famine
- **Cultural**: Commission a great work, suppress heresy
- **Espionage**: Assassinate a rival's general, steal tech secrets
- **Personal**: Ruler's personal journey, family drama, legacy building

Each mission: AI-generated brief + CE-tracked objectives + AI-generated resolution cutscene

### Mission Tracker UI
- Active missions panel (up to 5 simultaneous)
- Mission log with full AI-written history
- Reward preview (resources, traits, relationship changes)

---

## Side Stories

Standalone narrative experiences that don't affect main gameplay but enrich the world:

- **"The Beggar King"** — A dethroned rival's story, told from their POV
- **"The Merchant's Daughter"** — A trade family navigating your kingdom's policies
- **"Plague Year"** — A physician's journal during an epidemic
- **"The Last General"** — A war commander's final campaign
- **"The Spy's Confession"** — An espionage thriller
- All fully AI-generated, personalized to your kingdom's name, era, and history

---

## Side Games

| Side Game | Description |
|---|---|
| ⚔️ Battle Simulator | Set up custom armies, simulate battles with AI narration |
| 🏪 Trade Floor | Real-time supply/demand mini market game |
| 👑 Trial of Kings | Judgment scenarios — make rulings, see consequences |
| 🗡️ Duel | Your champion vs rival's — dice + stats, AI narrated |
| 🃏 Noble Cards | Card-based political intrigue game using your court |
| 🏹 Tournament | Host a tournament, bet on outcomes, gain prestige |
| 🧩 Royal Puzzle | Resource allocation puzzle with timed CE simulation |

---

## Scenarios & Timelines

### Preset Scenarios
- **The Crusade**: Religious war, manage faith + military simultaneously
- **The Plague**: 30-turn survival scenario, population hemorrhaging
- **The Succession Crisis**: Heir is a child, regency council politics
- **The Mongol Tide**: Defend against a massively superior invading force
- **The Renaissance**: Culture and knowledge victory condition only
- **The Merchant Republic**: Economy-only, no military conquest allowed
- **Custom Scenario**: AI generates a unique scenario from your prompt

### Timeline Viewer
- Visual horizontal scrolling timeline
- Player-annotatable (add notes to any turn)
- AI can summarize any time range as a "historical period"
- Compare two timelines side-by-side (if you have multiple saves)

---

## Save / Load System

### Save Format
Single JSON export containing:
```json
{
  "meta": { "version", "saveDate", "turnCount", "kingdomName" },
  "gameState": { "resources", "population", "military", "diplomacy", "tech" },
  "eventHistory": [ ...all past events ],
  "missionLog": [ ...completed + active missions ],
  "storyProgress": { ...all story states },
  "chronicle": [ ...AI-generated history entries ],
  "settings": { "era", "difficulty", "rulerTraits" },
  "ceState": { ...coordination engine internal variables }
}
```

### Save UI
- 5 named save slots (with kingdom thumbnail summary card)
- Auto-save every 5 turns
- **Export**: Downloads `.kingdom` JSON file
- **Import**: Upload `.kingdom` file to restore exactly
- Save versioning with conflict detection

---

## Implementation Phases

### Phase 1 — Core Shell
React app skeleton, hamburger nav, all tab stubs, Settings tab with Gemini connection, start screen flow, CE tick engine (basic), resource simulation

### Phase 2 — Kingdom Life
Population engine, treasury, military, construction, technology tree, basic statistics dashboard with charts

### Phase 3 — AI Soul
Full Gemini integration, events system, Chronicle, missions system, court tab, diplomacy with AI personalities

### Phase 4 — Depth Layer
Side stories, side games, espionage, scenarios, timeline viewer, full statistics (all 6 sub-tabs)

### Phase 5 — Polish
Glassmorphism UI refinement, save/load system, auto-save, animations, sound design descriptions, balance pass on CE numbers

---

## Design Principles

**Realism over simplicity** — every number means something and cascades into others.

**AI as narrator, CE as referee** — Gemini makes it feel alive; the CE makes it accurate.

**No dead screens** — every tab has dynamic content, charts, and at least one AI-generated element.

**Your kingdom is unique** — the combination of CE state + Gemini personalization means no two kingdoms tell the same story.

**Respect the player's time** — the game is pausable at any turn; nothing expires without warning.