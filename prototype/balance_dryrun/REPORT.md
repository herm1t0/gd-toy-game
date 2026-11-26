# Balance dry run — ticket #19

**Verdict: the table does not hold — but the failure is not a tuning offset. The match never reaches
the state the numbers are priced for.**

The economy is priced for an army that survives: ~20 recruits and 6–8 builds per side. In the pure
simulation at the numbers as written, a side recruits **77 units** and loses **74**, its army hovers at
**1–4 living units**, it **never reaches the 15-unit cap**, and it **buys 0–1 builds**. At the same
time the clock produces a bimodal match: either one side wins a clash and razes a Base in ~6 minutes,
or nobody can field a siege force and the match limps to sudden death at 12:00, where **11 of 12
sudden-death runs enter with both Bases at exactly the same HP** and therefore draw.

Reproduce: `dotnet run -c Release` in this folder (net10.0; no Godot, no dependencies).
Full numeric output: [RESULTS.md](RESULTS.md). 20 seeds per match-up (10 per orientation for the
greedy comparison).

## What the model is

A literal reading of #5/#6/#7/#11/#12/#13, in one file: a 120 × 40 lane, both Bases, instant
recruitment with a Spawn queue and the 15-unit cap, the income curve, bounty, one build slot,
II → III → Research with timings, six stats per class, one shared 0.25 s retarget tick, 6 fight slots
per unit and 8 per Base, melee Second rank, ranged landing-point spread and misses, mage splash,
the three abilities with cooldowns, base fire, sudden death, and #13's AI ladder plus a mass-first
greedy yardstick.

It is **not** the game. No navmesh, no avoidance, no collisions, no animation, no presentation, no
human controller, and no line-of-sight. Units move straight at 3 m/s and fire the moment range
allows, so fights resolve somewhat faster than #16's prototype measured (a 15v15 8/5/2 clash here is
**13.4 s** against #16's 16–19 s). One probe re-runs the mirror with all unit damage at 0.65 (fights
~1.5× longer) to check that the verdict does not hinge on that.

## Self-checks (all pass)

| Check | Result |
|---|---|
| No one-shot: largest roll 32 vs smallest pool 130 | 24.6% (cap 25%) |
| Passive income by 10:00 | 3,660 (300 start + 3,360) |
| Sudden death on untouched Bases | draw at 14:46 = 12:00 + 10,000/60 |
| 8 warriors vs 10,000 HP Base, base fire on | falls after 27 s of hitting (0:40 from spawn), 2 lost |
| 4/3/1 mixed vs Base | 0:51 from spawn, 2 lost |
| 8 archers vs Base | 0:55, **zero losses** (they out-range base fire — see finding 4) |
| One warrior vs Base | dies; its Base only falls to sudden death |
| 5v5 warriors | 4.8 s of fighting (#5 says 3–6 s) |
| 15v15 8/5/2 | 13.4 s, 4 survivors (#16 measured 16–19 s) |

## Answers to the ticket's questions

### Duration

| | |
|---|---|
| Runs | 20 mirror, AI vs AI |
| Outcome | 9 / 3 / **8 draws** |
| Median | **13:55** (target 8–13) |
| Range | 5:34 – 14:47 |
| Reached sudden death | **12 / 20** |

The median sits above the target and the distribution is not a ~10-minute curve at all. **8 of 20
matches ended before 12:00** (one side won a clash, converted, ~6 min) and **12 of 20 reached sudden
death**, of which 8 drew. The 15:00 ceiling is never breached because sudden death guarantees
14:47.

### Beats against #5's skeleton

| Beat | #5 | Sim median | Comment |
|---|---|---|---|
| First clash | 1:00 | **0:15** | 20/20 runs. 20 s to middle + both armies moving ⇒ contact at ~15 s |
| Upgrade level II started | 3:00 | **never** | 2 of 40 sides ever started a build; the two that did started at 0:40 |
| First Base damage | 6:00 | 8:06 | range 0:50 – 14:39 |
| A Base below 50% | 9:00 | 13:23 | i.e. only once sudden death is already draining it |
| Decided | 10:00 | 13:55 | bimodal: ~6:00 or 12:00+ |
| Duration | 8–13 (15 cap) | 13:55 | 8 draws at the ceiling |

### Purchases and slot idle

**0–1 purchases per side, median 0.** Build slot idle **94–100%** of the match. Idle *while a node
was affordable* is **~0.1%** — so the slot is not idle for want of gold; it is idle because every
gold piece goes into replacing dead units. Research: **0 nodes in 40 sides**, therefore **0 ability
casts** (finding 6).

The #11 budget predicts 6–8 purchases; the sim affords 0–1 because rule 1 of #13's ladder never stops
firing (finding 2).

### Saturation and banked gold

The 15-unit cap is **never reached** in 40 sides — not at 8:00, not at all. Peak observed army at a
minute mark is 3–6. Gold banked at the end is 0–90 (median 10), which looks healthy only because
nothing was bought.

### Comeback

Force-fed the "lost opening" (2 units deleted at 0:30 and 2 at 1:15): the side that lost them won
**8 / 20**, against **9 / 20** in the untouched mirror. **The first bad fight is not the match.**
The defender lever is real — base fire plus the 20 s walk home reliably holds small armies at home —
but it does not produce comeback tension, because the winner cannot sustain a siege either. The
comeback runs finish at **14:00+** and 14/20 reach sudden death.

### Sudden death

Fires in **12 / 20** mirror runs. **11 of those 12 enter with both Bases at equal HP**, so both hit
zero on the same tick and the match is a **draw**. When Bases differ it decides (the other 1 mirror
run). As written, sudden death does not "award the match to the side that did better" — it awards a
draw whenever neither side got through, which is the exact case it exists to resolve.

## Findings — what actually breaks

1. **The army never forms (root).** Steady state is 1–4 living units per side, with one death every
   ~11 s per side (5.4/min) and 77 recruits per side over ~14 min. At 100 gold per recruit and 4–8
   gold/s income, replacement spending (8–9 gold/s) eats the whole economy; there is no gold left
   for a 200/300/400 build, and no accumulation. #11's "12 units by 6:00, 15 by 8:00" requires
   almost no deaths before 6:00, while #6 puts first contact at 0:15 and #7 makes a 5v5 decisive in
   3–6 s.

2. **#13's ladder starves its own build ladder.** Rule 1 (recruit while census < armyTarget) fires on
   every poll whenever the army is under strength — which is always, under attrition. Rule 2 is
   unreachable, so the AI never upgrades, never researches, and never uses an ability. #13's "level II
   at ~3:00" budget assumes the 8 units survive to 3:00; one clash at 0:15 makes that impossible.
   Only 2 of 40 sides ever started a build (when they happened to win the opening untouched). The AI
   is also *weaker* than a mass-first policy: 4 wins to 8 (8 draws) across both orientations — its
   ramp target under-buys relative to income, so it fights the whole match outnumbered.

3. **#11's budget double-counts deaths.** 600–900 gold of bounty = 20–30 kills *per side*, but
   20 recruits + 3 starting units = 23 units ever; with 15 alive at the end at most 8 died. The
   table cannot be true of both a 15-unit army and a bounty-rich match.

4. **Base fire is out-ranged by archers.** #11 sets base fire to "10 m from the Base's edge"; the
   archer's range is 12 m. Measured: **8 archers kill a 10,000 HP Base with zero losses** (0:55 from
   spawn), exactly the failure #6's hand-off told #11 to avoid. Base fire range must be **≥ 12 m**
   (12.5 m gives the archer no free stand-off).

5. **Sudden death draws by construction.** Equal Base HP at 12:00 ⇒ identical drain ⇒ both die on
   the same tick. This is not a rare edge case: it is the normal outcome of a match that reached
   sudden death without a breakthrough (11/12 runs). Draining faster or slower does not change it.

6. **The progression and ability systems are never exercised.** 0 research nodes, 0 casts in 40 sides.
   #12's kit (15/70/60, 10/12/15 s) is untested by this run; #16 saw it only because the feel
   prototype spawned units for free. Any balance claim about abilities here is unfounded, not proven
   wrong.

7. **The beats contradict the geometry.** "First clash at 1:00" cannot coexist with instant recruit
   at 0:00 and 20 s to the middle; the sim contacts at 0:15 in every run. Likewise "first upgrade at
   3:00" is a knife-edge that assumes zero deaths (at 3:00 the passive budget leaves exactly 220
   gold against a 200 price).

