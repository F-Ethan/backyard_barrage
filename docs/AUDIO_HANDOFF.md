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

Added 2026-10-08 (mono WAV, same specs). The four hound cues were replaced the same day with the owner's picks. Mix: `throw_whoosh`, `throw_full_power`, `impact_snow`, `impact_wet`, and `hit_ouch` play at 0.75; other one-shots at 1.0 (`AudioCues.volumeOf`). Where each plays:

| File | Plays when |
|---|---|
| ui_back.wav | Settings close, Menu (pause / defeat), shop Back |
| throw_full_power.wav | Player release at full charge (instead of the whoosh) |
| charge_hum.wav | Loops while the player holds a charge (volume 0.75) |
| fort_hit.wav | A snowball hits a fort that stays up |
| fort_collapse.wav | A fort falls (worn out, or Fort cracker) |
| coin_pop.wav | Coins pop over a knocked-out rival |
| wave_start.wav | The "Wave N" banner |
| frost_glint.wav | A frost kid starts its windup |
| armor_block.wav | Frost armor turns away a snowball or the hound |
| powerup_armor.wav / powerup_freeze.wav / powerup_cocoa.wav | Those power-ups |
| powerup_power.wav | Power throw, Fort cracker, Big splat |
| hound_growl.wav | The hound appears (lane warning) |
| hound_leap.wav | The hound jumps the river |
| hound_snap.wav | The hound's bite lands |
| hound_whimper.wav | The hound runs off (scared or bounced) |
| hound_howl.wav | A far-off warning howl at a random moment before a wave's first hound (0.5s into the fight to 2s before it). 2.95s, a little over the 2.5s stinger guide. |

## Loops (`assets/audio/music/`)
- menu_loop.wav (cozy backyard, light) — menus
- battle_loop_winter.wav — winter arena
- battle_loop_summer.wav — summer arena

Winter and summer each play their own battle loop. Summer does not reuse the winter bed.

## Specs
- Prefer WAV or OGG; 44.1kHz mono for SFX, stereo OK for music
- Keep SFX < 1s except stingers < 2.5s
- Place under `assets/audio/sfx/` and `assets/audio/music/`
