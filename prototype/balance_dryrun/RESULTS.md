# Balance dry run (ticket #19)

Throwaway model: pure C#, no Godot, no navigation. Numbers from #5/#6/#7/#11/#12/#13.

## Self checks

- no-one-shot: max roll 32 vs smallest pool 130 = 24,6% (cap 25%) -> PASS
- passive income by 10:00: 3660 gold (start 300 + 3,360 = 3,660) -> PASS
- sudden death on untouched bases: 14:46 (draw) -> PASS
- siege, 8 warriors: Base falls at 0:40; attackers left 6/8; Base HP lost 10000
- siege, 8 archers: Base falls at 0:55; attackers left 8/8; Base HP lost 10000
- siege, 4 warriors + 3 archers + 1 mage: Base falls at 0:51; attackers left 6/8; Base HP lost 10000
- siege, one warrior: Base falls at 14:36; attackers left 0/1; Base HP lost 10000
- mirrored 8/5/2 clash: first damage 0:14, last death 0:27 (13,4 s); survivors 4v0; #16 measured 16-19 s
- mirrored 5v5 warriors: first damage 0:15, last death 0:19 (4,8 s); #5 says 3-6 s

## Results

### AI vs AI (mirror)

Runs: 20. Wins: team 0 9, team 1 3, draw 8, no result 0. Sudden death reached: 12.
Sides with at least one build: 2/40. Sudden-death runs entering with equal Base HP: 11/12. Median deaths per minute per side: 5,4.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 334,1 | 835,3 | 886,7 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 50,1 | 486,0 | 879,6 |
| base 0 below 50% (s) | 665,1 | 803,3 | 803,3 |
| base 1 below 50% (s) | 269,8 | 803,3 | 803,3 |
| first build started (s) | 40,5 | 40,5 | 40,5 |
| army saturated, team 0 (s) | - | - | - |
| army saturated, team 1 (s) | - | - | - |
| purchases per side | 0,0 | 0,0 | 1,0 |
| build slot idle % | 94,0 | 100,0 | 100,0 |
| slot idle WITH an affordable node % | 0,1 | 0,1 | 0,3 |
| recruits per side | 23,0 | 77,5 | 84,0 |
| kills per side | 17,0 | 74,5 | 83,0 |
| gold banked at end | 0,0 | 10,0 | 90,0 |
| level sum at end (3 = all I) | 3,0 | 3,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### AI (team 0) vs greedy mass-first (team 1)

Runs: 10. Wins: team 0 3, team 1 2, draw 5, no result 0. Sudden death reached: 8.
Sides with at least one build: 1/20. Sudden-death runs entering with equal Base HP: 8/8. Median deaths per minute per side: 5,5.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 480,1 | 883,6 | 886,7 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 110,6 | 739,7 | 810,6 |
| base 0 below 50% (s) | 558,6 | 803,3 | 803,3 |
| base 1 below 50% (s) | 349,2 | 803,3 | 803,3 |
| first build started (s) | 40,5 | 40,5 | 40,5 |
| army saturated, team 0 (s) | - | - | - |
| army saturated, team 1 (s) | - | - | - |
| purchases per side | 0,0 | 0,0 | 1,0 |
| build slot idle % | 95,8 | 100,0 | 100,0 |
| slot idle WITH an affordable node % | 0,1 | 0,1 | 0,2 |
| recruits per side | 35,0 | 83,5 | 84,0 |
| kills per side | 30,0 | 80,5 | 82,0 |
| gold banked at end | 10,0 | 40,0 | 160,0 |
| level sum at end (3 = all I) | 3,0 | 3,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### greedy (team 0) vs AI (team 1)

