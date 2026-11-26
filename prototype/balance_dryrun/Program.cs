// Throwaway balance dry run for ticket #19. NOT slice code, NOT a design.
// Pure arithmetic + clock model of the slice described in #5/#6/#7/#11/#12/#13:
// no Godot, no navigation, no avoidance, no rendering, no tests beyond the
// self-checks printed by `dotnet run`.

using System.Text;

namespace BalanceDryRun;

public enum Kind { Warrior = 0, Archer = 1, Mage = 2 }
public enum Policy { None = 0, Ai = 1, Greedy = 2 }
public enum Shape { None = 0, Burst, Locked, Landing }

static class K
{
    // #6 lane + #7 unit constants
    public const double March = 3.0;
    public const double Aggro = 20.0;
    public const double Spread = 0.5;
    public const double Flight = 20.0;
    public const double Dt = 1.0 / 60.0;

    // #5 / #11 economy
    public static int ArmyCap = 15;
    public const int RecruitCost = 100;
    public const int Bounty = 30;
    public static int BaseHp = 10_000;
    public const double BaseFireRange = 10.0;   // #11: "10 m from the Base's edge"
    public const double BaseFireInterval = 1.2;
    public const double MageSplash = 2.5;       // #7 basic attack, not an ability
    public static double SuddenDeathFrom = 720.0;
    public static double SuddenDeathDps = 60.0;

    public static readonly int[] UpgradeCost = { 0, 200, 400 };
    public static readonly double[] UpgradeTime = { 0, 20, 40 };
    public const int ResearchCost = 300;
    public const double ResearchTime = 30;
    public static readonly double[] Mult = { 1.0, 1.25, 1.55 };

    // Sensitivity knobs only: 1.0 is the table as written (#7). Used by probes that
    // stretch fights or fatten income to check whether the pacing verdict depends on them.
    public static double DamageScale = 1.0;
    public static double IncomeMultiplier = 1;

    public static readonly Def[] Defs =
    {
        // hp, dmg min, max, interval, range, radius, windup, ability dmg, ability radius, ability cd, shape
        new(Kind.Warrior, 240, 22, 32, 0.55, 1.6, 0.55, 0.2, 15, 2.5, 10, Shape.Burst),
        new(Kind.Archer, 150, 22, 32, 1.00, 12.0, 0.45, 0.3, 70, 0.0, 12, Shape.Locked),
        new(Kind.Mage, 130, 20, 30, 1.10, 9.0, 0.45, 0.4, 60, 4.0, 15, Shape.Landing),
    };

    public static Def Def(Kind k) => Defs[(int)k];
    public static readonly string[] Names = { "warrior", "archer", "mage" };

    public static double BaseMinX(int team) => team == 0 ? 0 : 110;
    public static double BaseMaxX(int team) => BaseMinX(team) + 10;
    public static double BaseCenterX(int team) => BaseMinX(team) + 5;
    public const double BaseMinY = 15, BaseMaxY = 25;

    public static double DistToBase(int baseTeam, double x, double y)
    {
        double cx = Math.Clamp(x, BaseMinX(baseTeam), BaseMaxX(baseTeam));
        double cy = Math.Clamp(y, BaseMinY, BaseMaxY);
        return Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
    }
}

sealed record Def(Kind Kind, int Hp, int DmgMin, int DmgMax, double Interval, double Range,
    double Radius, double Windup, int AbilityDamage, double AbilityRadius, double AbilityCooldown, Shape Shape)
{
    public double Dps => (DmgMin + DmgMax) / 2.0 / Interval;
}

sealed class Unit
{
    public int Id;
    public Kind Kind;
    public int Team;
    public double X, Y, VX, VY;
    public int Hp, MaxHp, DmgMin, DmgMax, Level = 1;
    public bool Alive = true;
    public int TargetUnit = -1, TargetBase = -1;
    public bool HasSlot;
    public double NextSwingAt, PendingAt = -1, AbilityReadyAt;
    public bool PendingAbility;
    public int PendingTarget = -1, PendingBase = -1;
    public readonly int[] Slots = new int[6];   // fight slots this unit offers its attackers

    public Def D => K.Def(Kind);
    public double Dps => (DmgMin + DmgMax) / 2.0 / D.Interval;
}

sealed class Shot
{
    public double LandAt, X, Y;
    public int TargetId = -1, Team;
    public Kind Source;
    public bool IsAbility;
    public double Splash;       // 0 = single target
    public int Damage;
}

public sealed class Side
{
    public int Team;
    public Policy Policy;
    public int Gold = 300;   // #11 starting gold
    public int BaseHp = K.BaseHp;
    public readonly int[] Level = { 1, 1, 1 };
    public readonly bool[] Researched = new bool[3];

    public readonly List<Kind> Queue = new();
    public int BuildClass = -1;
    public bool BuildIsResearch;
    public double BuildEndsAt;

    public readonly int[] BaseSlots = new int[8];
    public double NextBaseFireAt;
    public double NextPollAt;

    // metrics
    public int Kills, Recruits, Purchases, Casts;
    public readonly int[] CastsByKind = new int[3];
    public double BuildIdleSeconds, BuildIdleRichSeconds;
    public double? FirstBuildAt, SaturatedAt, FirstBaseDamageTakenAt;
    public int BaseDamageDealt;
    public double RecruitGold, BuildGold;
}

sealed record Sample(double T, int Hp0, int Hp1, int Gold0, int Gold1, int Army0, int Army1);

sealed record Result(
    int Seed, string Scenario, int Winner, string EndReason, double Duration,
    double? FirstClash, double? FirstBaseDamage, double? Base0Half, double? Base1Half,
    int Kills0, int Kills1, int Recruits0, int Recruits1,
    double? FirstBuild0, double? FirstBuild1,
    int Purchases0, int Purchases1,
    double BuildIdle0, double BuildIdle1, double BuildIdleRich0, double BuildIdleRich1,
    double? Saturated0, double? Saturated1,
    int Gold0, int Gold1, int BaseHp0, int BaseHp1,
    bool SuddenDeath, int Casts0, int Casts1,
    int LevelSum0, int LevelSum1, int Researched0, int Researched1,
    int? HpAtSudden0, int? HpAtSudden1);

