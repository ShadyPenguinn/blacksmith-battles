class_name BenchGame
extends Game
## Shared setup for the steps done at the workbench: the finished blade lies flat on it.

var blade: Node3D
var blade_len := 1.5

func shot() -> String:
	return "bench"

func lay_blade() -> void:
	blade_len = minf(BK.WEAPONS[order.get("weapon", "sword")]["len"], 1.7)
	blade = make_weapon(blade_len)
	BK.tint(blade, mat_color(), 0.45)
	blade.rotation_degrees = Vector3(90, 0, -90)
	blade.global_position = Workshop.BENCH + Vector3(0, ws.bench_top() + 0.08, 0.05)

## A point along the blade, from grip (0) to tip (1), on screen.
func along(f: float) -> Vector2:
	var a = Workshop.BENCH + Vector3(-blade_len * 0.5, ws.bench_top() + 0.1, 0.05)
	var b = Workshop.BENCH + Vector3(blade_len * 0.5, ws.bench_top() + 0.1, 0.05)
	return ws.to_screen(a.lerp(b, f))

func along3(f: float) -> Vector3:
	return Workshop.BENCH + Vector3(lerpf(-blade_len * 0.5, blade_len * 0.5, f), ws.bench_top() + 0.1, 0.05)
