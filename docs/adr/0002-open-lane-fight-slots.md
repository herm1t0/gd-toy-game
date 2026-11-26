# One open lane; blocking is fight slots, not bodies

Battlefield (#6) is a single flat 120 × 40 m **Lane** with a **Base** at each end, no chokepoints and no terrain, and melee blocking is modelled as reserved **Fight slots** on a target rather than unit-vs-unit collision. Chokepoints and body-blocking are the obvious way to make a front line matter, but #3's research found that Godot's avoidance jams head-on in tight space, knows nothing about the navmesh or physics, and that stacking physics collision on top of avoidance produces shoving and stalemates. A wide lane plus slots produces the same gameplay — limited frontage, a second rank, a ranged wing that survives — with exactly one movement authority.

**Considered options:** three lanes (splits a 15-unit army and multiplies pathing and AI); a wide open arena (fights fragment and units walk past each other); chokepoints with physics body-blocking (jams, two movement authorities); nearest-enemy with no slots (the whole army piles onto one target and frontage stops existing).

**Consequences:** units on opposite sides interpenetrate visually at contact — the fix is a larger avoidance radius, never collision. A unit with no free slot cannot attack at all, even standing beside an enemy. Any future map with real obstacles reopens this. #16 must confirm the interpenetration reads as a melee and not as a bug.