sealed class Sim
{
    public readonly Side[] Sides =
    {
        new() { Team = 0 },
        new() { Team = 1 },
    };

    readonly List<Unit> units = new();
    readonly List<Shot> shots = new();
    public readonly Random Rng;
    public readonly string Scenario;
    public long Tick;
    public double T => Tick * K.Dt;
    int nextId = 1;

    public bool Ended;
    public int Winner = -1;
    public string EndReason = "";
    public double? FirstClashAt, FirstBaseDamageAt;
    public double? Base0HalfAt, Base1HalfAt;
    public bool SuddenDeathFired;
    public int? HpAtSudden0, HpAtSudden1;
    double sdAcc;
    public readonly List<Sample> Samples = new();
    public readonly List<(double At, int Team, int Count)> ScheduledLosses = new();

    public Sim(int seed, Policy p0, Policy p1, string scenario)
    {
        Rng = new Random(seed);
        Sides[0].Policy = p0;
        Sides[1].Policy = p1;
        Scenario = scenario;
        Sides[0].NextPollAt = 0;
        Sides[1].NextPollAt = 0;      // both sides poll on the same ticks
    }

    // ---------- lookups ----------
    public Side Other(int team) => Sides[1 - team];
    Unit? ById(int id) => id <= 0 ? null : units.FirstOrDefault(u => u.Id == id);
    int Living(int team) => units.Count(u => u.Alive && u.Team == team);
    int Census(int team, Kind k) =>
        units.Count(u => u.Alive && u.Team == team && u.Kind == k) + Sides[team].Queue.Count(q => q == k);
    int Census(int team) => units.Count(u => u.Alive && u.Team == team) + Sides[team].Queue.Count;

