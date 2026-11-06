class_name Scoring
extends RefCounted
## Points for a cleared cave. The leaderboard Worker works the score out the
## same way (leaderboard-api/src/board.js computeScore): keep them in step.
##
##   100 per gem
##   500 for clearing the cave without getting hurt
##   5 per second faster than par (par = 20 seconds per gem)

const GEM_POINTS := 100
const NO_DAMAGE_BONUS := 500
const PAR_S_PER_GEM := 20
const SPEED_POINTS_PER_S := 5


static func speed_bonus(gems: int, time_ms: int) -> int:
	var seconds: int = time_ms / 1000
	return maxi(0, gems * PAR_S_PER_GEM - seconds) * SPEED_POINTS_PER_S


static func total(gems: int, time_ms: int, no_damage: bool) -> int:
	return gems * GEM_POINTS + (NO_DAMAGE_BONUS if no_damage else 0) + speed_bonus(gems, time_ms)


## "1:05.3" style time.
static func format_time(time_ms: int) -> String:
	var tenths: int = (time_ms / 100) % 10
	var seconds: int = (time_ms / 1000) % 60
	var minutes: int = time_ms / 60000
	return "%d:%02d.%d" % [minutes, seconds, tenths]
