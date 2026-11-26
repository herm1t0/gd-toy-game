# Balance and pacing dry run (ticket #19)

**Throwaway.** Not slice code, not a design, not a test suite. Delete it once #19 is resolved; the
answer lives on the issue, not here.

One C# console program that plays the slice headlessly in the pure simulation of ADR-0006: both
Bases, the lane, three classes with #7's stat blocks, #11's prices and income curve, one build slot,
#12's abilities, #13's AI ladder, sudden death. No Godot, no navigation, no rendering.

The question it answers: **does a full match at the written numbers land where #5's pacing skeleton
says it should?**

```bash
dotnet run -c Release
```

Writes `RESULTS.md` (all aggregate tables) next to this file and prints the same to stdout. Runtime
is a few seconds for 20 seeds × 7 scenarios.

- [REPORT.md](REPORT.md) — the verdict and the numbers to change, with the evidence.
- [RESULTS.md](RESULTS.md) — the captured run.
- `Program.cs` — the model itself; top of file lists the simplifications.

Deliberately absent: navmesh and avoidance, animations, presentation, any human controller, and a
test project. What is present is only what arithmetic and the clock need.
