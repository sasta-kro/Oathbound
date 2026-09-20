extends GutTest
## The main story's pacing through Area One: the quests between the first
## fight and the Black Knight, and the XP they are worth, should bring the
## starter to about level 15 by the time the Warden offers the boss.

const AREA_ONE := "res://areas/area_one.tscn"
const AREA_TWO := "res://areas/area_two.tscn"
const AREA_THREE := "res://areas/area_three.tscn"
const BOSS_QUEST_ID := &"quest_main_03_the_black_knight"
const KINGSWORN_QUEST_ID := &"quest_main_09_the_kingsworn"
const KING_QUEST_ID := &"quest_main_13_the_king_in_the_barrow"
const TARGET_LEVEL := 15
## Where the deep chain should leave the lead: at the Kingsworn, and at the
## king on the barrow, which is the level cap and the end of the story.
const KINGSWORN_TARGET_LEVEL := 28
const KING_TARGET_LEVEL := 38
## The main chain in story order, ending with the boss quest.
const CHAIN: Array[StringName] = [
	&"quest_main_01_beyond_the_walls",
	&"quest_main_01a_a_second_oath",
	&"quest_main_01b_room_for_more",
	&"quest_main_01c_field_mending",
	&"quest_main_01d_who_walks_in_front",
	&"quest_main_01e_strike_first",
	&"quest_main_01f_caught_in_the_open",
	&"quest_main_01g_no_battle_at_all",
	&"quest_main_01h_a_bed_at_the_hearthside",
	&"quest_main_01i_a_stocked_satchel",
	&"quest_main_01j_the_road_is_waiting",
	&"quest_main_02_the_ruined_road",
	&"quest_main_02_to_the_ranger",
	&"quest_main_02a_scalded_shallows",
	&"quest_main_02a_to_the_woodcutter",
	&"quest_main_02b_wings_in_the_wood",
	&"quest_main_02b_to_the_warden",
	&"quest_main_02c_the_hollow_watch",
	BOSS_QUEST_ID,
]
## The chain under the altar, in story order, ending with the king.
const DEEP_CHAIN: Array[StringName] = [
	&"quest_main_04_the_stair_shut",
	&"quest_main_04_to_the_archivist",
	&"quest_main_05_the_record",
	&"quest_main_05_to_the_gravewright",
	&"quest_main_06_what_the_dead_carry",
	&"quest_main_06_to_the_bellkeeper",
	&"quest_main_07_the_inside_of_the_door",
	&"quest_main_07_to_the_nurse",
	&"quest_main_08_a_champions_kit",
	&"quest_main_08_to_aldric",
	KINGSWORN_QUEST_ID,
	&"quest_main_10_the_dead_wood",
	KING_QUEST_ID,
]
## Where each half of the deep chain is fought, so a quest's foes are costed
## at the levels of the area the player meets them in. Both areas hold some
## of the same species at different levels.
const DEEP_CHAIN_AREA: Dictionary = {
	&"quest_main_04_the_stair_shut": AREA_TWO,
	&"quest_main_05_the_record": AREA_TWO,
	&"quest_main_06_what_the_dead_carry": AREA_TWO,
	&"quest_main_07_the_inside_of_the_door": AREA_TWO,
	&"quest_main_08_a_champions_kit": AREA_TWO,
	&"quest_main_04_to_the_archivist": AREA_TWO,
	&"quest_main_05_to_the_gravewright": AREA_TWO,
	&"quest_main_06_to_the_bellkeeper": AREA_TWO,
	&"quest_main_07_to_the_nurse": AREA_TWO,
	&"quest_main_08_to_aldric": AREA_TWO,
	KINGSWORN_QUEST_ID: AREA_TWO,
	&"quest_main_10_the_dead_wood": AREA_THREE,
	KING_QUEST_ID: AREA_THREE,
}
## Fights a player picks up walking between quest areas, as a rough share of
## the XP the required kills pay. Hostile creatures sit along every route.
const INCIDENTAL_SHARE := 0.2


## The whole story, town to barrow, as one unbroken line of requirements.
func _full_chain() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(CHAIN)
	out.append_array(DEEP_CHAIN)
	return out


func test_the_main_chain_runs_in_order() -> void:
	var chain: Array[StringName] = _full_chain()
	for index: int in range(1, chain.size()):
		var quest: QuestData = Content.get_quest(chain[index])
		assert_not_null(quest, "%s ships." % chain[index])
		if quest == null:
			continue
		assert_eq(quest.requires, chain[index - 1], "%s follows %s." % [chain[index], chain[index - 1]])
		assert_true(quest.is_main(), "%s is a main quest." % chain[index])


## No main quest may be left off the chain, or the story would fork and the
## player would be left with a thread nothing leads to.
func test_every_main_quest_is_on_the_chain() -> void:
	var chain: Array[StringName] = _full_chain()
	for quest: QuestData in Content.all_quests():
		if quest.is_main():
			assert_true(chain.has(quest.id), "%s is on the main chain." % quest.id)


func test_every_quest_giver_stands_in_the_world() -> void:
	var givers: Dictionary = {}
	for scene_path: String in ["res://areas/town.tscn", AREA_ONE, AREA_TWO, AREA_THREE]:
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


