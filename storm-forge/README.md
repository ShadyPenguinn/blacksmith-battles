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
| F or left-click | Use what you hold. By the anvil's rope handle: hold it to haul the hammer up, let go to drop it |
| Q | Throw what you hold (at the dunk tank it aims for the target) |
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
3. **Smelter** jumps on the two stomp bellows beside the furnace to blow air in (alternate sides: the same one twice in a row pumps less, and five stomps in under two seconds makes the furnace burp a fireball that knocks everyone back). Tuning is in `SF.BELLOWS`. The bellows are a custom KayKit-style model (`assets/models/stations/bellows_giant.glb`, using the Dungeon pack's texture): the lid is hinged at the nozzle and slams shut on each stomp. Keep heat in the band shown over the furnace for 3 seconds. Too hot and the batch turns to slag. The furnace mouth shows the fire: dark when there's no heat, orange while it warms up, yellow when it's the right heat for what's inside, and pulsing red when it's about to slag (colors in `SF.FIRE`).
4. The hot ingot shoots out of the furnace's chimney (the cap pops open) and lands somewhere random nearby (`SF.CHIMNEY`). The furnace is a custom KayKit-style model (`assets/models/stations/furnace_forge.glb`) with holes on both sides for the bellows nozzles. Grab it with the tongs (E) and put it on the **anvil** (E). Bare hands burn and you drop it.
5. **Anyone** grabs the red rope handle beside the anvil (hold F or the left mouse button) and walks away from the anvil to haul the giant hammer up. Let go and it drops. The higher it falls, the harder the slam. The head hangs right where the rope holds it: every meter you back up lifts it a meter, and the rope is as long as the frame is tall, so you keep backing up until it's at the top. Hauling is slow alone and quicker with friends on the rope. Let go and the loose rope whips back up through the pulley and swings before it settles. A full-height slam shakes anyone standing at the anvil off their feet. About 3 full slams shape a Copper blade. Each area the frame is taller, so the hammer goes higher. Harder metals need a longer drop before a slam does anything: a red flag on the post marks the height the head has to clear for the metal on the anvil (Copper needs none, Starmetal needs 2.5 m), and only the drop past it counts. Ingots stay hot for 30 seconds. Tuning is in `SF.TRIP`.
6. The finished blade springs off the anvil and lands on the **dunk tank** seat. Throw an ore chunk (Q) at the target sliding along the rail behind the tank. A throw at the tank flies straight on from where you stand and arcs to the target's height, so stand in its path and time it. Only a hit while it's in the middle, over the yellow stretch of rail right behind the tank, counts: the target spins over and slaps the blade into the water, and the blade quenches and rides the water slide out the front as a finished sword. A hit anywhere else just dings. Each area the target is smaller and the poles are further apart, and it always slides through the middle at the same speed, so you wait longer for it to come round. Tuning is in `SF.DUNK`. The bucket still fills at the tank.
7. Take the sword to the **door** and swing (F). Hit the glowing weak spot for double damage. A sword below the door's metal bounces off. Broken swords become scrap; put scrap back in the furnace.
8. Door down: a random buff and debuff roll, then you walk through into the next area. Each area has its own furnace, anvil and dunk tank in a new spot, plus veins of the new metal. Area 1 always uses the same starter layout.

**Ore veins** hold 3-5 chunks each (shown as "N left") and crumble when empty. About every 30 seconds, lightning cracks open a new vein somewhere in the area, up to 2 more than the area started with.

**Lightning:** a ring warns you 1.5 seconds before a strike and stops following you just before it lands, so you can dive out. Getting hit stuns you and flings what you hold. Holding metal makes you a likelier target. A full bucket splashed on a stunned friend revives them. From door 6, strikes turn ore nodes into Starmetal.

When the storm timer runs out you get a 60-second last stand with ever faster lightning.

## Tuning

Every number is at the top of `scripts/data.gd`: timer, strike rate, heat bands, the rope hammer, the dunk tank, door HP, recipes, buffs and debuffs.

## Models

The smiths, tools, anvil, ore rocks, ore chunks, bars and swords are KayKit models (CC0, by Kay Lousberg) in `assets/models/`. Each smith is a different KayKit adventurer: Barbarian (Miner), Engineer (Smelter), Knight (Smith) and Druid (Finisher). They use the KayKit Rig_Medium animations for idle, walking, running, dodging, getting struck, pickaxe swings, hammering, throwing and picking up. Ores and metals are told apart by a color tint. The furnace, the hammer frame, the dunk tank, door and walls are still placeholder boxes.

Every model path is in `SF.MODELS` in `scripts/data.gd`. An entry is a path, or `{"path", "rot"}` to turn the model first. Each model is scaled to fit its collision box, and an empty entry keeps the placeholder. Animation clip choices are in `SF.ANIM_WORDS` and `SF.ACTION_ANIMS`, and the camera distance is `SF.CAM_OFFSET`. Copy more models from the full collection into `assets/models/` and point a key at them. `assets/kaykit/` is git-ignored if you want a local scratch folder.

The run is made goofy in code on top of the KayKit clip: each step hops, squashes and waddles, the body leans in, the arms are flung out to the sides and flap, and the head wobbles. Every knob is in `SF.GOOFY` in `scripts/data.gd` (the arm and head part is `scripts/goofy.gd`). Work actions are one-shot: one press is one swing, the effect lands when the tool makes contact, the tool bounces back, and you stand still until it settles. Each swing's clip, contact time and bounce are in `SF.ACTIONS`, and the lightning launch is `SF.ZAP`. `tests/actionframes.gd` renders a mining swing, a hammer blow or a strike, and `tests/forgeframes.gd` renders the furnace glow, the rope hammer and the dunk tank (`-- /some/folder fire`, `hammer`, `dunk`, or `deep` for a later area's taller frame). `tests/camframes.gd` renders the game camera as a smith walks through an open door and back; the glide between areas is tuned in `SF.CAM_SWING`.. Movement feel (momentum, skids, the floaty jump and the belly flop) is tuned in `SF.MOVE`, and `tests/moveframes.gd` renders a run, skid, jump and flop routine. `tests/runframes.gd` saves frames of a smith sprinting past the camera to judge it (`-- /some/folder 8 side` or `front`, add `--empty` for no tool).

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

The web build lives in `storm-forge/web/` (offline only; browsers block the UDP that online play uses). Once on `main` it is served at https://shadypenguinn.github.io/blacksmith-battles/storm-forge/web/ (GitHub Pages redeploys on each push to `main`; if a merge doesn't show up, check the Actions tab for a "pages build and deployment" run). Rebuild after changes with:

```
godot --headless --path storm-forge --export-release "Web" web/index.html
```

This needs the Godot 4.7 web export templates (the `web_nothreads_*` ones).
