## A splat clip whose frame the game picks, instead of the clip looping on the clock.
## The forge's one clip holds every move of the smith; [member frame] chooses which pose shows.
extends SplatInstance

var frame: int = 0


func frame_at(_seconds: float) -> int:
	return frame