    static double Dist(Unit a, Unit b) => Math.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Y - b.Y) * (a.Y - b.Y));
    static double DistXY(double x0, double y0, double x1, double y1) =>
        Math.Sqrt((x0 - x1) * (x0 - x1) + (y0 - y1) * (y0 - y1));

    // alternate processing order so neither team gets the first-strike slot every tick
    IEnumerable<Unit> InOrder() => (Tick & 1) == 0 ? units : Enumerable.Reverse(units);
    Side[] SideOrder() => (Tick & 1) == 0 ? new[] { Sides[0], Sides[1] } : new[] { Sides[1], Sides[0] };

    // ---------- unit lifecycle ----------
    void ApplyStats(Unit u, bool fill)
    {
        var d = u.D;
        double m = K.Mult[Sides[u.Team].Level[(int)u.Kind] - 1];   // Level is 1-based
        u.MaxHp = (int)Math.Round(d.Hp * m, MidpointRounding.AwayFromZero);
        u.DmgMin = (int)Math.Round(d.DmgMin * m, MidpointRounding.AwayFromZero);
        u.DmgMax = (int)Math.Round(d.DmgMax * m, MidpointRounding.AwayFromZero);
        u.Level = Sides[u.Team].Level[(int)u.Kind];
        if (fill) u.Hp = u.MaxHp;
    }

    public Unit Spawn(int team, Kind kind, double x, double y)
    {
        var u = new Unit { Id = nextId++, Kind = kind, Team = team, X = x, Y = y };
        ApplyStats(u, true);
        u.NextSwingAt = T;
        units.Add(u);
        return u;
    }

    void SpawnFresh(int team, Kind kind)
    {
        double x = team == 0 ? 14 : 106;
        double y = 20 + (Rng.NextDouble() - 0.5) * 2.0;   // tiny spread so bodies do not stack exactly
        Spawn(team, kind, x, y);
    }

    void Recruit(Side s, Kind k)
    {
        if (s.Gold < K.RecruitCost) return;
        s.Gold -= K.RecruitCost;
        s.Recruits++;
        s.RecruitGold += K.RecruitCost;
        if (Living(s.Team) >= K.ArmyCap) { s.Queue.Add(k); return; }
        SpawnFresh(s.Team, k);
    }

    void Deploy(int team)
    {
        var s = Sides[team];
        while (Living(team) < K.ArmyCap && s.Queue.Count > 0)
        {
            var k = s.Queue[0];
            s.Queue.RemoveAt(0);
            SpawnFresh(team, k);
        }
    }

    // ---------- damage ----------
    int Roll(Unit u) => Scale(Rng.Next(u.DmgMin, u.DmgMax + 1));
    public static int Scale(int dmg) => Math.Max(1, (int)Math.Round(dmg * K.DamageScale));

    void HurtUnit(Unit target, int dmg, int killerTeam)
    {
        if (!target.Alive) return;
        target.Hp -= dmg;
        if (target.Hp <= 0) Kill(target, killerTeam);
    }

    void Kill(Unit u, int killerTeam, bool payBounty = true)
    {
        if (!u.Alive) return;
        u.Alive = false;
        if (payBounty)
        {
            Sides[killerTeam].Gold += K.Bounty;
            Sides[killerTeam].Kills++;
        }
        FreeSlots(u.Id);

        // #7: a normal swing whose target dies mid-wind-up is cancelled and restarted;
        // an ability cast already started still resolves where it was aimed.
        foreach (var a in units)
        {
            if (!a.Alive || a.PendingAt < 0 || a.PendingAbility) continue;
            if (a.PendingTarget != u.Id) continue;
            a.PendingAt = -1;
            a.PendingTarget = -1;
            a.NextSwingAt = T;
        }

        Deploy(u.Team);
    }

    void DamageBase(int team, int dmg, int attackerTeam, bool countsAsAttack)
    {
        var s = Sides[team];
        if (s.BaseHp <= 0) return;
        s.BaseHp = Math.Max(0, s.BaseHp - dmg);
        Sides[attackerTeam].BaseDamageDealt += dmg;
        if (countsAsAttack)
        {
            FirstBaseDamageAt ??= T;
            s.FirstBaseDamageTakenAt ??= T;
        }
        if (s.BaseHp < K.BaseHp / 2)
        {
            if (team == 0) Base0HalfAt ??= T;
            else Base1HalfAt ??= T;
        }
    }

    // ---------- slots ----------
    void FreeSlots(int unitId)
    {
        foreach (var u in units)
        {
            for (int i = 0; i < u.Slots.Length; i++)
                if (u.Slots[i] == unitId) u.Slots[i] = 0;
        }
        foreach (var s in Sides)
            for (int i = 0; i < s.BaseSlots.Length; i++)
                if (s.BaseSlots[i] == unitId) s.BaseSlots[i] = 0;
        var holder = ById(unitId);
        if (holder != null) holder.HasSlot = false;
    }

    void DropSlot(Unit u)
    {
        if (u.HasSlot) FreeSlots(u.Id);
        u.HasSlot = false;
    }

    // ---------- targeting, on the shared 0.25 s tick ----------
    void Retarget()
    {
        foreach (var u in units)
        {
            if (!u.Alive) continue;

            if (u.TargetUnit >= 0)
            {
                var t = ById(u.TargetUnit);
                if (t == null || !t.Alive)
                {
                    u.TargetUnit = -1;
                    DropSlot(u);
                }
            }

            Unit? near = null;
            double best = double.MaxValue;
            foreach (var e in units)
            {
                if (!e.Alive || e.Team == u.Team) continue;
                double d = Dist(u, e);
                if (d <= K.Aggro && d < best) { best = d; near = e; }
            }

            if (u.TargetUnit < 0)
            {
                if (near != null)
                {
                    if (u.TargetBase >= 0) { DropSlot(u); u.TargetBase = -1; }
                    u.TargetUnit = near.Id;
                }
                else if (u.TargetBase < 0)
                {
                    u.TargetBase = 1 - u.Team;
                }
            }
        }

        // melee frontage: 6 slots per unit target, 8 per Base, first-come on this tick
        foreach (var u in units)
        {
            if (!u.Alive || u.Kind != Kind.Warrior || u.HasSlot) continue;
            var d = u.D;
            if (u.TargetUnit >= 0)
            {
                var t = ById(u.TargetUnit);
                if (t == null || !t.Alive) continue;
                if (Dist(u, t) - t.D.Radius > d.Range + 4.0) continue;
                int idx = Array.IndexOf(t.Slots, 0);
                if (idx >= 0) { t.Slots[idx] = u.Id; u.HasSlot = true; }
            }
            else if (u.TargetBase >= 0)
            {
                var b = Sides[u.TargetBase];
                if (K.DistToBase(u.TargetBase, u.X, u.Y) > d.Range + 3.0) continue;
                int idx = Array.IndexOf(b.BaseSlots, 0);
                if (idx >= 0) { b.BaseSlots[idx] = u.Id; u.HasSlot = true; }
            }
        }
    }

    // ---------- attacks ----------
    void StartSwing(Unit u, Unit? tgt, int baseTeam)
    {
        var d = u.D;
        bool ability = tgt != null
                       && Sides[u.Team].Researched[(int)u.Kind]
                       && T >= u.AbilityReadyAt
                       && Dist(u, tgt) - tgt.D.Radius <= d.Range + 0.05;

        u.PendingAbility = ability;
        u.PendingAt = T + d.Windup;
        u.PendingTarget = tgt?.Id ?? -1;
        u.PendingBase = baseTeam;
        u.NextSwingAt = T + d.Interval;

        if (ability)
        {
            u.AbilityReadyAt = T + d.AbilityCooldown;
            Sides[u.Team].Casts++;
            Sides[u.Team].CastsByKind[(int)u.Kind]++;
        }
    }

    void ResolveSwing(Unit u)
    {
        if (u.PendingAbility) { FireAbility(u); return; }

        if (u.PendingBase >= 0)
        {
            if (Sides[u.PendingBase].BaseHp > 0)
                DamageBase(u.PendingBase, Roll(u), u.Team, true);
            return;
        }

        var t = ById(u.PendingTarget);
        if (t == null || !t.Alive) return;   // swing lost with its target

        if (u.Kind == Kind.Warrior) HitUnit(t, Roll(u), u.Team);
        else FireShot(u, t);
    }

    void HitUnit(Unit target, int dmg, int killerTeam)
    {
        FirstClashAt ??= T;
        HurtUnit(target, dmg, killerTeam);
    }

    void FireShot(Unit u, Unit t)
    {
        double d = Dist(u, t);
        double flight = Math.Max(0.05, d / K.Flight);
        double px = t.X + t.VX * flight, py = t.Y + t.VY * flight;
        flight = Math.Max(0.05, DistXY(u.X, u.Y, px, py) / K.Flight);
        px = t.X + t.VX * flight;
        py = t.Y + t.VY * flight;

        if (u.Kind == Kind.Archer || u.Kind == Kind.Mage)
        {
            // one 0.5 m spread disc, both classes (#7)
            double ang = Rng.NextDouble() * Math.PI * 2;
            double r = K.Spread * Math.Sqrt(Rng.NextDouble());
            px += r * Math.Cos(ang);
            py += r * Math.Sin(ang);
        }

        shots.Add(new Shot
        {
            LandAt = T + flight, X = px, Y = py, TargetId = t.Id, Team = u.Team,
            Source = u.Kind, IsAbility = false,
            Splash = u.Kind == Kind.Mage ? K.MageSplash : 0,
            Damage = Roll(u),
        });
    }

    void FireAbility(Unit u)
    {
        var d = u.D;
        switch (d.Shape)
        {
            case Shape.Burst:   // Shockwave: resolves on the caster's body, no projectile
                foreach (var e in units)
                    if (e.Alive && e.Team != u.Team && Dist(u, e) <= d.AbilityRadius)
                        HitUnit(e, Scale(d.AbilityDamage), u.Team);
                break;

            case Shape.Locked:   // Called Shot: target-locked, cannot miss
            {
                var t = ById(u.PendingTarget);
                if (t == null || !t.Alive) return;
                shots.Add(new Shot
                {
                    LandAt = T + Math.Max(0.05, Dist(u, t) / K.Flight),
                    X = t.X, Y = t.Y, TargetId = t.Id, Team = u.Team, Source = u.Kind,
                    IsAbility = true, Splash = 0, Damage = Scale(d.AbilityDamage),
                });
                break;
            }

            case Shape.Landing:   // Meteor: landing point, then 4.0 m splash
            {
                var t = ById(u.PendingTarget);
                double tx = t?.X ?? u.X, ty = t?.Y ?? u.Y;
                double flight = Math.Max(0.05, DistXY(u.X, u.Y, tx, ty) / K.Flight);
                double px = tx + (t?.VX ?? 0) * flight, py = ty + (t?.VY ?? 0) * flight;
                double ang = Rng.NextDouble() * Math.PI * 2;
                double r = K.Spread * Math.Sqrt(Rng.NextDouble());
                px += r * Math.Cos(ang);
                py += r * Math.Sin(ang);
                shots.Add(new Shot
                {
                    LandAt = T + flight, X = px, Y = py, TargetId = t?.Id ?? -1, Team = u.Team,
                    Source = u.Kind, IsAbility = true, Splash = d.AbilityRadius, Damage = Scale(d.AbilityDamage),
                });
                break;
            }
        }
    }

    void ResolveShots()
    {
        for (int i = shots.Count - 1; i >= 0; i--)
        {
            var s = shots[i];
            if (T < s.LandAt) continue;
            shots.RemoveAt(i);

            if (s.Splash > 0)
            {
                // one roll shared by every unit in the sphere; units only, never a Base
                foreach (var e in units)
                    if (e.Alive && e.Team != s.Team && DistXY(s.X, s.Y, e.X, e.Y) <= s.Splash)
                        HitUnit(e, s.Damage, s.Team);
                continue;
            }

            var t = ById(s.TargetId);
            if (t == null || !t.Alive) continue;   // a shot in flight is lost with its target

            if (s.IsAbility) HitUnit(t, s.Damage, s.Team);
            else if (DistXY(s.X, s.Y, t.X, t.Y) <= t.D.Radius) HitUnit(t, s.Damage, s.Team);
        }
    }

    void BaseFire()
    {
        foreach (var s in SideOrder())
        {
            if (s.BaseHp <= 0 || T < s.NextBaseFireAt) continue;
            Unit? tgt = null;
            double best = double.MaxValue;
            foreach (var e in units)
            {
                if (!e.Alive || e.Team == s.Team) continue;
                if (K.DistToBase(s.Team, e.X, e.Y) > K.BaseFireRange) continue;
                double d = K.DistToBase(s.Team, e.X, e.Y);
                if (d < best) { best = d; tgt = e; }
            }
            if (tgt == null) continue;
            s.NextBaseFireAt = T + K.BaseFireInterval;
            HurtUnit(tgt, Rng.Next(15, 26), s.Team);
        }
    }

    // ---------- movement ----------
    void Move()
    {
        foreach (var u in units)
        {
            if (!u.Alive) continue;
            u.VX = 0;
            u.VY = 0;

            double gx, gy, stop;
            if (u.TargetUnit >= 0)
            {
                var t = ById(u.TargetUnit);
                if (t == null || !t.Alive) continue;
                stop = u.D.Range + t.D.Radius - 0.05 + (u.Kind == Kind.Warrior && !u.HasSlot ? 3.0 : 0.0);
                gx = t.X;
                gy = t.Y;
                if (Dist(u, t) <= stop) continue;
            }
            else if (u.TargetBase >= 0)
            {
                if (K.DistToBase(u.TargetBase, u.X, u.Y) <= u.D.Range - 0.05) continue;
                gx = K.BaseCenterX(u.TargetBase);
                gy = 20;
            }
            else continue;

            double dx = gx - u.X, dy = gy - u.Y, len = Math.Sqrt(dx * dx + dy * dy);
            if (len < 1e-9) continue;
            double step = Math.Min(K.March * K.Dt, len);
            u.VX = dx / len * K.March;
            u.VY = dy / len * K.March;
            u.X += u.VX * K.Dt;
            u.Y += u.VY * K.Dt;
        }
    }

    // ---------- economy ----------
    static int IncomeRate(double t) => t < 240 ? 40 : t < 480 ? 60 : 80;

    void IncomeTick()
    {
        if (Tick % 600 != 0) return;          // every 10 s of sim time
        int g = (int)Math.Round(IncomeRate(T) * K.IncomeMultiplier);
        Sides[0].Gold += g;
        Sides[1].Gold += g;
    }

    void BuildTick()
    {
        foreach (var s in Sides)
        {
            if (s.BuildClass < 0) continue;
            if (T < s.BuildEndsAt) continue;
            int cls = s.BuildClass;
            if (s.BuildIsResearch)
            {
                s.Researched[cls] = true;
                foreach (var u in units)
                    if (u.Alive && u.Team == s.Team && (int)u.Kind == cls) u.AbilityReadyAt = 0;
            }
            else
            {
                s.Level[cls]++;
                foreach (var u in units)
                    if (u.Alive && u.Team == s.Team && (int)u.Kind == cls) ApplyStats(u, false);
            }
            s.BuildClass = -1;
        }
    }

    // ---------- the #13 ladder and the greedy yardstick ----------
    public static double[] RampTimes = { 0, 60, 180, 360, 480 };
    public static int[] RampTotals = { 3, 5, 8, 12, 15 };
    public static int[][] RampClasses =
    {
        new[] { 3, 0, 0 },
        new[] { 4, 1, 0 },
        new[] { 4, 3, 1 },
        new[] { 6, 4, 2 },
        new[] { 7, 5, 3 },
    };

    static int RampRow(double t)
    {
        int row = 0;
        for (int i = 0; i < RampTimes.Length; i++) if (t >= RampTimes[i]) row = i;
        return row;
    }

    static Kind Counter(Kind theirs) => theirs switch
    {
        Kind.Archer => Kind.Warrior,
        Kind.Mage => Kind.Archer,
        _ => Kind.Mage,
    };

    Kind ScheduleClass(Side s)
    {
        int row = RampRow(T);
        for (int i = 0; i < 3; i++)
            if (Census(s.Team, (Kind)i) < RampClasses[row][i]) return (Kind)i;
        return Kind.Warrior;
    }

    Kind? CounterShift(Side s)
    {
        Kind? pick = null;
        int bestLead = 2;
        for (int i = 0; i < 3; i++)
        {
            var k = (Kind)i;
            int lead = Census(1 - s.Team, k) - Census(s.Team, k);
            if (lead > bestLead) { bestLead = lead; pick = Counter(k); }
        }
        return pick;
    }

    // next node of the per-class II -> III -> Research ladder, classes sorted by census
    (int Class, bool Research, int Cost, double Time)? NextNode(Side s)
    {
        var order = new[] { 0, 1, 2 }
            .OrderByDescending(c => Census(s.Team, (Kind)c))
            .ThenBy(c => c)
            .ToArray();
        foreach (int c in order)
        {
            if (s.Level[c] < 3) return (c, false, K.UpgradeCost[s.Level[c]], K.UpgradeTime[s.Level[c]]);
            if (!s.Researched[c]) return (c, true, K.ResearchCost, K.ResearchTime);
        }
        return null;
    }

    void StartBuild(Side s, (int Class, bool Research, int Cost, double Time) node)
    {
        s.Gold -= node.Cost;
        s.BuildClass = node.Class;
        s.BuildIsResearch = node.Research;
        s.BuildEndsAt = T + node.Time;
        s.Purchases++;
        s.BuildGold += node.Cost;
        s.FirstBuildAt ??= T;
    }

    void AiDecide(Side s)
    {
        int total = Census(s.Team);
        if (total < RampTotals[RampRow(T)])
        {
            if (s.Queue.Count >= 2) return;
            Kind k = ScheduleClass(s);
            k = CounterShift(s) ?? k;
            Recruit(s, k);
            return;
        }

        if (s.BuildClass >= 0) return;
        var node = NextNode(s);
        if (node != null && s.Gold >= node.Value.Cost) StartBuild(s, node.Value);
    }

    void GreedyDecide(Side s)
    {
        // spend on sight: mass first, then the same per-class ladder
        if (s.Gold >= K.RecruitCost && Living(s.Team) < K.ArmyCap)
        {
            Recruit(s, Kind.Warrior);   // greedy yardstick: mass first, warriors only
            return;
        }

        if (s.BuildClass >= 0) return;
        var node = NextNode(s);
        if (node != null && s.Gold >= node.Value.Cost) StartBuild(s, node.Value);
    }

    void Controllers()
    {
        foreach (var s in SideOrder())
        {
            if (T + 1e-9 < s.NextPollAt) continue;
            s.NextPollAt = T + 0.5;
            switch (s.Policy)
            {
                case Policy.Ai: AiDecide(s); break;
                case Policy.Greedy: GreedyDecide(s); break;
            }
        }
    }

    void BuildIdleMetrics()
    {
        foreach (var s in Sides)
        {
            if (s.BuildClass >= 0) continue;
            s.BuildIdleSeconds += K.Dt;
            var node = NextNode(s);
            if (node != null && s.Gold >= node.Value.Cost) s.BuildIdleRichSeconds += K.Dt;
        }
    }

    // ---------- the step ----------
    public void Step()
    {
        if (Ended) return;

        Controllers();
        IncomeTick();
        BuildTick();

        if (Tick % 15 == 0) Retarget();     // shared 0.25 s engagement tick

        BaseFire();

        foreach (var u in InOrder())
        {
            if (!u.Alive) continue;
            if (u.PendingAt >= 0 && T >= u.PendingAt)
            {
                ResolveSwing(u);
                u.PendingAt = -1;
            }
        }

        // start swings
        foreach (var u in InOrder())
        {
            if (!u.Alive || u.PendingAt >= 0) continue;
            if (T < u.NextSwingAt) continue;
            var d = u.D;

            if (u.TargetUnit >= 0)
            {
                var t = ById(u.TargetUnit);
                if (t == null || !t.Alive) continue;
                if (Dist(u, t) - t.D.Radius > d.Range + 0.05) continue;
                if (u.Kind == Kind.Warrior && !u.HasSlot) continue;
                StartSwing(u, t, -1);
            }
            else if (u.TargetBase >= 0)
            {
                if (Sides[u.TargetBase].BaseHp <= 0) continue;
                if (K.DistToBase(u.TargetBase, u.X, u.Y) > d.Range + 0.05) continue;
                if (u.Kind == Kind.Warrior && !u.HasSlot) continue;
                StartSwing(u, null, u.TargetBase);
            }
        }

        ResolveShots();
        Move();
        BuildIdleMetrics();

        foreach (var s in Sides)
            if (s.SaturatedAt == null && Living(s.Team) >= K.ArmyCap) s.SaturatedAt = T;

        // scheduled losses for the comeback run
        foreach (var loss in ScheduledLosses)
        {
            if (Tick != (long)Math.Round(loss.At / K.Dt)) continue;
            var victims = units
                .Where(u => u.Alive && u.Team == loss.Team)
                .OrderByDescending(u => u.X)
                .Take(loss.Count)
                .ToList();
            foreach (var v in victims) Kill(v, 1 - loss.Team, payBounty: false);
        }

        if (T >= K.SuddenDeathFrom)
        {
            SuddenDeathFired = true;
            HpAtSudden0 ??= Sides[0].BaseHp;
            HpAtSudden1 ??= Sides[1].BaseHp;
            sdAcc += K.SuddenDeathDps * K.Dt;
            int drain = (int)sdAcc;
            sdAcc -= drain;
            if (Sides[0].BaseHp > 0) Sides[0].BaseHp = Math.Max(0, Sides[0].BaseHp - drain);
            if (Sides[1].BaseHp > 0) Sides[1].BaseHp = Math.Max(0, Sides[1].BaseHp - drain);
            if (Sides[0].BaseHp < K.BaseHp / 2) Base0HalfAt ??= T;
            if (Sides[1].BaseHp < K.BaseHp / 2) Base1HalfAt ??= T;
        }

        CheckEnd();
        Sample();

        Tick++;
    }

    void Sample()
    {
        if (Tick % 3600 != 0) return;     // every 60 s
        Samples.Add(new Sample(T, Sides[0].BaseHp, Sides[1].BaseHp, Sides[0].Gold, Sides[1].Gold,
            Living(0), Living(1)));
    }

    void CheckEnd()
    {
        if (Ended) return;
        bool a = Sides[0].BaseHp <= 0, b = Sides[1].BaseHp <= 0;
        if (!a && !b) return;
        Ended = true;
        if (a && b) { Winner = -1; EndReason = "draw"; }
        else if (a) { Winner = 1; EndReason = "base destroyed"; }
        else { Winner = 0; EndReason = "base destroyed"; }
    }

    public Result Run(double maxSeconds = 900)
    {
        while (!Ended && T < maxSeconds) Step();
        if (!Ended) EndReason = "15:00 ceiling";
        return Snapshot();
    }

    public int LivingCount(int team) => Living(team);

    public Result Snapshot()
    {
        var a = Sides[0];
        var b = Sides[1];
        return new Result(
            Seed: 0, Scenario: Scenario, Winner: Winner, EndReason: EndReason, Duration: T,
            FirstClash: FirstClashAt, FirstBaseDamage: FirstBaseDamageAt,
            Base0Half: Base0HalfAt, Base1Half: Base1HalfAt,
            Kills0: a.Kills, Kills1: b.Kills, Recruits0: a.Recruits, Recruits1: b.Recruits,
            FirstBuild0: a.FirstBuildAt, FirstBuild1: b.FirstBuildAt,
            Purchases0: a.Purchases, Purchases1: b.Purchases,
            BuildIdle0: a.BuildIdleSeconds, BuildIdle1: b.BuildIdleSeconds,
            BuildIdleRich0: a.BuildIdleRichSeconds, BuildIdleRich1: b.BuildIdleRichSeconds,
            Saturated0: a.SaturatedAt, Saturated1: b.SaturatedAt,
            Gold0: a.Gold, Gold1: b.Gold, BaseHp0: a.BaseHp, BaseHp1: b.BaseHp,
            SuddenDeath: SuddenDeathFired, Casts0: a.Casts, Casts1: b.Casts,
            LevelSum0: a.Level.Sum(), LevelSum1: b.Level.Sum(),
            Researched0: a.Researched.Count(x => x), Researched1: b.Researched.Count(x => x),
            HpAtSudden0: HpAtSudden0, HpAtSudden1: HpAtSudden1);
    }
}

