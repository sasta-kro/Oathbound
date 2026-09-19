extends GutTest
## The main story's pacing through Area One: the quests between the first
## fight and the Black Knight, and the XP they are worth, should bring the
## starter to about level 15 by the time the Warden offers the boss.

const AREA_ONE := "res://areas/area_one.tscn"
const BOSS_QUEST_ID := &"quest_main_03_the_black_knight"
const TARGET_LEVEL := 15
## The main chain in story order, ending with the boss quest.
const CHAIN: Array[StringName] = [
	&"quest_main_01_beyond_the_walls",
	&"quest_main_01a_a_second_oath",
	&"quest_main_01b_field_mending",
	&"quest_main_02_the_ruined_road",
	&"quest_main_02a_scalded_shallows",
	&"quest_main_02b_wings_in_the_wood",
	&"quest_main_02c_the_hollow_watch",
	BOSS_QUEST_ID,
]
## Fights a player picks up walking between quest areas, as a rough share of
## the XP the required kills pay. Hostile creatures sit along every route.
const INCIDENTAL_SHARE := 0.2


func test_the_main_chain_runs_in_order() -> void:
	for index: int in range(1, CHAIN.size()):
		var quest: QuestData = Content.get_quest(CHAIN[index])
		assert_not_null(quest, "%s ships." % CHAIN[index])
		assert_eq(quest.requires, CHAIN[index - 1], "%s follows %s." % [CHAIN[index], CHAIN[index - 1]])
		assert_true(quest.is_main())


func test_every_quest_giver_stands_in_the_world() -> void:
	var givers: Dictionary = {}
	for scene_path: String in ["res://areas/town.tscn", AREA_ONE]:
		var area: Node = autofree((load(scene_path) as PackedScene).instantiate())
		for actor: Node in area.get_node("Actors").get_children():
			if actor is WorldActor and not actor is WildCreature:
				for id: StringName in (actor as WorldActor).quest_ids:
					givers[id] = (actor as WorldActor).actor_id()
	for quest: QuestData in Content.all_quests():
		if quest.id == &"":
			continue
		assert_eq(givers.get(quest.id, &""), quest.giver, "%s is carried by its giver." % quest.id)


func test_the_boss_warns_an_underleveled_party() -> void:
	var boss_quest: QuestData = Content.get_quest(BOSS_QUEST_ID)
	assert_eq(boss_quest.recommended_level, TARGET_LEVEL)
	assert_true(boss_quest.is_underleveled(12))
	assert_false(boss_quest.is_underleveled(15))
	assert_string_contains(boss_quest.caution_text(), "15")


func test_spawn_levels_climb_along_the_quest_path() -> void:
	var levels: Dictionary = _zone_levels()
	var path: Array[StringName] = [
		&"creature_fire_01", &"creature_fire_03", &"creature_wind_02", &"creature_earth_03"
	]
	for index: int in range(1, path.size()):
		assert_gt(levels[path[index]], levels[path[index - 1]], "%s is tougher than %s." % [path[index], path[index - 1]])


## Plays the chain on paper: the starter kills what each main quest asks for,
## at the middle of its zone's level range, plus a share for fights on the
## way, and collects every quest's XP. It should reach the boss at about the
## target level without having already evolved past it.
func test_the_guided_path_reaches_the_boss_near_level_15() -> void:
	var starter: CreatureInstance = Content.spawn_creature(GameState.STARTER_SPECIES_ID, GameState.STARTER_LEVEL)
	var levels: Dictionary = _zone_levels()
	var area: Node = autofree((load(AREA_ONE) as PackedScene).instantiate())
	var guardian: WildCreature = area.get_node("Actors/Guardian")
	for id: StringName in CHAIN:
		if id == BOSS_QUEST_ID:
			break
		var quest: QuestData = Content.get_quest(id)
		var earned: float = 0.0
		for objective: QuestObjective in quest.objectives:
			if objective.kind != QuestObjective.Kind.DEFEAT:
				continue
			# The Cinderclaw the Warden asks for is the hand-placed Guardian.
			var level: float = (
				float(guardian.level)
				if objective.target == guardian.species.id
				else float(levels[objective.target])
			)
			var foe: CreatureInstance = Content.spawn_creature(objective.target, int(round(level)))
			earned += float(BattleRules.xp_for_defeating(foe) * objective.required())
		starter.gain_xp(int(earned * (1.0 + INCIDENTAL_SHARE)) + quest.reward_xp)
	gut.p("Starter reaches the Warden's boss offer at level %d (%d XP)." % [starter.level, starter.total_xp])
	assert_between(starter.level, TARGET_LEVEL - 1, TARGET_LEVEL, "Around level 15 at the boss.")


## Species id -> middle of its spawn zone's level range in Area One.
func _zone_levels() -> Dictionary:
	var area: Node = autofree((load(AREA_ONE) as PackedScene).instantiate())
	var out: Dictionary = {}
	for zone: SpawnZone in area.get_node("SpawnZones").get_children():
		out[zone.species.id] = (zone.level_min + zone.level_max) / 2.0
	return out
