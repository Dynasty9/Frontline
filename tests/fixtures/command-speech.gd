extends Node

func _ready() -> void:
	var men := []
	var items := []
	for i in 80:
		var man := Soldier.new()
		man.eid = i + 1
		man.sid = i / 4 + 1
		men.append(man)
		items.append([man, "Grenade!", 1.0, "shout", float(i), Vector2.ZERO])
	var grouped := HudOverlay.command_speech(items.duplicate())
	assert(grouped.size() == 20, "A squad repeats a warning once at command zoom")
	assert(grouped[0][0] == men[0], "Keep the newest duplicate")
	for i in 80:
		items[i][1] = "Distinct warning %d" % i
	men[79].selected = true
	items[78][3] = "radio"
	items[77][3] = "medic"
	var limited := HudOverlay.command_speech(items)
	assert(limited.size() == HudOverlay.COMMAND_SPEECH_LIMIT)
	assert(limited[0][0] == men[79] and limited[1][0] == men[78] and limited[2][0] == men[77], "Selected units, orders and casualties precede routine shouts")
	assert(limited[3][0] == men[0], "Newer routine messages follow urgent calls")
	for man in men:
		man.free()
	print("COMMAND_SPEECH passed")
	get_tree().quit()