## Species id -> the level that species is met at in [param scene_path]:
## the middle of its spawn zone's range, or the exact level of a creature the
## map places by hand, which always wins because it is the fight the quest
## means.
func _levels_in(scene_path: String) -> Dictionary:
	var area: Node = autofree((load(scene_path) as PackedScene).instantiate())
	var out: Dictionary = {}
	for zone: SpawnZone in area.get_node("SpawnZones").get_children():
		if zone.species != null:
			out[zone.species.id] = (zone.level_min + zone.level_max) / 2.0
	for actor: Node in area.get_node("Actors").get_children():
		if actor is WildCreature and (actor as WildCreature).species != null:
			out[(actor as WildCreature).species.id] = float((actor as WildCreature).level)
	return out


## Plays the deep chain on paper the way [method
## test_the_guided_path_reaches_the_boss_near_level_15] plays Area One's: the
## lead kills what each quest asks for, at the level that area meets it at,
## plus a share for the fights on the way, and collects the quest rewards.
func test_the_deep_chain_reaches_the_king_near_level_38() -> void:
	var lead: CreatureInstance = Content.spawn_creature(GameState.STARTER_SPECIES_ID, TARGET_LEVEL)
	var levels: Dictionary = {AREA_TWO: _levels_in(AREA_TWO), AREA_THREE: _levels_in(AREA_THREE)}
	var at_kingsworn: int = 0
	for id: StringName in DEEP_CHAIN:
		var quest: QuestData = Content.get_quest(id)
		assert_not_null(quest, "%s ships." % id)
		if quest == null:
			continue
		if id == KINGSWORN_QUEST_ID:
			at_kingsworn = lead.level
		if id == KING_QUEST_ID:
			break
		var here: Dictionary = levels[DEEP_CHAIN_AREA[id]]
		var earned: float = 0.0
		for objective: QuestObjective in quest.objectives:
			if objective.kind != QuestObjective.Kind.DEFEAT:
				continue
			assert_true(here.has(objective.target), "%s meets %s in its own area." % [id, objective.target])
			if not here.has(objective.target):
				continue
			var foe: CreatureInstance = Content.spawn_creature(
				objective.target, int(round(float(here[objective.target])))
			)
			earned += float(BattleRules.xp_for_defeating(foe) * objective.required())
		lead.gain_xp(int(earned * (1.0 + INCIDENTAL_SHARE)) + quest.reward_xp)
	gut.p("Lead reaches the Kingsworn at level %d and the king at level %d." % [at_kingsworn, lead.level])
	# A floor, not a window. Quests are written for what they are about
	# rather than to a level budget, and grinding is the answer to a fight
	# the player cannot win, so coming out above the target is fine.
	assert_gte(
		at_kingsworn,
		KINGSWORN_TARGET_LEVEL - 2,
		"At least level 26 when Aldric offers the Kingsworn."
	)
	# Area Three is deliberately short: two quests, the wood and the king.
	# The chain alone does not carry the player to the king's recommended
	# level, so the last stretch is grinding ground rather than a guided
	# climb. The floor here only holds the gap to something a party can
	# close in the wood rather than having to go back up two areas for it.
	assert_gte(
		lead.level,
		KING_TARGET_LEVEL - 6,
		"At least level 32 when the Last Champion offers the king."
	)


## The last two quests are written for the cap, and the king is the ceiling.
func test_the_king_is_written_for_the_level_cap() -> void:
	var king: QuestData = Content.get_quest(KING_QUEST_ID)
	assert_not_null(king)
	assert_eq(king.recommended_level, KING_TARGET_LEVEL)
	assert_true(king.is_underleveled(30))
	assert_false(king.is_underleveled(CreatureRules.GLOBAL_MAX_LEVEL))
	assert_string_contains(king.caution_text(), str(KING_TARGET_LEVEL))


## The whole story walked end to end through a live log: each quest becomes
## offerable only once the one before it is finished, its objectives can all
## be met, and finishing it opens exactly one more.
func test_the_whole_story_can_be_walked_in_order() -> void:
	var log := QuestLog.new(Content)
	var chain: Array[StringName] = _full_chain()
	for index: int in chain.size():
		var quest: QuestData = Content.get_quest(chain[index])
		assert_not_null(quest, "%s ships." % chain[index])
		if quest == null:
			return
		assert_true(log.can_offer(quest), "%s comes up in its turn." % quest.id)
		for later: int in range(index + 1, chain.size()):
			var ahead: QuestData = Content.get_quest(chain[later])
			assert_false(log.can_offer(ahead), "%s waits for %s." % [chain[later], quest.id])
		assert_true(log.accept(quest), "%s can be taken." % quest.id)
		for objective: QuestObjective in quest.objectives:
			for _step: int in objective.required():
				log.report(objective.kind, objective.target)
		assert_true(log.is_ready(quest), "%s can be finished." % quest.id)
		assert_true(log.complete(quest), "%s can be handed in." % quest.id)
	assert_eq(log.completed_quests().size(), chain.size(), "The whole story is behind the player.")
