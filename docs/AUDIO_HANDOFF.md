# Audio handoff — Backyard Barrage MVP

Studio's procedural MVP pack is in the repo and played by `flame_audio`. Replace these files in place when finals land. Keep the filenames.

## One-shots (`assets/audio/sfx/`)
- throw_whoosh.wav
- impact_snow.wav
- impact_wet.wav
- hit_ouch.wav (kid-safe)
- ko_collapse.wav
- win_stinger.wav
- lose_stinger.wav
- ui_tap.wav
- purchase_coin.wav

## Loops (`assets/audio/music/`)
- menu_loop.wav (cozy backyard, light) — menus
- battle_loop_winter.wav — winter arena
- battle_loop_summer.wav — summer arena

Winter and summer each play their own battle loop. Summer does not reuse the winter bed.

## Specs
- Prefer WAV or OGG; 44.1kHz mono for SFX, stereo OK for music
- Keep SFX < 1s except stingers < 2.5s
- Place under `assets/audio/sfx/` and `assets/audio/music/`