static class Program
{
    static readonly string[] ScenarioNames =
    {
        "AI vs AI (mirror)",
        "AI (team 0) vs greedy mass-first (team 1)",
        "greedy (team 0) vs AI (team 1)",
        "Comeback: AI (team 0) loses 2 units at 0:30 and 1:15",
        "Sensitivity: AI vs AI, unit damage x0.65 (fights ~1.5x longer)",
        "Probe: AI vs AI, income x2",
        "Probe: AI vs AI, income x2 + Base 16,000 + sudden death 90/s",
        "Probe: AI vs AI, income x2 + 8-unit cap (ramp 3/5/8/8/8)",
        "Probe: AI vs AI, income x1.5 + 8-unit cap (ramp 3/5/8/8/8)",
        "Probe: AI vs AI, income x1.5 + 8-unit cap, ramp met by 2:00 (3/5/8)",
        "Probe #5: income x2 + 8-cap + ramp 3/5/8 by 2:00 + sudden death 6:00 (mirror)",
        "Probe #5: same, comeback (team 0 loses 2 units at 0:30 and 1:15)",
        "Probe #5: income x2 + 8-cap + ramp 3/5/8 by 2:00 + sudden death 7:00 (mirror)",
        "Probe #5: income x2 + 8-cap + ramp 3/5/8 by 2:00 + sudden death 7:30 (mirror)",
    };

