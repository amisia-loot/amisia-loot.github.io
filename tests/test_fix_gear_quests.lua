-- A repeatable quest turned in before the quest data was parsed (it loads on demand, D-28) stays
-- open: the repeatable flag is checked when the state is asked, not at QUEST_TURNED_IN.
NS.QUEST_DATA = { built = "2026-11-07", source = "test", count = 2,
    Z = { [1429] = "Elwynn Forest" }, N = {},
    Q = {
        [400] = "1429;Daily Thing;1;;0;0;0;0;;O;;;;R",
        [401] = "1429;Once Only;1;;0;0;0;0;;O;;;;",
    },
}
STUB.class, STUB.level, STUB.faction = "WARRIOR", 12, "Alliance"
NS.Quests._reset()
-- no index yet: the turn-ins come first
STUB.fire("QUEST_TURNED_IN", 400)
STUB.fire("QUEST_TURNED_IN", 401)
assert(NS.QuestState(400).status == "open", "a repeatable quest stays open: " .. tostring(NS.QuestState(400).status))
assert(NS.QuestState(401).status == "done", "a plain quest counts as done at once")
