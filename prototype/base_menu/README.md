# Base menu wireframe — wayfinder #17

**Throwaway.** Not game code: no tests, no architecture, nothing here survives the
slice. It exists to answer one question from #14/#8/#11:

> Can Recruit, Upgrade and Research fit one screen and stay readable during a fight?
> How many clicks per action, and what is confusing?

## Run

```text
"C:\Users\herm1t\Godot_v4.8-beta5_mono_win64\Godot_v4.8-beta5_mono_win64.exe" ^
  --path "C:\Users\herm1t\Documents\Godot Projects\toy-game" ^
  prototype/base_menu/base_menu.tscn
```

Opens at 1920×1080 on #16's 15-a-side clash, with the Base menu already open.

| Key | What |
| --- | --- |
| `B` / `Esc` | open / close the Base menu |
| `1` `2` `3` | recruit Warrior / Archer / Mage (one click, strip always visible) |
| `F1` `F2` `F3` | strip fit **A** / **B** / **C** (see below) |
| `R` | restart the clash behind the HUD |
| `T` | clock +60 s (to reach sudden death and the income steps) |
| `F5` | +1000 gold (to see every cell state) |
| `F12` | screenshot into `prototype/base_menu/shots/` |

The top-left overlay is **DEBUG**: it prints the live fit measurement and the click count,
so the numbers below can be re-read while playing.

## The answer the wireframe gives

Measured at 1920×1080 with the built-in font at #14's 16 px floor, worst-case content
(four-digit gold, `15 / 15` army with a 12-unit queue, a long build name in the slot):

| | Worst-case strip width | 1,920 px? | Bottom third (strip + menu + 8) |
| --- | --- | --- | --- |
| **Fit A** — everything in one 120 px row | **2,366 px** | over by 446 | 353 of 360 |
| **Fit B** — two rows: score row over cluster row | **1,564 px** | fits, 356 spare | 353 of 360 |
| **Fit C** — reads in the 120 px row, recruits in a 56 px row above | **1,901 px** | fits by 19 px | **409 of 360 → over** |

- **#14's one-row strip does not fit.** Fit A clips the enemy Base bar at 1,920 px even
  with today's short strings (`shots/fitA-menu.png`). It is not a font problem that a
  smaller font would fix within #14's ≥16 px rule: it is 446 px over.
- **Fit B is the only fit that clears both budgets.** 356 px of slack in the strip,
  and the menu at **225 px of #14's 240 px** (231 px when a cell is building).
- **Fit C buys strip room by breaking the bottom-third rule.** Recruits are reachable
  in one click either way; the cost is 49 px of lane.
- **The menu itself fits, with 9 px to spare at its tallest.** Six rows of 2 lines
  plus a progress bar is the whole 240 px budget. A third line in any cell (a reject
  reason under the effect, say) would overflow it.

Clicks per action, counted by the DEBUG overlay: **Recruit is always 1** (the buttons
never leave the strip). **Upgrade and Research are 2 from a closed menu, 1 once it is
open**, because a purchase does not close it (#14) — a double-buy is two clicks.

## What is faithful

Implemented from the resolved tickets:

- **#14** bottom third only; strip fixed, menu grows above it, never pauses the match;
  78% panels, 1 px separators, built-in font 16 px, flat shapes and text (no icons);
  read order own → clock → enemy; both Base bars at the strip's outer edges, mirrored;
  `%` not HP; gold with `+40 per 10 s` and the next step inline; army with the queue
  total; build slot with a 1 px progress bar; enemy levels `W II · A II · M I+`; the
  six upgrade-cell states; recruit greys under 100 g and stays enabled at 15/15 with
  `×N`; `B`/`Esc`; `1`/`2`/`3`; a single transient line; no damage numbers, no
  cooldown UI, no per-death message.
- **#8/#11** Upgrade I/II/III with `II` before `III` (`II first`), 200/400 g at 20/40 s,
  ×1.25/×1.55 as literal multipliers; Research 300 g at 30 s, one node per class;
  `OWNED` / `MAX`; one shared slot, gold spent on start.
- **#16** the 15-a-side clash running behind, so "readable while the menu is open" is
  judged on a real fight, not a mock.

## What is shortcut (do not judge these here)

- **The economy is a stand-in.** Gold, income, the clock and the build slot are local
  state in this file, not `MatchSnapshot` (#10). Only army counts and Base HP come from
  #16's sim. The queue is not a real sim event: it drains when the clash frees a slot.
- **The enemy's slot is a timer**, not #13's policy: it finishes and bumps Archer to III.
- **No slide-in** (#9's motion), no audio, no Shell (#15), no end screen, no AI.
- **The lane is #16's gray box**, not the slice's art: only the HUD's fit is being
  judged, not the fight's look.
- **Fit A's overflow is deliberate** — it is the measurement, not a bug to fix.

## Open questions this raised (for the verdict)

1. **Fit B** — the second row splits reads (row 1) from purchases + army (row 2).
   Does the eye still find Base HP and gold in one glance?
2. **The reject reason displaces the effect line.** In `need 60 g` / `slot busy` /
   `II first` the cell shows the reason where the multiplier was, so the effect is
   only visible on cells you can currently buy. Acceptable, or does the cell need a
   third line (which the 240 px budget cannot pay for)?
3. **What wins when a cell is both unaffordable and the slot is busy?** The wireframe
   shows `slot busy`; the other reason never appears.
4. **The transient line has no home.** #14 puts it "directly above the strip" and the
   menu also grows above the strip; strip 120 + menu 231 already spends 351 of the
   360 px bottom third. The wireframe draws the line in the lane band, 8 px above the
   bottom third — that is the only place left.
5. **The clock is 170 px wide and never moves**, so `04:12 → SUDDEN DEATH` does not
   shift the row. Worth the width?
6. **Recruit buttons carry the hint** (`front line` / `long range` / `splash`) under
   `Warrior · 100 · 1`. Three two-line buttons are the widest thing in the strip
   (~480 px). Drop the hint to a single line and the strip gets 60 px back.
