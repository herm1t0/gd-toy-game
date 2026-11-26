# Gray-box combat feel test — wayfinder #16

**Throwaway.** This is not game code: no tests, no architecture, nothing here survives the
slice. It exists to answer one question from #6/#7/#9/#12:

> Is the combat readable, brutal, deliberate, and watchable? What must change before
> numbers are locked?

## Run

```text
"C:\Users\herm1t\Godot_v4.8-beta5_mono_win64\Godot_v4.8-beta5_mono_win64.exe" ^
  --path "C:\Users\herm1t\Documents\Godot Projects\toy-game" ^
  prototype/combat_feel/combat_feel.tscn
```

Opens on a 15-a-side mixed clash (8 warriors, 5 archers, 2 mages). Pan along the lane with
`A`/`D` in the side-on camera and `W`/`S` in the down-the-lane camera. `V` swaps camera mode,
`1`/`2`/`3` widen the framing from #9's 48 px/m. `Reset` replays the same fight (one fixed seed).

- `R W/A/M` / `B W/A/M` — spawn one free unit for red or blue.
- `res W/A/M` — free research switch per side, per class. Off = no abilities.
- `auto ramp` — both sides spawn on #13's ramp table, no gold, for a whole-match watch.

## What is faithful

Implemented from the resolved tickets, numbers unchanged:

- **#6** 120 × 40 m lane, bases at the ends, march at 3 m/s, 20 m aggro, sticky targets,
  one 0.25 s engagement tick, 6 fight slots per unit target (8 on a base), second rank,
  ranged posture with no kiting, base fire that never outranks a unit.
- **#7** the three stat blocks, wind-up 0.2/0.3/0.4 s, interval from swing start, damage
  rolled at impact, 20 m/s projectiles, 0.5 m landing spread, body-radius hit test,
  2.5 m mage splash with one shared roll, death removes the unit and sinks the mesh.
- **#11** base 10,000 HP, 15–25 damage every 1.2 s, range 14 m.
- **#12** Shockwave / Called Shot / Meteor, damage-only, fired in place of one attack,
  cooldowns 10/12/15 s, never on a base, one burst per cast.
- **#9** ~48 px/m, perspective 45° FOV at 60° pitch, pan on one axis, team ring decals
  instead of model colour, health bars on damage only, splash-ring decals.

The dashboard counts what the verdict needs: last clash length, average clash length,
average time from engagement to death, and kills per side. Kills and clashes also print
to stdout, so a headless run gives numbers without watching:

```text
Godot ..._console.exe --headless --path . prototype/combat_feel/combat_feel.tscn ^
  --fixed-fps 5 --quit-after 400
```

## What is shortcut (do not judge these here)

- **No navmesh.** Straight steering plus a light separation push instead of
  `NavigationAgent3D` + 2D avoidance. Interpenetration is therefore shown at its worst,
  not at #3's calibrated setting.
- **No animations, no audio.** The 0.2/0.3/0.4 s wind-up tell is a body lean, not a
  weapon raise; there is no flinch and no 0.8 s death clip beyond a sink.
- **No economy, upgrades or build slot.** Spawns are free; research is a checkbox, so
  "is 15 damage worth 300 g" cannot be answered here — only "does 15 damage read".
- **No auto-follow camera, no desaturation pass, no real art.** #9's palette and
  silhouette checks need the real assets.
- **Base slots are fixed points** on the facing edge, not a moving ring; the base is
  attacked from the front only, which matches the navmesh hole.
