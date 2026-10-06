-- Hand-made test fixture in the builder language of the Forever data the tool reads (not real data).
local mapMetatable = {
	__index = function(t, mapKey)
		error("Unknown map key MAP." .. mapKey);
	end
};
MAP = setmetatable({
	TEST_CITY = 1455;
	TEST_HILLS = 1426;
	TEST_HALLS = 9101;
	TEST_DEEP = 9102;
}, mapMetatable);

-- as the real file does: the map constants become globals too
for mapConst,mapID in pairs(MAP) do
	_G[mapConst] = mapID;
end
