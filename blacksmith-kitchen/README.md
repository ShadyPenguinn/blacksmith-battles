# Blacksmith Kitchen

A hands-on forging game. Customers walk up to the counter and ask for a weapon. You make it
yourself, one short minigame at a time: crack the ore, stomp the bellows, carry the hot ingot
with tongs, hammer on the beat, quench, sharpen, wrap the grip. Every step gets a grade, and the
finished weapon gets a medal. Old Grizzle, the retired barbarian who owns the forge, watches
from the corner and has opinions.

Solo is the main game. **Rush Hour** is a chaotic co-op mode for 1-4 players on one screen,
built in the spirit of Storm Forge.

Play in the browser: https://shadypenguinn.github.io/blacksmith-battles/blacksmith-kitchen/web/

## Run it

Open this folder in Godot 4.5 or newer (built and tested on 4.7) and press F5. It is its own
project and doesn't touch Storm Forge or the tablet game.

## What carried over from the old cooking-game formula

Studied for mechanics and pacing only; names, characters, look and recipes here are all original.

- **A recipe is a chain of tiny, physical steps**, each 5-15 seconds, each with its own gesture
  (tap, hold, drag, alternate, trace, circle). Variety comes from the gesture, not from menus.
- **Every step is graded on its own** (PERFECT / GREAT / OK / OOPS) and the dish's medal is the
  average, so one bad step hurts but never ends the run. The next step always starts fresh.
- **A mentor reacts to every step**. Big praise for perfects, a forgiving grumble for mistakes.
- **Short intro card before each step**: name, one-line how-to, "Ready... GO!".
- **Familiar steps repeat across recipes** and get harder with better ingredients, so a new
  recipe is mostly steps you know plus one new one.
- **Unlocks come from playing**: new recipes and ingredients appear as you clear days, and a
  practice book lets you replay any recipe for a better medal.

## Solo: Shop Days

12 days. Each day 1-4 customers order a weapon in a metal. Clear a day (every order at Bronze or
better) to open the next. Day 12 is Grizzle's own order. Weapons you've met are unlocked in the
**Recipe Book** for practice, with the best medal saved per weapon and metal. Coins buy **Shop
Upgrades** (bellows, longer tongs, a balanced hammer, a whetstone, and a cat).

Metals: Copper, Bronze, Iron, Steel, Moonsilver, Starmetal. Harder metals tighten heat bands,
speed up meters, and need more hammer ropes.

### Running the shop