    static void Main()
    {
        var outLines = new List<string>();
        var con = new List<string>();
        void W(string s) { con.Add(s); outLines.Add(s); }

        SelfChecks(W);
        var results = new List<Result>();

        results.AddRange(RunScenario(ScenarioNames[0], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[0])));
        results.AddRange(RunScenario(ScenarioNames[1], 10, seed => new Sim(seed, Policy.Ai, Policy.Greedy, ScenarioNames[1])));
        results.AddRange(RunScenario(ScenarioNames[2], 10, seed => new Sim(seed, Policy.Greedy, Policy.Ai, ScenarioNames[2])));
        results.AddRange(RunScenario(ScenarioNames[3], 20, seed =>
        {
            var sim = new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[3]);
            sim.ScheduledLosses.Add((30, 0, 2));
            sim.ScheduledLosses.Add((75, 0, 2));
            return sim;
        }));

        K.DamageScale = 0.65;
        results.AddRange(RunScenario(ScenarioNames[4], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[4])));
        K.DamageScale = 1.0;

        K.IncomeMultiplier = 2;
        results.AddRange(RunScenario(ScenarioNames[5], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[5])));

        K.BaseHp = 16_000;
        K.SuddenDeathDps = 90;
        results.AddRange(RunScenario(ScenarioNames[6], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[6])));
        K.IncomeMultiplier = 1;
        K.BaseHp = 10_000;
        K.SuddenDeathDps = 60;

        K.IncomeMultiplier = 2;
        K.ArmyCap = 8;
        Sim.RampTotals = new[] { 3, 5, 8, 8, 8 };
        Sim.RampClasses = new[]
        {
            new[] { 3, 0, 0 },
            new[] { 4, 1, 0 },
            new[] { 4, 3, 1 },
            new[] { 5, 2, 1 },
            new[] { 5, 2, 1 },
        };
        results.AddRange(RunScenario(ScenarioNames[7], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[7])));
        K.IncomeMultiplier = 1.5;
        results.AddRange(RunScenario(ScenarioNames[8], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[8])));

        Sim.RampTimes = new[] { 0.0, 60, 120 };
        Sim.RampTotals = new[] { 3, 5, 8 };
        Sim.RampClasses = new[]
        {
            new[] { 3, 0, 0 },
            new[] { 4, 1, 0 },
            new[] { 4, 3, 1 },
        };
        results.AddRange(RunScenario(ScenarioNames[9], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[9])));

        // #5's settled shape: income x2, 8-unit cap, ramp 3/5/8 by 2:00, sudden death from 6:00.
        K.IncomeMultiplier = 2;
        K.SuddenDeathFrom = 360.0;
        Sim.RampTimes = new[] { 0.0, 60, 120 };
        Sim.RampTotals = new[] { 3, 5, 8 };
        Sim.RampClasses = new[]
        {
            new[] { 3, 0, 0 },
            new[] { 4, 1, 0 },
            new[] { 4, 3, 1 },
        };
        results.AddRange(RunScenario(ScenarioNames[10], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[10])));
        results.AddRange(RunScenario(ScenarioNames[11], 20, seed =>
        {
            var sim = new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[11]);
            sim.ScheduledLosses.Add((30, 0, 2));
            sim.ScheduledLosses.Add((75, 0, 2));
            return sim;
        }));
        K.SuddenDeathFrom = 420.0;
        results.AddRange(RunScenario(ScenarioNames[12], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[12])));
        K.SuddenDeathFrom = 450.0;
        results.AddRange(RunScenario(ScenarioNames[13], 20, seed => new Sim(seed, Policy.Ai, Policy.Ai, ScenarioNames[13])));

        Sim.RampTimes = new[] { 0.0, 60, 180, 360, 480 };
        Sim.RampTotals = new[] { 3, 5, 8, 8, 8 };
        Sim.RampClasses = new[]
        {
            new[] { 3, 0, 0 },
            new[] { 4, 1, 0 },
            new[] { 4, 3, 1 },
            new[] { 5, 2, 1 },
            new[] { 5, 2, 1 },
        };
        K.IncomeMultiplier = 1;
        K.ArmyCap = 15;
        Sim.RampTotals = new[] { 3, 5, 8, 12, 15 };
        Sim.RampClasses = new[]
        {
            new[] { 3, 0, 0 },
            new[] { 4, 1, 0 },
            new[] { 4, 3, 1 },
            new[] { 6, 4, 2 },
            new[] { 7, 5, 3 },
        };

        W("");
        W("## Results");
        W("");
        foreach (var name in ScenarioNames) ReportScenario(W, results.Where(r => r.Scenario == name).ToList());

        W("");
        W("## One representative run (AI vs AI, 60 s samples)");
        W("");
        var sampleRun = new Sim(1, Policy.Ai, Policy.Ai, ScenarioNames[0]);
        sampleRun.Run();
        W("| clock | base 0 | base 1 | gold 0 | gold 1 | army 0 | army 1 |");
        W("|---|---|---|---|---|---|---|");
        foreach (var s in sampleRun.Samples)
            W($"| {Clock(s.T)} | {s.Hp0} | {s.Hp1} | {s.Gold0} | {s.Gold1} | {s.Army0} | {s.Army1} |");
        W("");
        W($"End: {sampleRun.EndReason} at {Clock(sampleRun.T)}, team {sampleRun.Winner} wins; " +
          $"clash {Clock(sampleRun.FirstClashAt ?? 0)}, first base damage {Clock(sampleRun.FirstBaseDamageAt ?? 0)}");

        Console.WriteLine(string.Join("\n", con));
        File.WriteAllText(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "RESULTS.md"),
            string.Join("\n", outLines));
    }

    static IEnumerable<Result> RunScenario(string name, int seeds, Func<int, Sim> make)
    {
        for (int seed = 1; seed <= seeds; seed++)
        {
            var sim = make(seed);
            var r = sim.Run();
            yield return r with { Seed = seed };
        }
    }

    static void ReportScenario(Action<string> W, List<Result> runs)
    {
        void Row(string name, IEnumerable<double> xs) => Program.Row(W, name, xs);

        W($"### {runs[0].Scenario}");
        W("");
        W($"Runs: {runs.Count}. Wins: team 0 {runs.Count(r => r.Winner == 0)}, team 1 {runs.Count(r => r.Winner == 1)}, " +
          $"draw {runs.Count(r => r.Winner == -1)}, no result {runs.Count(r => r.Winner == -1 && r.EndReason.Contains("ceiling"))}. " +
          $"Sudden death reached: {runs.Count(r => r.SuddenDeath)}.");
        int sidesWithBuy = runs.SelectMany(r => new[] { r.Purchases0, r.Purchases1 }).Count(p => p > 0);
        int sdRuns = runs.Count(r => r.SuddenDeath);
        int sdEqual = runs.Count(r => r.HpAtSudden0.HasValue && r.HpAtSudden0 == r.HpAtSudden1);
        W($"Sides with at least one build: {sidesWithBuy}/{runs.Count * 2}. " +
          $"Sudden-death runs entering with equal Base HP: {sdEqual}/{sdRuns}. " +
          $"Median deaths per minute per side: {Median(runs.Select(r => (r.Kills0 + r.Kills1) / 2.0 / (r.Duration / 60.0))):0.0}.");
        W("");
        W("| metric | min | median | max |");
        W("|---|---|---|---|");
        Row("duration (s)", runs.Select(r => r.Duration));
        Row("first unit clash (s)", NonNull(runs.Select(r => r.FirstClash)));
        Row("first base damage (s)", NonNull(runs.Select(r => r.FirstBaseDamage)));
        Row("base 0 below 50% (s)", NonNull(runs.Select(r => r.Base0Half)));
        Row("base 1 below 50% (s)", NonNull(runs.Select(r => r.Base1Half)));
        Row("first build started (s)", NonNull(runs.SelectMany(r => new[] { r.FirstBuild0, r.FirstBuild1 })));
        Row("army saturated, team 0 (s)", NonNull(runs.Select(r => r.Saturated0)));
        Row("army saturated, team 1 (s)", NonNull(runs.Select(r => r.Saturated1)));
        Row("purchases per side", runs.SelectMany(r => new[] { (double)r.Purchases0, r.Purchases1 }));
        Row("build slot idle %", runs.SelectMany(r => new[]
            { 100.0 * r.BuildIdle0 / r.Duration, 100.0 * r.BuildIdle1 / r.Duration }));
        Row("slot idle WITH an affordable node %", runs.SelectMany(r => new[]
            { 100.0 * r.BuildIdleRich0 / r.Duration, 100.0 * r.BuildIdleRich1 / r.Duration }));
        Row("recruits per side", runs.SelectMany(r => new[] { (double)r.Recruits0, r.Recruits1 }));
        Row("kills per side", runs.SelectMany(r => new[] { (double)r.Kills0, r.Kills1 }));
        Row("gold banked at end", runs.SelectMany(r => new[] { (double)r.Gold0, r.Gold1 }));
        Row("level sum at end (3 = all I)", runs.SelectMany(r => new[] { (double)r.LevelSum0, r.LevelSum1 }));
        Row("research nodes at end", runs.SelectMany(r => new[] { (double)r.Researched0, r.Researched1 }));
        Row("ability casts per side", runs.SelectMany(r => new[] { (double)r.Casts0, r.Casts1 }));
        W("");
    }

    static IEnumerable<double> NonNull(IEnumerable<double?> xs) => xs.Where(x => x.HasValue).Select(x => x!.Value);

    static double Median(IEnumerable<double> xs)
    {
        var v = xs.OrderBy(x => x).ToArray();
        if (v.Length == 0) return 0;
        return v.Length % 2 == 1 ? v[v.Length / 2] : (v[v.Length / 2 - 1] + v[v.Length / 2]) / 2;
    }

    static void Row(Action<string> W, string name, IEnumerable<double> xs)
    {
        var v = xs.OrderBy(x => x).ToArray();
        if (v.Length == 0) { W($"| {name} | - | - | - |"); return; }
        double min = v[0], max = v[^1], med = v.Length % 2 == 1 ? v[v.Length / 2] : (v[v.Length / 2 - 1] + v[v.Length / 2]) / 2;
        W($"| {name} | {min:0.0} | {med:0.0} | {max:0.0} |");
    }

    static string Clock(double seconds) => $"{(int)(seconds / 60)}:{(int)(seconds % 60):00}";

    // ---------------- self checks ----------------
    static void SelfChecks(Action<string> W)
    {
        W("# Balance dry run (ticket #19)");
        W("");
        W("Throwaway model: pure C#, no Godot, no navigation. Numbers from #5/#6/#7/#11/#12/#13.");
        W("");
        W("## Self checks");
        W("");

        int maxRoll = K.Defs.Max(d => d.DmgMax);
        int smallestPool = K.Defs.Min(d => d.Hp);
        W($"- no-one-shot: max roll {maxRoll} vs smallest pool {smallestPool} = {100.0 * maxRoll / smallestPool:0.0}% (cap 25%) " +
          $"-> {(maxRoll <= smallestPool * 0.25 ? "PASS" : "FAIL")}");

        // passive income with nothing spent: 300 + 3,360 = 3,660 by 10:00
        {
            var sim = new Sim(1, Policy.None, Policy.None, "income check");
            for (int i = 0; i < 60 * 600; i++) sim.Step();
            W($"- passive income by 10:00: {sim.Sides[0].Gold} gold (start 300 + 3,360 = 3,660) " +
              $"-> {(sim.Sides[0].Gold == 3660 ? "PASS" : "FAIL")}");
        }

        // sudden death from 12:00, untouched bases -> 10,000 / 60 = 166.7 s, both die together
        {
            var sim = new Sim(1, Policy.None, Policy.None, "sudden death check");
            var r = sim.Run();
            W($"- sudden death on untouched bases: {Clock(r.Duration)} ({r.EndReason}) " +
              $"-> {(r.EndReason == "draw" && Math.Abs(r.Duration - (720 + 10_000 / 60.0)) < 0.5 ? "PASS" : "FAIL")}");
        }

        // siege maths: how long 8 surviving attackers need against a 10,000 HP Base
        foreach (var (label, kinds) in new (string, Kind[])[]
        {
            ("8 warriors", Enumerable.Repeat(Kind.Warrior, 8).ToArray()),
            ("8 archers", Enumerable.Repeat(Kind.Archer, 8).ToArray()),
            ("4 warriors + 3 archers + 1 mage", new[] { Kind.Warrior, Kind.Warrior, Kind.Warrior, Kind.Warrior, Kind.Archer, Kind.Archer, Kind.Archer, Kind.Mage }),
            ("one warrior", new[] { Kind.Warrior }),
        })
        {
            var sim = new Sim(1, Policy.None, Policy.None, "siege check");
            foreach (var k in kinds) sim.Spawn(0, k, 70, 20);
            var r = sim.Run();
            W($"- siege, {label}: Base falls at {Clock(r.Duration)}; attackers left {sim.LivingCount(0)}/{kinds.Length}; " +
              $"Base HP lost {K.BaseHp - sim.Sides[1].BaseHp}");
        }

        // a mirrored 8/5/2 clash with no economy: first contact -> last death
        {
            var sim = new Sim(1, Policy.None, Policy.None, "clash check");
            for (int i = 0; i < 8; i++) sim.Spawn(0, Kind.Warrior, 14, 16 + i);
            for (int i = 0; i < 5; i++) sim.Spawn(0, Kind.Archer, 14, 16 + i);
            for (int i = 0; i < 2; i++) sim.Spawn(0, Kind.Mage, 14, 16 + i);
            for (int i = 0; i < 8; i++) sim.Spawn(1, Kind.Warrior, 106, 16 + i);
            for (int i = 0; i < 5; i++) sim.Spawn(1, Kind.Archer, 106, 16 + i);
            for (int i = 0; i < 2; i++) sim.Spawn(1, Kind.Mage, 106, 16 + i);
            double? first = null, last = null;
            int prev = 0;
            while (!sim.Ended && sim.T < 300)
            {
                sim.Step();
                int now = sim.Sides[0].Kills + sim.Sides[1].Kills;
                if (now != prev) { first ??= sim.FirstClashAt; last = sim.T; prev = now; }
                if (sim.LivingCount(0) == 0 || sim.LivingCount(1) == 0) break;
            }
            W($"- mirrored 8/5/2 clash: first damage {Clock(first ?? 0)}, last death {Clock(last ?? 0)} " +
              $"({((last ?? 0) - (first ?? 0)):0.0} s); survivors {sim.LivingCount(0)}v{sim.LivingCount(1)}; #16 measured 16-19 s");
        }

        // a mirrored 5v5: #5 says a 5v5 resolves in 3-6 s
        {
            var sim = new Sim(1, Policy.None, Policy.None, "5v5 check");
            for (int i = 0; i < 5; i++) sim.Spawn(0, Kind.Warrior, 14, 18 + i);
            for (int i = 0; i < 5; i++) sim.Spawn(1, Kind.Warrior, 106, 18 + i);
            double? first = null, last = null;
            int prev = 0;
            while (!sim.Ended && sim.T < 300)
            {
                sim.Step();
                int now = sim.Sides[0].Kills + sim.Sides[1].Kills;
                if (now != prev) { first ??= sim.FirstClashAt; last = sim.T; prev = now; }
                if (sim.LivingCount(0) == 0 || sim.LivingCount(1) == 0) break;
            }
            W($"- mirrored 5v5 warriors: first damage {Clock(first ?? 0)}, last death {Clock(last ?? 0)} " +
              $"({((last ?? 0) - (first ?? 0)):0.0} s); #5 says 3-6 s");
        }
    }

}