Runs: 10. Wins: team 0 6, team 1 1, draw 3, no result 0. Sudden death reached: 4.
Sides with at least one build: 0/20. Sudden-death runs entering with equal Base HP: 3/4. Median deaths per minute per side: 4,8.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 555,7 | 670,1 | 886,7 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 55,2 | 593,9 | 666,8 |
| base 0 below 50% (s) | 786,7 | 803,3 | 803,3 |
| base 1 below 50% (s) | 507,0 | 648,7 | 803,3 |
| first build started (s) | - | - | - |
| army saturated, team 0 (s) | - | - | - |
| army saturated, team 1 (s) | - | - | - |
| purchases per side | 0,0 | 0,0 | 0,0 |
| build slot idle % | 100,0 | 100,0 | 100,0 |
| slot idle WITH an affordable node % | 0,1 | 0,1 | 0,1 |
| recruits per side | 45,0 | 59,0 | 84,0 |
| kills per side | 39,0 | 56,0 | 82,0 |
| gold banked at end | 0,0 | 55,0 | 170,0 |
| level sum at end (3 = all I) | 3,0 | 3,0 | 3,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Comeback: AI (team 0) loses 2 units at 0:30 and 1:15

Runs: 20. Wins: team 0 8, team 1 12, draw 0, no result 0. Sudden death reached: 14.
Sides with at least one build: 0/40. Sudden-death runs entering with equal Base HP: 0/14. Median deaths per minute per side: 4,8.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 528,5 | 755,3 | 886,3 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 49,2 | 95,4 | 96,7 |
| base 0 below 50% (s) | 465,3 | 796,9 | 802,9 |
| base 1 below 50% (s) | 476,0 | 765,3 | 803,3 |
| first build started (s) | - | - | - |
| army saturated, team 0 (s) | - | - | - |
| army saturated, team 1 (s) | - | - | - |
| purchases per side | 0,0 | 0,0 | 0,0 |
| build slot idle % | 100,0 | 100,0 | 100,0 |
| slot idle WITH an affordable node % | 0,1 | 0,1 | 0,2 |
| recruits per side | 41,0 | 67,5 | 83,0 |
| kills per side | 35,0 | 62,5 | 81,0 |
| gold banked at end | 0,0 | 70,0 | 170,0 |
| level sum at end (3 = all I) | 3,0 | 3,0 | 3,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Sensitivity: AI vs AI, unit damage x0.65 (fights ~1.5x longer)

Runs: 20. Wins: team 0 7, team 1 13, draw 0, no result 0. Sudden death reached: 6.
Sides with at least one build: 0/40. Sudden-death runs entering with equal Base HP: 1/6. Median deaths per minute per side: 4,9.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 582,7 | 698,8 | 858,4 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 406,7 | 598,2 | 819,6 |
| base 0 below 50% (s) | 644,6 | 665,3 | 803,3 |
| base 1 below 50% (s) | 535,1 | 676,7 | 803,3 |
| first build started (s) | - | - | - |
| army saturated, team 0 (s) | - | - | - |
| army saturated, team 1 (s) | - | - | - |
| purchases per side | 0,0 | 0,0 | 0,0 |
| build slot idle % | 100,0 | 100,0 | 100,0 |
| slot idle WITH an affordable node % | 0,1 | 0,1 | 0,1 |
| recruits per side | 48,0 | 62,0 | 81,0 |
| kills per side | 41,0 | 59,0 | 79,0 |
| gold banked at end | 0,0 | 50,0 | 90,0 |
| level sum at end (3 = all I) | 3,0 | 3,0 | 3,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe: AI vs AI, income x2

Runs: 20. Wins: team 0 14, team 1 6, draw 0, no result 0. Sudden death reached: 0.
Sides with at least one build: 30/40. Sudden-death runs entering with equal Base HP: 0/0. Median deaths per minute per side: 6,4.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 193,3 | 301,6 | 523,0 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 110,2 | 202,3 | 478,3 |
| base 0 below 50% (s) | 227,5 | 366,1 | 379,8 |
| base 1 below 50% (s) | 148,7 | 223,9 | 510,1 |
| first build started (s) | 20,5 | 21,3 | 350,5 |
| army saturated, team 0 (s) | 520,5 | 520,5 | 520,5 |
| army saturated, team 1 (s) | - | - | - |
| purchases per side | 0,0 | 1,0 | 2,0 |
| build slot idle % | 73,3 | 94,7 | 100,0 |
| slot idle WITH an affordable node % | 0,2 | 0,4 | 0,8 |
| recruits per side | 19,0 | 37,0 | 78,0 |
| kills per side | 13,0 | 32,0 | 75,0 |
| gold banked at end | 10,0 | 70,0 | 390,0 |
| level sum at end (3 = all I) | 3,0 | 4,0 | 5,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe: AI vs AI, income x2 + Base 16,000 + sudden death 90/s

