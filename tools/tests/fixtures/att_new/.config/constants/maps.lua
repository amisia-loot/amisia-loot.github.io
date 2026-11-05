-- Hand-made test fixture in the builder language of the Forever data (the form since November 2026; not real data).
local mapMetatable = {
	__index = function(t, mapKey)
		error("Unknown map key MAP." .. mapKey);
	end
};
local _MAP = setmetatable({
	TEST_MOOR = 1427;
	TEST_KEEP = 9201;
	TEST_ISLE = 2521;
}, mapMetatable);

for mapConst, mapID in pairs(_MAP) do
	_G[mapConst] = mapID;
	MAP[mapConst] = mapID;
end
