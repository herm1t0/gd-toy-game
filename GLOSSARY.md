# Toy Game

A small top-down auto-battler: two **Bases**, three unit types, and a player whose only levers are what they buy at their **Base**.

## Match

**Match**:
One complete game, from both **Bases** at full health to one of them at zero.
_Avoid_: Game, round, session

**Base**:
A side's single structure: the source of its units and the only thing whose destruction ends a **Match**.
_Avoid_: Building, main building, HQ, spawn point

**Opponent**:
The second side in a **Match**: the AI in the slice, a human once PvP arrives.
_Avoid_: AI, bot, CPU

**Base fire**:
The **Base**'s own single-target ranged attack: weak, slow, and the only protection a side has at home. Its kills pay the defender the **Kill bounty**.
_Avoid_: Turret, tower, garrison shot

**Army cap**:
The limit on how many living units a side may field at once; a death frees a slot.
_Avoid_: Unit limit, supply, population

**Gold**:
The **Match**'s only currency, earned from the **Income tick** and the **Kill bounty** and spent on **Recruit**, **Upgrade** and **Research**; it never expires and has no cap.
_Avoid_: Money, cash, credits, resources

**Recruit**:
Spending gold at the **Base** to add a unit to your army. Instant, gold only, subject to the **Army cap**.
_Avoid_: Buy, summon, build

**Spawn queue**:
**Recruited** units waiting for a free **Army cap** slot. Gold is already spent; the unit enters play when a slot frees.

**Income tick**:
The passive grant of gold that every side receives on a fixed interval, independent of the battle.

**Income step**:
A point on the match clock at which the **Income tick** grows, so a **Match** cannot be starved into a standstill.

**Kill bounty**:
The gold awarded for killing an enemy unit, worth a fraction of what that unit cost to **Recruit**.

**Sudden death**:
The late-match rule that drains both **Bases**' health, guaranteeing a **Match** ends and awarding it to the side that did better.

**Concede**:
A human player's declaration of defeat. The AI opponent never does this.
_Avoid_: Surrender, forfeit

**Draw**:
The outcome where both **Bases** die on the same tick of **Sudden death**. The only non-decisive ending.

## Progression

**Upgrade**:
The repeatable purchase of a higher **Upgrade level** for one class at the **Base**: max HP and both ends of the damage range grow, nothing else, and every living or queued unit of that class gets it.
_Avoid_: Buff, tech, enhancement

**Upgrade level**:
One of three steps a class's stats can reach, I being the starting block; a level never touches attack interval, attack range or body radius.
_Avoid_: Tier, rank, star

**Research**:
The one-time purchase of a class's **Ability** at the **Base**; the class keeps it for the rest of the **Match**. Research never unlocks a unit type or a building.
_Avoid_: Tech, unlock, spell school

**Ability**:
A class's researched combat behaviour: an automatic damage burst fired in place of one attack when its cooldown is ready, with fixed numbers that no **Upgrade level** changes.
_Avoid_: Skill, spell, perk, proc

**Shockwave**:
The **Warrior**'s **Ability**: a burst centred on the warrior that damages every enemy **Unit** near it.
_Avoid_: Cleave, AoE slam, war stomp

**Called Shot**:
The **Archer**'s **Ability**: one arrow that cannot miss and hits its **Unit** harder than any attack in the game.
_Avoid_: Snipe, aimed shot, Pierce

**Meteor**:
The **Mage**'s **Ability**: a single **Splash** far wider than its basic attack's, at the same **Landing point**.
_Avoid_: Bomb, blast, fireball

**Build slot**:
The single slot an **Upgrade** or **Research** occupies while it builds at the **Base**; only one builds at a time. **Recruiting** never takes the slot.
_Avoid_: Queue, bench, construction site

**Build time**:
The delay between paying for an **Upgrade** or **Research** and its effect applying; a property of that purchase, not of its price.
_Avoid_: Cast time, construction time, research time

## Battlefield

**Lane**:
The whole playable battlefield: one straight, flat, open strip with a **Base** at each end.
_Avoid_: Map, arena, corridor, terrain

**Aggro range**:
The distance at which a unit notices enemy units and stops **Marching** to fight them; the same for every unit type.
_Avoid_: Detection range, sight, vision, engage radius

**March**:
A unit's default action: walking towards the enemy **Base** while no enemy unit is inside its **Aggro range**.
_Avoid_: Advance, push, auto-walk, patrol

**Reinforcement**:
A unit that has just left its own **Base** and is **Marching** to a fight already in progress.
_Avoid_: Wave, respawn, replacement

**Clash**:
One engagement between the two armies, from first contact until no enemy unit is left inside anyone's **Aggro range**; the pacing unit of a **Match**.
_Avoid_: Battle, skirmish, scrum

**Fight slot**:
A reserved contact position on one side of a target; only a unit holding one may attack that target.
_Avoid_: Attack position, spot, queue slot

**Second rank**:
Melee units holding back because every **Fight slot** on their target is taken.
_Avoid_: Backup, reserve, overflow

## Units

**Unit**:
One soldier on the **Lane** — a **Warrior**, **Archer** or **Mage** — put into play by **Recruit**.
_Avoid_: Minion, mob, character, pawn

**Warrior**:
The melee **Unit**: the most health, the shortest **Attack range**, and the only class that needs a **Fight slot** to attack.
_Avoid_: Fighter, tank, brute

**Archer**:
The **Unit** with the longest **Attack range**, single target only; the only class whose attacks can miss.
_Avoid_: Bowman, ranger, sniper

**Mage**:
The **Unit** with the shortest **Attack range** of the ranged classes, whose attacks **Splash**; it loses every duel but punishes stacked enemies.
_Avoid_: Wizard, caster, artillery

**Attack range**:
The distance at which a **Unit** stops to attack; a melee **Unit** must also hold a **Fight slot** on its target.
_Avoid_: Reach, weapon range

**Splash**:
A mage's damage, applied at full strength to every enemy **Unit** near where its attack lands.
_Avoid_: AoE, area damage, cleave

**Wind-up**:
The beat of an attack before its damage leaves the attacker; losing the target during it cancels the attack.
_Avoid_: Cast time, delay, animation lock

**Landing point**:
Where a ranged attack comes down; it damages a **Unit** only if it lands inside that **Unit**'s body, and a **Mage**'s **Splash** is measured from it.
_Avoid_: Impact point, hit roll, accuracy

## Presentation

**Side ring**:
The tinted ring on the ground under a **Unit** that marks which side it belongs to.
_Avoid_: Team colour, outline, marker, decal

**Hit flash**:
The brief white flash a **Unit** shows when it takes damage; the slice's only per-hit damage read on the field.
_Avoid_: Damage number, popup, floating text

**Splash ring**:
The circle drawn at a **Mage** attack's **Landing point**, showing the area its **Splash** covers.
_Avoid_: AoE indicator, blast radius
