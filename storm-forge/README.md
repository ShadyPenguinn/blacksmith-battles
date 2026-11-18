# Storm Forge (graybox)

Offline graybox of the co-op forge game: four smiths, one door, a storm on the clock.
Placeholder shapes only. Plan doc: https://claude.ai/artifact/1pAswscawc9NFi3Y5E4wYF

## Run it

Open this `storm-forge` folder in Godot 4.5 or newer (tested on 4.7) and press F5.
It uses Jolt physics, which is built into Godot.

You control one smith at a time. Press 1-4 to jump between them and run the whole pipeline yourself.

| Key | Does |
| --- | --- |
| WASD or arrows | Move |
| Shift | Sprint |
| Space | Dive (dodge lightning) |
| E or right-click | Grab, place on a station, grip with tongs, or drop |
| F or left-click | Use what you hold |
| Q | Throw what you hold |
| 1-4 | Switch smith: Miner, Smelter, Smith, Finisher |
| L | Debug: call lightning on yourself |
| N | Debug: skip to the next door |
| R | Restart after the run ends |

## The loop

1. **Miner** hits an ore node 3 times with the pickaxe. A chunk pops out.
2. Anyone carries ore to the **furnace** (E). Hauling slows you down.
3. **Smelter** uses the tongs at the furnace to pump the bellows. Keep heat in the band shown over the furnace for 3 seconds. Too hot and the batch turns to slag.
4. The hot ingot pops out. Grab it with the tongs (E) and put it on the **anvil** (E). Bare hands burn and you drop it.
5. **Smith** hits the anvil with the hammer (F) when the O is in the `===` zone. 4 hits makes a blade, 3 misses makes scrap.
6. Carry the blade to the **grindstone**. **Finisher** fills the bucket at the trough, quenches the blade, then grinds on the beat 3 times.
7. Take the sword to the **door** and swing (F). Hit the glowing weak spot for double damage. A sword below the door's metal bounces off. Broken swords become scrap; put scrap back in the furnace.
8. Door down: a random buff and debuff roll, then the next area with a new metal.

**Lightning:** a ring warns you 1.5 seconds before a strike and stops following you just before it lands, so you can dive out. Getting hit stuns you and flings what you hold. Holding metal makes you a likelier target. A full bucket splashed on a stunned friend revives them. From door 6, strikes turn ore nodes into Starmetal.

When the storm timer runs out you get a 60-second last stand with ever faster lightning.

## Tuning

Every number is at the top of `scripts/data.gd`: timer, strike rate, heat bands, beat windows, door HP, recipes, buffs and debuffs.

## Dropping in KayKit models

Copy models into `assets/kaykit/` (git ignores that folder) and set paths in `SF.MODELS` in `scripts/data.gd`, for example `"anvil": "res://assets/kaykit/anvil.gltf"`. Any key left empty keeps its placeholder shape. Collision boxes stay the same size, so scale the model to fit.

## Tests

```
godot --headless --path storm-forge --script res://tests/smoke_test.gd
xvfb-run godot --rendering-driver opengl3 --path storm-forge --script res://tests/screenshot.gd -- /some/folder
```

The smoke test runs the whole pipeline from ore to a broken door, plus lightning, revive and game over.

## Not in yet

Online play and proximity voice, real ragdolls (stunned smiths just tumble), the moon mechanic for Moonsilver, the two-door Sky Bridge, the Steel quench window, voting between rolls, and sound.