Runs: 20. Wins: team 0 14, team 1 6, draw 0, no result 0. Sudden death reached: 0.
Sides with at least one build: 30/40. Sudden-death runs entering with equal Base HP: 0/0. Median deaths per minute per side: 6,5.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 241,9 | 347,5 | 536,3 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 110,2 | 202,3 | 478,3 |
| base 0 below 50% (s) | 278,0 | 385,3 | 399,3 |
| base 1 below 50% (s) | 168,0 | 238,2 | 518,2 |
| first build started (s) | 20,5 | 21,3 | 350,5 |
| army saturated, team 0 (s) | 520,5 | 520,5 | 520,5 |
| army saturated, team 1 (s) | - | - | - |
| purchases per side | 0,0 | 1,0 | 3,0 |
| build slot idle % | 75,9 | 95,1 | 100,0 |
| slot idle WITH an affordable node % | 0,2 | 0,4 | 0,7 |
| recruits per side | 25,0 | 40,5 | 79,0 |
| kills per side | 17,0 | 38,0 | 77,0 |
| gold banked at end | 0,0 | 80,0 | 380,0 |
| level sum at end (3 = all I) | 3,0 | 4,0 | 5,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe: AI vs AI, income x2 + 8-unit cap (ramp 3/5/8/8/8)

Runs: 20. Wins: team 0 14, team 1 6, draw 0, no result 0. Sudden death reached: 0.
Sides with at least one build: 30/40. Sudden-death runs entering with equal Base HP: 0/0. Median deaths per minute per side: 6,4.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 193,3 | 301,6 | 516,1 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 110,2 | 202,3 | 458,7 |
| base 0 below 50% (s) | 227,5 | 366,6 | 377,2 |
| base 1 below 50% (s) | 148,7 | 223,9 | 499,4 |
| first build started (s) | 20,5 | 21,3 | 350,5 |
| army saturated, team 0 (s) | 181,0 | 235,5 | 461,0 |
| army saturated, team 1 (s) | 270,5 | 322,8 | 330,5 |
| purchases per side | 0,0 | 1,0 | 2,0 |
| build slot idle % | 73,3 | 93,3 | 100,0 |
| slot idle WITH an affordable node % | 0,2 | 0,4 | 0,8 |
| recruits per side | 19,0 | 37,0 | 73,0 |
| kills per side | 13,0 | 32,0 | 73,0 |
| gold banked at end | 10,0 | 85,0 | 430,0 |
| level sum at end (3 = all I) | 3,0 | 4,0 | 5,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe: AI vs AI, income x1.5 + 8-unit cap (ramp 3/5/8/8/8)

Runs: 20. Wins: team 0 11, team 1 8, draw 1, no result 0. Sudden death reached: 1.
Sides with at least one build: 17/40. Sudden-death runs entering with equal Base HP: 1/1. Median deaths per minute per side: 6,3.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 211,9 | 495,2 | 886,7 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 108,7 | 394,6 | 488,2 |
| base 0 below 50% (s) | 404,6 | 468,1 | 803,3 |
| base 1 below 50% (s) | 162,1 | 440,3 | 803,3 |
| first build started (s) | 30,0 | 480,5 | 680,5 |
| army saturated, team 0 (s) | 390,5 | 425,5 | 640,5 |
| army saturated, team 1 (s) | 372,0 | 446,5 | 504,0 |
| purchases per side | 0,0 | 0,0 | 1,0 |
| build slot idle % | 90,6 | 100,0 | 100,0 |
| slot idle WITH an affordable node % | 0,1 | 0,2 | 0,7 |
| recruits per side | 20,0 | 56,5 | 124,0 |
| kills per side | 13,0 | 51,0 | 121,0 |
| gold banked at end | 0,0 | 60,0 | 380,0 |
| level sum at end (3 = all I) | 3,0 | 3,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe: AI vs AI, income x1.5 + 8-unit cap, ramp met by 2:00 (3/5/8)