## The numbers to change, and why

Ranked by how much of the failure each one removes. These are proposals for #11/#13/#5 to decide;
this run does not change the tickets.

1. **Army size vs replacement cost — the root.** Either:
   - **accept 3–6-unit armies** and re-price everything around them (ramp 3/4/5/6/6, cap ~8, Base HP
     down, research/upgrade prices to fit ~6 purchases); or
   - **raise income ~2× and slow sieges to match.** Verified: income ×2 makes builds appear
     (30/40 sides), but matches get *shorter* — 5:02 median — because bigger armies raze Bases
     faster. Adding Base 16,000 HP + sudden death 90/s only recovers 5:47. So a second lever is
     needed: Base HP ×2.5–3 (≈25–30k) or a slower siege.
2. **Base fire range 10 m → 12.5 m.** Removes the free archer siege (finding 4). One number.
3. **Sudden death needs a tie-break** before the drain (units alive, then gold, then total damage),
   or a drain that is not exactly symmetric. Otherwise a stalemate is a draw, not a loss.
4. **#11's budget needs one regime**: either 20–30 kills and no standing army, or a 15-unit army and
   ≤8 deaths. It cannot be both.
5. **#13's rule order** must change if the army is to have any quality: e.g. reserve a build price
   before recruiting, or gate rule 1 on a floor (census < target *and* gold > next node price). With
   rule 1 first, no attrition regime ever lets the AI build.
6. **#5's beats** need re-deriving from travel + recruitment: first clash ~0:20, not 1:00.

## Does the verdict depend on the model's simplifications?

No for the main one. With all unit damage at 65% (fights 1.5× longer): still **0/40 sides build**,
still **never saturated**, median duration 11:39, 6/20 sudden death. The no-progression result is
about the economy/policy interaction, not about how fast a fight resolves.

It *does* depend on the AI policy: both controllers spend on sight and only one build ordering is
tested. A human who banks and times purchases is not modelled, and could reach the 6–8 purchases #11
predicts — but the AI the spec ships cannot.

## Files

- `Program.cs` — the model (throwaway; no abstractions, no tests by design).
- `RESULTS.md` — the captured run, including every aggregate table.
- `README.md` — what this is and how to run it.
