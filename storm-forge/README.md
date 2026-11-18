# Storm Forge (graybox)

Graybox of the co-op forge game, offline or online for up to 4 players: four smiths, one door, a storm on the clock.
Placeholder shapes only. Plan doc: https://claude.ai/artifact/1pAswscawc9NFi3Y5E4wYF

## Run it

Open this `storm-forge` folder in Godot 4.5 or newer (tested on 4.7) and press F5.
It uses Jolt physics, which is built into Godot.

The menu offers three choices:

- **Play offline**: you control one smith at a time. Press Tab to jump between them and run the whole pipeline yourself.
- **Host a game**: wait in the lobby for friends, then press Start. Each player gets one smith in join order (host = Miner, then Smelter, Smith, Finisher). Smiths nobody plays leave their tool on the floor for anyone to pick up.
- **Join**: type the host's IP address and press Join.

Online uses direct IP on port 7777 (UDP). On the same Wi-Fi, use the host's local IP (like 192.168.x.x). Over the internet, the host forwards UDP port 7777 on their router. Steam lobbies will replace this later.

Command-line shortcuts: `--offline`, `--host`, `--join 1.2.3.4`, `--autostart 2` (host starts when 2 players are in). Put them after `--`, for example `godot --path storm-forge -- --host`.

| Key | Does |
| --- | --- |
| WASD or arrows | Move |
| Shift | Sprint |
| Space | Jump. Press again in the air to belly flop (dodge lightning) |
| E or right-click | Grab into your hotbar, put things on a station (from your hand or pockets), grip with tongs, or drop |
| F or left-click | Use what you hold |
| Q | Throw what you hold |
| 1-4 or mouse wheel | Pick a hotbar slot |
| Tab | Offline: switch smith (Miner, Smelter, Smith, Finisher) |
| L | Debug: call lightning on yourself |
| N | Debug: skip to the next door |
| R | Restart after the run ends |

## Hotbar

Every smith has 4 slots. Slot 1 holds your one tool, and you can never carry two tools. Slots 2-4 hold anything else, like 3 chunks of ore. The selected slot is what's in your hand: F uses it and Q throws it. Everything else rides on your back where friends can see it. Each extra heavy thing slows you a bit more, all of it raises your lightning odds, and a strike flings the lot. Press E at the furnace to dump all your ore in at once.

## The loop

1. **Miner** hits an ore node 3 times with the pickaxe. A chunk pops out.
2. Press E by the chunk to pocket it (the pickaxe stays in hand), then E at the **furnace** to put it in. Hauling slows you down.
3. **Smelter** jumps on the two stomp bellows beside the furnace to blow air in (alternate sides: the same one twice in a row pumps less, and five stomps in under two seconds makes the furnace burp a fireball that knocks everyone back). Tuning is in `SF.BELLOWS`. Keep heat in the band shown over the furnace for 3 seconds. Too hot and the batch turns to slag.
4. The hot ingot pops out. Grab it with the tongs (E) and put it on the **anvil** (E). Bare hands burn and you drop it.
5. **Smith** hits the anvil with the hammer (F) when the O is in the `===` zone. 4 hits makes a blade, 3 misses makes scrap.
6. Carry the blade to the **grindstone**. **Finisher** fills the bucket at the trough, quenches the blade, then grinds on the beat 3 times.
7. Take the sword to the **door** and swing (F). Hit the glowing weak spot for double damage. A sword below the door's metal bounces off. Broken swords become scrap; put scrap back in the furnace.
8. Door down: a random buff and debuff roll, then you walk through into the next area. Each area has its own furnace, anvil, grindstone and trough in a new spot, plus veins of the new metal. Area 1 always uses the same starter layout.

**Ore veins** hold 3-5 chunks each (shown as "N left") and crumble when empty. About every 30 seconds, lightning cracks open a new vein somewhere in the area, up to 2 more than the area started with.

