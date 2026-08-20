# Audio — Adaptive Layered Score (GRAND_PLAN §12)

> Calm base bed → tension on war → triumph stinger on victory → mourning on ruler death. Driven by CE mood; plus diegetic 3D + pooled UI SFX.

## 4-Layer Adaptive Score

| Layer | File (placeholder) | Trigger (CE signal) | Mix |
|---|---|---|---|
| **base** | `base.ogg` (loop, calm) | always on; `happiness 0.5–1.0`, peace | Bus `Music/Base` 0 dB |
| **tension** | `tension.ogg` (loop, percussive) | `war_fatigue>0.3` OR `revolt_risk>0.4` OR `diplomacy.score<-40` | Bus `Music/Tension` faded in 0→-6 dB, 2s xfade |
| **triumph** | `triumph.ogg` (stinger, 4–6s) | `battle victory` OR `prestige milestone` | One-shot Bus `Music/Stinger` +0 dB, duck base -3 dB 1.5s |
| **mourning** | `mourning.ogg` (loop, sparse) | `ruler death` / `succession crisis` / `plague severity>0.7` | Bus `Music/Mourning` replaces base, low-pass 800Hz |

All layers loop at same BPM (e.g., 80) for seamless crossfade. Placeholder OGGs are silent 1s loops until CC0 music is curated.

## CE → Audio Mapping

```gdscript
# scripts/audio/music_controller.gd (stub)
# mood = clamp(happiness - war_fatigue*0.5 - revolt_risk*0.3, 0, 1)
# tension_vol = lerp(-80, -6, clamp((war_fatigue+revolt_risk)/0.8,0,1))
# mourning = succession_pending or plague
```

Subscribed to `Game.resources_changed`, `Game.event_occurred`, `Military.battle_resolved`.

## Buses & Accessibility

```
Master (-0) -> Music (base/tension/mourning/stinger) | SFX (UI) | SFX3D (diegetic) 
```
Sliders: master / music / sfx / sfx-3d (saved in `settings` vault, never in save JSON). Subtitles for diegetic speech.

## Diegetic & UI SFX (placeholder)

- `AudioStreamPlayer3D` at market/smith/battle sources; pooled `AudioStreamPlayer` for UI verbs (distinct timbre per family: economic=wood, military=metal, civic=chime).
- Files: `sfx/ui_click.ogg`, `sfx/battle_clang.ogg` — placeholders.

## Placeholder Files

- `adaptive_score.json` — layer config + crossfade curves (no binary).
- `*.ogg.placeholder` — zero-byte markers so `preload` does not fail; replace with Ogg Vorbis q0.4 (<500KB each) to stay <80MB.

## Cleanup

```bash
rm assets/audio/*.ogg assets/audio/adaptive_score.json
```

Tracked in `INSTALL_LOG.md` §2.
