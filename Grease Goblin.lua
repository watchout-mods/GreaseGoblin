local MAJOR, Addon = ...;
LibStub("AceAddon-3.0"):NewAddon(Addon, MAJOR,
	"AceEvent-3.0"
);
_G.greasegoblin = Addon; -- debug
local pairs, tremove, max
    = pairs, tremove, max;

--[[ -----------------------------   OPTIONS  ----------------------------- ]]--
local DefaultEditorOptions = {
	profile = {
		__version   = 1,
		Syntax      = "Lua", -- Sets the default syntax scheme
		Highlight   = true,  -- Enable or Disable syntax highlighting
		AutoIndent  = true,  -- automatically indent on new line
		SmartIndent = false, -- improves auto-indent to semantic awareness
		AutoSuggest = false, -- other possible values are: TOP, RIGHT, BOTTOM, LEFT,
		LineNumbers = false, -- show line numbers
		TabWidth    = 4,
		TabToSpaces = false, -- convert tabs to spaces automatically?
	}
}

local DefaultGoblins = {
	profile = {
		["?"] = 1, -- This is the db version number
		Hello = [==[
-- OnLoad: true
print("Hello World!", ...);
]==]
	}
};

--[[ ------------------------  PRIVATE  VARIABLES  ------------------------ ]]--
local Empty = function() end;
local GoblinCache = setmetatable({
	["?"] = Empty,
}, {
--	__mode = "v",
	__index = function(self, id)
		if Addon.Goblins.profile[id] then
			local g = Addon:PrepareGoblin(id, Addon.Goblins.profile[id]);
			self[id] = g;
			return g;
		end
		return Empty;
	end,
});

--[[ ----------------------------  ADDON CODE  ---------------------------- ]]--
function Addon:OnInitialize()
	local AceDB = LibStub("AceDB-3.0");
	-- load config from acedb-savedvariables
	self.Options = AceDB:New("Greasegoblin_Options", DefaultEditorOptions, true);
	self.Goblins = AceDB:New("Greasegoblins", DefaultGoblins, true);
end

function Addon:OnEnable()
	for id, rawcode in pairs(self.Goblins.profile) do
		local _dummy = GoblinCache[id];
	end
end

---
-- Prepares a Goblin (script) with ID `id`
-- You probably don't want to call this externally.
function Addon:PrepareGoblin(id, rawcode)
	local Goblin = {};
	Goblin.Code = rawcode;
	Goblin.Frame = CreateFrame("frame");
	for line in rawcode:gmatch("(.-)[\n\r]+") do
		local key, value = line:match("^%-%-%s*(.-)%s*:%s*(.-)%s*$");
		--print("match", key, value, "[END]");
		if key == "OnEvent" then
			Goblin.Frame:RegisterEvent(value);
		elseif key == "OnLoad" and value == "true" then
			self:Queue(id, "LOAD");
		elseif key == nil then
			break; -- only allow the first lines of the script for special comments
		else
			-- ignore unknown keys
		end
	end
	Goblin.Function = assert(loadstring("return function(self, ...) "..rawcode.." end;", id))();
	Goblin.Frame:SetScript("OnEvent", function(self, ...)
		return Goblin:Function(...);
	end);
	
	return Goblin;
end

function Addon:RunGoblin(id, ...)
	GoblinCache[id].Function(GoblinCache[id], ...);
end

function Addon:UpdateGoblin(id, code)
	if id ~= "?" then
		GoblinCache[id].Frame:UnregisterAllEvents();
		GoblinCache[id].Frame:Hide();
		GoblinCache[id] = nil;
		Addon.Goblins.profile[id] = code;
		local dummy = GoblinCache[id];
	end
end

function Addon:DeleteGoblin(id, ...)
	if id ~= "?" then
		GoblinCache[id] = nil;
		Addon.Goblins.profile[id] = nil;
	end
end

local Queue, QueueWorker = {};
function Addon:Queue(id, ...)
	Queue[#Queue+1] = (function(...)
		local args = {...};
		return function()
			GoblinCache[id].Function(GoblinCache[id], unpack(args));
		end
	end)(...);
	
	if not QueueWorker then
		QueueWorker = CreateFrame("frame");
		QueueWorker:SetScript("OnUpdate", function()
			local g = tremove(Queue);
			if #Queue == 0 then
				QueueWorker:Hide();
			end
			if g then
				xpcall(g, geterrorhandler());
			end
		end);
	end
	QueueWorker:Show();
end