Runs: 20. Wins: team 0 13, team 1 7, draw 0, no result 0. Sudden death reached: 0.
Sides with at least one build: 20/40. Sudden-death runs entering with equal Base HP: 0/0. Median deaths per minute per side: 6,3.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 208,4 | 512,8 | 710,1 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 108,7 | 392,7 | 635,7 |
| base 0 below 50% (s) | 404,9 | 473,8 | 567,6 |
| base 1 below 50% (s) | 162,0 | 454,1 | 684,1 |
| first build started (s) | 30,0 | 500,5 | 662,0 |
| army saturated, team 0 (s) | 390,5 | 450,5 | 634,5 |
| army saturated, team 1 (s) | 372,0 | 452,0 | 521,0 |
| purchases per side | 0,0 | 0,5 | 2,0 |
| build slot idle % | 90,4 | 99,8 | 100,0 |
| slot idle WITH an affordable node % | 0,1 | 0,3 | 0,5 |
| recruits per side | 19,0 | 58,0 | 90,0 |
| kills per side | 13,0 | 54,0 | 90,0 |
| gold banked at end | 0,0 | 70,0 | 310,0 |
| level sum at end (3 = all I) | 3,0 | 3,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe #5: income x2 + 8-cap + ramp 3/5/8 by 2:00 + sudden death 6:00 (mirror)

Runs: 20. Wins: team 0 14, team 1 6, draw 0, no result 0. Sudden death reached: 8.
Sides with at least one build: 30/40. Sudden-death runs entering with equal Base HP: 2/8. Median deaths per minute per side: 6,4.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 176,6 | 301,6 | 480,5 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 110,2 | 202,3 | 453,8 |
| base 0 below 50% (s) | 227,5 | 365,3 | 443,3 |
| base 1 below 50% (s) | 148,6 | 223,9 | 443,3 |
| first build started (s) | 20,5 | 21,3 | 350,5 |
| army saturated, team 0 (s) | 140,5 | 220,5 | 440,5 |
| army saturated, team 1 (s) | 270,5 | 322,8 | 330,5 |
| purchases per side | 0,0 | 1,0 | 2,0 |
| build slot idle % | 88,7 | 93,6 | 100,0 |
| slot idle WITH an affordable node % | 0,2 | 0,4 | 0,7 |
| recruits per side | 20,0 | 37,0 | 67,0 |
| kills per side | 12,0 | 32,0 | 66,0 |
| gold banked at end | 0,0 | 95,0 | 390,0 |
| level sum at end (3 = all I) | 3,0 | 4,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe #5: same, comeback (team 0 loses 2 units at 0:30 and 1:15)

Runs: 20. Wins: team 0 7, team 1 13, draw 0, no result 0. Sudden death reached: 3.
Sides with at least one build: 27/40. Sudden-death runs entering with equal Base HP: 1/3. Median deaths per minute per side: 5,6.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 166,9 | 213,3 | 409,1 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 54,1 | 118,7 | 373,7 |
| base 0 below 50% (s) | 127,9 | 158,3 | 389,3 |
| base 1 below 50% (s) | 158,7 | 254,8 | 390,4 |
| first build started (s) | 20,5 | 20,5 | 272,0 |
| army saturated, team 0 (s) | 160,5 | 241,5 | 361,0 |
| army saturated, team 1 (s) | 121,5 | 160,5 | 340,5 |
| purchases per side | 0,0 | 1,0 | 2,0 |
| build slot idle % | 84,9 | 93,7 | 100,0 |
| slot idle WITH an affordable node % | 0,2 | 0,3 | 0,6 |
| recruits per side | 17,0 | 26,0 | 53,0 |
| kills per side | 11,0 | 22,0 | 52,0 |
| gold banked at end | 0,0 | 70,0 | 360,0 |
| level sum at end (3 = all I) | 3,0 | 4,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe #5: income x2 + 8-cap + ramp 3/5/8 by 2:00 + sudden death 7:00 (mirror)

