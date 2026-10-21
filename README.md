# bloom

A neon platformer where **everything glows**. Hop across floating platforms, dodge spikes, collect every coin and reach the finish line across **100 levels** of rising difficulty. Spend coins on new glowing characters.

- Landscape, 1280x720 base, scales to any aspect ratio (phones, tablets, desktop, web)
- Main menu: Play / Settings / Exit (Exit is hidden on web and iOS, where apps don't quit themselves)
- 100 procedurally generated, deterministic levels, 10 colour themes, difficulty Easy -> Insane
- Moving platforms (level 11+), crumbling platforms (26+), checkpoints on long levels
- Stars: 1 = finish, 2 = every coin, 3 = every coin without dying
- 12 unlockable characters (orb, cube, prism, hexa, pulse, crystal, halo, starling, wisp, fireball, plasma, nova) with their own trails
- Fully original, synthesised audio (SFX + two music loops), music/SFX on/off and volume in Settings
- No third-party art or audio. Font: Outfit (SIL OFL, see `assets/fonts/OFL.txt`)

## Controls
| | Move | Jump | Pause |
|---|---|---|---|
| Keyboard | A/D or arrows | Space / W / Up | Esc or P |
| Gamepad | D-pad / left stick | A or B | Start |
| Touch | on-screen buttons | on-screen button | pause button |

## Project layout
```
src/core      pure game logic: Sim (physics), Levels (generator), Skins, Bot, Fx
src/autoload  Save (progress/settings), Sfx (audio), Nav (screens + transitions)
src/screens   splash, main_menu, level_select, game, shop, settings
src/ui        design-system widgets (GlowButton, Switch, Backdrop shader, icons...)
tools         asset generators (art, audio) and build script
tests         headless bot that beats the levels using the real simulation
web           branded HTML shell for the web export
```

## Develop
Requires Godot **4.5.x** (GL Compatibility renderer). Open the folder in Godot and press F5.

```
python tools/gen_art.py      # regenerate icon / splash / logo   (needs Pillow)
python tools/gen_audio.py    # regenerate all audio              (needs numpy)
godot --headless --path . --script tests/bot_test.gd   # prove every level is beatable
```

## Build
`pwsh tools/build.ps1` exports Windows, Linux, macOS, Web, Android and the iOS Xcode project into `build/`. See [PUBLISHING.md](PUBLISHING.md) for signing and store steps.
