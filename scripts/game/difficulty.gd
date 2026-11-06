class_name Difficulty
extends RefCounted
## The three difficulties, chosen when you press Play. They set your hearts
## and how the blaster works; the cave itself is the same for a seed (so
## leaderboard seeds replay the same cave), except ammo crates only appear
## on Medium.
##
##   Easy    5 hearts, unlimited shots with a short cooldown
##   Medium  3 hearts, 6 shots + ammo crates (+5 each)
##   Hard    1 heart,  10 shots for the whole cave, no crates
## On Medium and Hard an empty blaster slowly recharges one shot, so a cave
## can never become impossible because of wasted shots.

const IDS: Array[String] = ["easy", "medium", "hard"]
const RECHARGE_S := 15.0
const CRATE_AMMO := 5

const TABLE := {
	"easy": {"name": "Easy", "hearts": 5, "ammo": -1, "cooldown": 0.4, "crates": false, "about": "5 hearts. Unlimited shots (short cooldown)."},
	"medium": {"name": "Medium", "hearts": 3, "ammo": 6, "cooldown": 0.25, "crates": true, "about": "3 hearts. 6 shots, plus ammo crates."},
	"hard": {"name": "Hard", "hearts": 1, "ammo": 10, "cooldown": 0.25, "crates": false, "about": "1 heart. 10 shots for the whole cave."},
}


static func valid(id: String) -> String:
	return id if TABLE.has(id) else "medium"


static func get_value(id: String, key: String) -> Variant:
	return TABLE[valid(id)][key]


static func label(id: String) -> String:
	return str(get_value(id, "name"))