**Lightning:** a ring warns you 1.5 seconds before a strike and stops following you just before it lands, so you can dive out. Getting hit stuns you and flings what you hold. Holding metal makes you a likelier target. A full bucket splashed on a stunned friend revives them. From door 6, strikes turn ore nodes into Starmetal.

When the storm timer runs out you get a 60-second last stand with ever faster lightning.

## Tuning

Every number is at the top of `scripts/data.gd`: timer, strike rate, heat bands, beat windows, door HP, recipes, buffs and debuffs.

## Models

The smiths, tools, anvil, grindstone, ore rocks, ore chunks, bars and swords are KayKit models (CC0, by Kay Lousberg) in `assets/models/`. Each smith is a different KayKit adventurer: Barbarian (Miner), Engineer (Smelter), Knight (Smith) and Druid (Finisher). They use the KayKit Rig_Medium animations for idle, walking, running, dodging, getting struck, pickaxe swings, hammering, throwing and picking up. Ores and metals are told apart by a color tint. The furnace, trough, door and walls are still placeholder boxes.

Every model path is in `SF.MODELS` in `scripts/data.gd`. An entry is a path, or `{"path", "rot"}` to turn the model first. Each model is scaled to fit its collision box, and an empty entry keeps the placeholder. Animation clip choices are in `SF.ANIM_WORDS` and `SF.ACTION_ANIMS`, and the camera distance is `SF.CAM_OFFSET`. Copy more models from the full collection into `assets/models/` and point a key at them. `assets/kaykit/` is git-ignored if you want a local scratch folder.

The run is made goofy in code on top of the KayKit clip: each step hops, squashes and waddles, the body leans in, the arms are flung out to the sides and flap, and the head wobbles. Every knob is in `SF.GOOFY` in `scripts/data.gd` (the arm and head part is `scripts/goofy.gd`). Work actions are one-shot: one press is one swing, the effect lands when the tool makes contact, the tool bounces back, and you stand still until it settles. Each swing's clip, contact time and bounce are in `SF.ACTIONS`, and the lightning launch is `SF.ZAP`. `tests/actionframes.gd` renders a mining swing, a hammer blow or a strike. Movement feel (momentum, skids, the floaty jump and the belly flop) is tuned in `SF.MOVE`, and `tests/moveframes.gd` renders a run, skid, jump and flop routine. `tests/runframes.gd` saves frames of a smith sprinting past the camera to judge it (`-- /some/folder 8 side` or `front`, add `--empty` for no tool).

`tests/closeup.gd` renders close-up frames of a smith idling, walking, mining and getting struck:

```
xvfb-run godot --rendering-driver opengl3 --path storm-forge --script res://tests/closeup.gd -- /some/folder
```

## Tests

```
godot --headless --path storm-forge --script res://tests/smoke_test.gd
xvfb-run godot --rendering-driver opengl3 --path storm-forge --script res://tests/screenshot.gd -- /some/folder
```

The smoke test runs the whole pipeline from ore to a broken door, plus lightning, revive and game over.

The online test runs a real host and client over localhost. Start both at once:

```
godot --headless --path storm-forge --script res://tests/net_test.gd -- host --autostart 2
godot --headless --path storm-forge --script res://tests/net_test.gd -- client
```

## Not in yet

Proximity voice, Steam lobbies (no port forwarding), joining a run already in progress, client-side movement prediction, real ragdolls (stunned smiths just tumble), the moon mechanic for Moonsilver, the two-door Sky Bridge, the Steel quench window, voting between rolls, and sound.

## Play in a browser

The web build lives in `storm-forge/web/` (offline only; browsers block the UDP that online play uses). Once on `main` it is served at https://shadypenguinn.github.io/blacksmith-battles/storm-forge/web/ . Rebuild after changes with:

```
godot --headless --path storm-forge --export-release "Web" web/index.html
```

This needs the Godot 4.7 web export templates (the `web_nothreads_*` ones).