Runs: 20. Wins: team 0 14, team 1 6, draw 0, no result 0. Sudden death reached: 2.
Sides with at least one build: 30/40. Sudden-death runs entering with equal Base HP: 1/2. Median deaths per minute per side: 6,4.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 176,6 | 301,6 | 495,7 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 110,2 | 202,3 | 453,8 |
| base 0 below 50% (s) | 227,5 | 366,6 | 377,2 |
| base 1 below 50% (s) | 148,6 | 223,9 | 472,3 |
| first build started (s) | 20,5 | 21,3 | 350,5 |
| army saturated, team 0 (s) | 140,5 | 220,5 | 440,5 |
| army saturated, team 1 (s) | 270,5 | 322,8 | 330,5 |
| purchases per side | 0,0 | 1,0 | 2,0 |
| build slot idle % | 88,5 | 93,3 | 100,0 |
| slot idle WITH an affordable node % | 0,2 | 0,4 | 0,8 |
| recruits per side | 20,0 | 37,0 | 69,0 |
| kills per side | 12,0 | 32,0 | 69,0 |
| gold banked at end | 0,0 | 90,0 | 390,0 |
| level sum at end (3 = all I) | 3,0 | 4,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |

### Probe #5: income x2 + 8-cap + ramp 3/5/8 by 2:00 + sudden death 7:30 (mirror)

Runs: 20. Wins: team 0 14, team 1 6, draw 0, no result 0. Sudden death reached: 1.
Sides with at least one build: 30/40. Sudden-death runs entering with equal Base HP: 1/1. Median deaths per minute per side: 6,4.

| metric | min | median | max |
|---|---|---|---|
| duration (s) | 176,6 | 301,6 | 502,3 |
| first unit clash (s) | 15,2 | 15,2 | 15,2 |
| first base damage (s) | 110,2 | 202,3 | 453,8 |
| base 0 below 50% (s) | 227,5 | 366,6 | 377,2 |
| base 1 below 50% (s) | 148,6 | 223,9 | 483,8 |
| first build started (s) | 20,5 | 21,3 | 350,5 |
| army saturated, team 0 (s) | 140,5 | 220,5 | 440,5 |
| army saturated, team 1 (s) | 270,5 | 322,8 | 330,5 |
| purchases per side | 0,0 | 1,0 | 2,0 |
| build slot idle % | 87,8 | 93,3 | 100,0 |
| slot idle WITH an affordable node % | 0,2 | 0,4 | 0,8 |
| recruits per side | 20,0 | 37,0 | 71,0 |
| kills per side | 12,0 | 32,0 | 71,0 |
| gold banked at end | 0,0 | 85,0 | 390,0 |
| level sum at end (3 = all I) | 3,0 | 4,0 | 4,0 |
| research nodes at end | 0,0 | 0,0 | 0,0 |
| ability casts per side | 0,0 | 0,0 | 0,0 |


## One representative run (AI vs AI, 60 s samples)

| clock | base 0 | base 1 | gold 0 | gold 1 | army 0 | army 1 |
|---|---|---|---|---|---|---|
| 0:00 | 10000 | 10000 | 240 | 240 | 1 | 1 |
| 1:00 | 10000 | 10000 | 60 | 130 | 2 | 0 |
| 2:00 | 10000 | 10000 | 90 | 90 | 1 | 1 |
| 3:00 | 10000 | 10000 | 50 | 120 | 2 | 0 |
| 4:00 | 10000 | 10000 | 100 | 100 | 1 | 1 |
| 5:00 | 10000 | 10000 | 110 | 80 | 2 | 1 |
| 6:00 | 10000 | 10000 | 120 | 90 | 2 | 1 |
| 7:00 | 10000 | 10000 | 100 | 100 | 2 | 2 |
| 8:00 | 8199 | 8199 | 160 | 160 | 1 | 1 |
| 9:00 | 4599 | 4599 | 90 | 120 | 2 | 3 |
| 10:00 | 999 | 999 | 80 | 110 | 2 | 3 |

End: draw at 10:16, team -1 wins; clash 0:15, first base damage 0:00