extends Node
## Persistent player data: coins, level progress, owned characters and settings.

signal coins_changed
signal settings_changed

const PATH := "user://bloom.save"
const LEVEL_COUNT := 100

var coins := 0
var unlocked_to := 1
var progress := {}            # "level" -> {"stars": int, "coins": int, "best_time": float}
var owned: Array = ["orb"]
var equipped := "orb"
var total_deaths := 0

var music_on := true
var sfx_on := true
var music_vol := 0.8
var sfx_vol := 1.0
var shake_on := true
var vibrate_on := true
var fullscreen := false


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", 0))
	unlocked_to = clampi(int(data.get("unlocked_to", 1)), 1, LEVEL_COUNT)
	progress = data.get("progress", {})
	owned = data.get("owned", ["orb"])
	if not owned.has("orb"):
		owned.append("orb")
	equipped = data.get("equipped", "orb")
	if not owned.has(equipped):
		equipped = "orb"
	total_deaths = int(data.get("total_deaths", 0))
	music_on = bool(data.get("music_on", true))
	sfx_on = bool(data.get("sfx_on", true))
	music_vol = float(data.get("music_vol", 0.8))
	sfx_vol = float(data.get("sfx_vol", 1.0))
	shake_on = bool(data.get("shake_on", true))
	vibrate_on = bool(data.get("vibrate_on", true))
	fullscreen = bool(data.get("fullscreen", false))


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"coins": coins, "unlocked_to": unlocked_to, "progress": progress,
		"owned": owned, "equipped": equipped, "total_deaths": total_deaths,
		"music_on": music_on, "sfx_on": sfx_on, "music_vol": music_vol,
		"sfx_vol": sfx_vol, "shake_on": shake_on, "vibrate_on": vibrate_on,
		"fullscreen": fullscreen,
	}))


func reset_progress() -> void:
	coins = 0
	unlocked_to = 1
	progress = {}
	owned = ["orb"]
	equipped = "orb"
	total_deaths = 0
	save_data()
	coins_changed.emit()


func settings_changed_notify() -> void:
	save_data()
	settings_changed.emit()


func add_coins(n: int) -> void:
	coins += n
	save_data()
	coins_changed.emit()


func stars_of(level: int) -> int:
	return int(progress.get(str(level), {}).get("stars", 0))


func coins_of(level: int) -> int:
	return int(progress.get(str(level), {}).get("coins", 0))


func total_stars() -> int:
	var s := 0
	for k in progress:
		s += int(progress[k].get("stars", 0))
	return s


func is_unlocked(level: int) -> bool:
	return level <= unlocked_to


## Records a finished level. Returns {"stars", "bonus", "coins_earned", "new_best_stars"}.
func complete_level(level: int, coins_got: int, coins_total: int, deaths: int, time: float) -> Dictionary:
	var stars := 1
	if coins_got >= coins_total:
		stars = 2
		if deaths == 0:
			stars = 3
	var prev: Dictionary = progress.get(str(level), {})
	var first_clear := prev.is_empty()
	var bonus := 0
	if first_clear:
		bonus = 10 + level / 4
	bonus += maxi(0, stars - int(prev.get("stars", 0))) * 5
	var earned := coins_got + bonus
	var entry := {
		"stars": maxi(stars, int(prev.get("stars", 0))),
		"coins": maxi(coins_got, int(prev.get("coins", 0))),
		"best_time": minf(time, float(prev.get("best_time", 99999.0))),
	}
	progress[str(level)] = entry
	if level >= unlocked_to and level < LEVEL_COUNT:
		unlocked_to = level + 1
	coins += earned
	total_deaths += deaths
	save_data()
	coins_changed.emit()
	return {"stars": stars, "bonus": bonus, "coins_earned": earned, "first_clear": first_clear}


func owns(id: String) -> bool:
	return owned.has(id)


func buy(id: String, price: int) -> bool:
	if owns(id) or coins < price:
		return false
	coins -= price
	owned.append(id)
	save_data()
	coins_changed.emit()
	return true


func equip(id: String) -> void:
	if owns(id):
		equipped = id
		save_data()
