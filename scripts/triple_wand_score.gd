extends RefCounted

const GAME_ID := "triple_wand_trial"
const DEFAULT_FAST_TIME := 20.0
const DEFAULT_SLOW_TIME := 90.0


static func calculate(seconds: float, fast_time: float, slow_time: float) -> Dictionary:
	if not is_finite(fast_time) or not is_finite(slow_time) or fast_time < 0.0 or slow_time <= fast_time:
		fast_time = DEFAULT_FAST_TIME
		slow_time = DEFAULT_SLOW_TIME
	var score := clampf(100.0 * (slow_time - seconds) / (slow_time - fast_time), 0.0, 100.0)
	return {
		"game_id": GAME_ID,
		"completion_time_seconds": seconds,
		"performance_score": score,
		"completed": true,
		"gryffindor_points": score * 0.40,
		"slytherin_points": score * 0.20,
		"ravenclaw_points": score * 0.15,
		"hufflepuff_points": score * 0.25,
	}