A shop day is played on the shop floor. You walk the smith around (WASD, or click/tap where to
go; click a station to walk straight to it) and press **E or Space** (or click the station
you're standing at) to use it, pick something up or put it down.

- Customers walk in and wait at the counter. Their ticket appears across the top: weapon, metal,
  route, how far along it is, and a **patience bar**. More customers arrive during the day, so
  you'll have several tickets at once. If patience runs out they storm off. Faster service pays
  more.
- Start an order at the **ore rock** (it picks the oldest ticket). You carry the work around:
  ore, crushed ore, crucible or bloom, bar, blade. A label over it and a ring on the floor show
  which station is next.
- Each station zooms in for its minigame, just like before.
- **Hands-off stations**: the **furnace** smelts on its own for a while (about 9-15 s), and a
  cast **mold** cools on its own on the casting table. While they run you're free to start the
  next order or carry another job along. Come back in time: a bloom or crucible left sitting
  in a ready furnace starts to burn and loses grade.
- **Station camera**: while you're in a minigame and the furnace or a mold is running, a small
  camera in the corner shows it. **Tab** switches which one it shows.
- Finished weapons go to the counter. The customer pays, reacts and leaves.

Tuning is in `SHOP` and `shop_stages()` in `scripts/bk.gd`; the floor logic is
`scripts/shop/shop.gd`. The Recipe Book still plays an order as a straight run of minigames.

### Two routes, like the real thing

The metal decides how the weapon is made (see `steps_for()` in `scripts/bk.gd`):

- **Cast** (Copper, Bronze, Moonsilver): these melt in a crucible, so you crush the ore, melt it,
  **pour the mold** and crack it open, then finish.
- **Forged** (Iron, Steel, Starmetal): iron never melts in an old furnace. It cooks into a spongy
  **bloom** that you pull out, squeeze the slag out of with the big hammer, **fold** (Steel: 2
  folds, Starmetal: 3), shape, quench and **temper**, then finish.

Every order starts by crushing the ore (and digging it first for some weapons). Finishing steps
(sharpen, wrap, fit, polish, etch) come from the weapon.

### The steps

| Step | Gesture | Station |
| --- | --- | --- |
| Crack the Ore | click the glowing cracks before they fade | ore rock |
| Stomp the Bellows | alternate left/right (A/D or click each side); same side twice only wheezes | furnace + Storm Forge bellows |
| Pump the Lever | up/down (W/S, left/right click, or tap top/bottom) | furnace + new lever pump |
| Tong Carry | grab the ingot that shoots out of the chimney, hold and drag it along the chalk path | floor between furnace and anvil |
| Hammer Time | hit when the marker is in the middle | anvil |
| Rope Drop | hold and drag down to haul the giant hammer; each rope only lifts so high, harder metals need 2-4 ropes; let go above the red flag | Storm Forge trip hammer kit |
| Quench | hold to dunk; let go when the temper is in the blue zone | Storm Forge dunk tank |
| Sharpen | pump two pedals in turn to keep the wheel speed in the green | KayKit grindstone + new pedals |
| Wrap the Grip | over/under on the beat as the ring closes | workbench |
| Polish | hold and scrub off grime | workbench |
| Etch a Rune | trace through numbered dots | workbench |
| Fit the Handle | drop the swinging handle into the socket, then tap it home | workbench |
| Crush the Ore | click big chunks to split them into gravel for the roasting pan; hitting gravel turns it to dust | crushing stone by the rock |
| Pour the Mold | hold to tip the crucible; pour steady (too far splashes), fill to the line before the metal cools, then click to crack the mold | sand mold on the workbench |
| Fold and Weld | drag the bar's right end over onto its left end, then hammer it shut before it cools | anvil |
| Temper | hold to warm the blade on coals; the colour runs straw, bronze, purple, blue; let go just before the target, it keeps creeping | anvil |

On the forged route the bellows and lever step is called Fire the Bloomery, Tong Carry is Pull
the Bloom, Rope Drop is Squeeze the Bloom and Hammer Time is Shape the Blade. On the cast route
the bellows and lever melt the metal.

### Recipes

Dagger, Arming Sword, Spear, Hand Axe, War Hammer, Rune Staff, Round Shield, Greatsword,
Halberd. Each takes 4-7 steps cast and 8-12 forged; see `WEAPONS` and `steps_for()` in
`scripts/bk.gd`.

## Co-op: Rush Hour

Same workshop, seen from above. Tickets arrive at the counter; customers storm off when their
timer runs out. 3.5 minute shift, stars at 60/180/320 coins.

1. **GRAB** at the rock for ore, **GRAB** at the furnace to load it.
2. **USE** on the two bellows, alternating sides, to hold the furnace in the gold band. Over-stomp
   and it burps a fireball that knocks everyone back and slags the batch.
3. The hot ingot shoots out of the chimney and lands somewhere random. **Hold USE** next to it to
   grip it with tongs; keep holding while you walk, let go at the anvil. Grabbing it bare-handed
   burns you. It goes cold after 25 s (cold ingots go back in the furnace).
4. **USE** at the anvil when the beat marker is in the gold. Two smiths hammer twice as fast.
5. **GRAB** to drop the blank in the quench tank and pull it out while it says GRAB IT NOW.
   Each dunk uses water: take the bucket to the well (far left), **USE** to fill, **USE** at the
   tank to pour. Bucket relay.
6. **GRAB** onto the grindstone, mash **USE**, then **GRAB** the finished weapon to the counter.

| | Move | Grab | Use |
| --- | --- | --- | --- |
| P1 | WASD | E | F or Space |
| P2 | Arrows | . | / or Shift |
| Gamepads | Left stick / d-pad | A | X or B |

P3 and P4 use gamepads 1 and 2. With 1-2 players, gamepads 1 and 2 also drive P1 and P2.
Rush Hour needs a keyboard or gamepad; solo works with touch.

## Files

- `scripts/bk.gd`: all tuning and data (steps, weapons, metals, customers, days, upgrades, Rush).
- `scripts/main.gd`: menus, days, the practice order flow. `scripts/shop/*.gd`: the walk-around shop day. `scripts/hud.gd`: everything on screen.
- `scripts/workshop.gd`: the 3D forge, stations, camera shots. `scripts/actor.gd`: KayKit characters.
- `scripts/games/*.gd`: one file per step. `scripts/coop/*.gd`: Rush Hour.
- `assets/models/`: KayKit (CC0) plus the Storm Forge Blender kits (bellows, furnace, trip hammer, dunk tank).

## Tests

```
# screenshots every 1.6 s of a whole order, steps auto-finishing
xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/capture.gd -- /tmp/out 1.6 30 --test-order axe 3 --autoplay
# every minigame with random input
xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/fuzz.gd
# crush, temper, fold and pour played like a person would, with scores (and screenshots)
xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/play_new.gd -- /tmp/shots
# a bot plays a whole shop day (day index, optional screenshot folder)
xvfb-run godot --rendering-driver opengl3 --path . --script res://tests/shop_test.gd -- 5 /tmp/shop
# one sword through the whole Rush Hour pipeline
godot --headless --path . --script res://tests/rush_test.gd
```

## Web build

```
godot --headless --path . --export-release Web web/index.html
```
