# Ethan 3D kid sprites (raw)

Approved stills of Ethan's own 3D kid. **The winter player uses these.** `pubspec.yaml` lists only the six `*_512.png` frames the game draws (the four aim frames and the two flipped run frames); the 1024s, unflipped runs, and review sheets are reference only. `SeasonAssets` maps them (see `lib/seasons/season.dart`). Idle and throw are not included because they are not approved yet, so the game reuses `aim_01` for those.

Full frames are 1024×1024 transparent PNGs. Feet sit on a shared baseline at about y=941. Each `*_512.png` is a 512×512 preview of the frame with the same stem (feet at about y=470).

## Aim wind-up

One wind-up pose. The camera pans from profile to 3/4 front.

- `aim_00_profile.png` / `aim_00_profile_512.png` — profile
- `aim_01.png` / `aim_01_512.png`
- `aim_02.png` / `aim_02_512.png`
- `aim_03_34front.png` / `aim_03_34front_512.png` — 3/4 front

## Run

Mirrored to face right. This is the set Ethan chose.

- `run_00_flipped.png` / `run_00_flipped_512.png`
- `run_01_flipped.png` / `run_01_flipped_512.png`

Unflipped originals, kept for reference:

- `run_00.png` / `run_00_512.png`
- `run_01.png` / `run_01_512.png`

## Review contact sheets

RGB contact sheets for review.

- `review_aim_sheet.png` (2640×712)
- `review_aim_sheet_dark.png` (2640×712)
- `review_run_sheet.png` (1328×712)
- `review_run_flipped_sheet.png` (1040×540)
