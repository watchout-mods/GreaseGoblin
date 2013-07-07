local MAJOR, Addon = ...;
local DBVERSION = 2;
LibStub("AceAddon-3.0"):NewAddon(Addon, MAJOR,
	"AceEvent-3.0"
);
_G.greasegoblin = Addon; -- debug
local pairs, tremove, max, gsub
    = pairs, tremove, max, gsub;

--[[ -----------------------------   OPTIONS  ----------------------------- ]]--
local DefaultOptions = {
	profile = {
		_Version = false, -- This is the db version number
		
		Editor = {
			Syntax      = "Lua", -- Sets the default syntax scheme
			Highlight   = true,  -- Enable or Disable syntax highlighting
			AutoIndent  = true,  -- automatically indent on new line
			SmartIndent = false, -- improves auto-indent to semantic awareness
			AutoSuggest = false, -- 
			LineNumbers = false, -- show line numbers
			TabWidth    = 4,
			TabToSpaces = false, -- convert tabs to spaces automatically?
		}, 
		Scripts = {},
		ScriptStates = {},
	},
};
local DefaultScript = [[
-- OnLoad: true
print("Hello World!", ...);
]];

--[[ ------------------------  PRIVATE  VARIABLES  ------------------------ ]]--
local Empty = function() end;
local GoblinMetatable;
local GoblinCache = setmetatable({
	["?"] = Empty,
}, {
--	__mode = "v",
	__index = function(self, id)
		if Addon.Options.profile.Scripts[id] then
			local g = Addon:PrepareGoblin(id, Addon.Options.profile.Scripts[id]);
			self[id] = g or false;
			if Addon.Options.profile.ScriptStates[id] ~= false then
				Addon:EnableGoblin(id);
			end
			return g;
		end
		return Empty;
	end,
});

--[[ ----------------------------  ADDON CODE  ---------------------------- ]]--
function Addon:OnInitialize()
	local AceDB = LibStub("AceDB-3.0");
	-- load config from acedb-savedvariables
	self.Options = AceDB:New("Greasegoblins", DefaultOptions, true);
	
	local O = self.Options.profile;
	if O._Version == false then
		O._Version = DBVERSION;
		if #O.Scripts == 0 then
			O.Scripts.Hello = DefaultScript;
		end
	end
end

function Addon:OnEnable()
	local i=1
	for id, rawcode in pairs(self.Options.profile.Scripts) do
		local _dummy = GoblinCache[id];
	end
end

---
-- Prepares a Goblin (script) with ID `id`
-- You probably don't want to call this externally.
function Addon:PrepareGoblin(id, rawcode)
	local Goblin = setmetatable({ Code = rawcode, Frame = CreateFrame("frame"),
		Metadata = {}, Events = {}}, GoblinMetatable);
	local isinit, tpl = false, "return function(self,...) %s\nend";
	for line in rawcode:gmatch("(.-)\r?\n") do
		local key, value = line:match("^%-%-%s*(.-)%s*:%s*(.-)%s*$");
		if key == "OnEvent" then
			Goblin.Events[#Goblin.Events+1] = value;
		elseif key == "OnLoad" and value == "true" then
			Addon:Queue(id, "LOAD");
		elseif key == "IsInit" and value == "true" then
			Addon:Queue(id, "LOAD");
			tpl = "%s";
		elseif key == "Enabled" and value ~= "true" then
			Goblin.Enabled = true;
		elseif key == nil then
			if not line:match("^%-%-") then
				break; -- only allow lines from the first block of uninterrupted comments
			end
		else
			Goblin.Metadata[key] = value; -- put any unknown k/v in .Metadata
		end
	end
	
	local f, err = loadstring(tpl:format(rawcode), id);
	if f then
		local d, f = xpcall(function() return f(Goblin) end, geterrorhandler());
		if d and f then
			Goblin.Function = f;
			Goblin.Frame:SetScript("OnEvent", function(self, ...)
				return Goblin:Function(...);
			end);
			return Goblin;
		end
	end
	
	if err then
		geterrorhandler()(err);
	end
	
	Goblin.Events = {};
	Goblin.Frame:UnregisterAllEvents();
	Goblin.Frame:SetScript("OnEvent", nil);
	Goblin.Frame:Hide();
end

function Addon:EnableGoblin(id)
	Addon.Options.profile.ScriptStates[id] = nil;
	local g = GoblinCache[id];
	if g then
		local e, f = g.Events, g.Frame;
		
		for i=1, #e do
			f:RegisterEvent(e[i]);
		end
		f:Show();
	end
end

function Addon:DisableGoblin(id)
	Addon.Options.profile.ScriptStates[id] = false;
	local g = GoblinCache[id];
	if g then
		g.Frame:UnregisterAllEvents();
		g.Frame:Hide();
	end
end

function Addon:IsGoblinEnabled(id)
	return Addon.Options.profile.ScriptStates[id] ~= false;
end

function Addon:RunGoblin(id, ...)
	local g = GoblinCache[id];
	if g then
		g.Function(g, ...);
	end
end

function Addon:UpdateGoblin(id, code)
	if id ~= "?" then
		local g = GoblinCache[id];
		if g then
			g.Frame:UnregisterAllEvents();
			g.Frame:Hide();
		end
		GoblinCache[id] = nil;
		Addon.Options.profile.Scripts[id] = code;
		local dummy = GoblinCache[id];
	end
end

function Addon:DeleteGoblin(id, ...)
	if id ~= "?" then
		GoblinCache[id] = nil;
		Addon.Options.profile.Scripts[id] = nil;
	end
end

local Queue, QueueWorker = {};
function Addon:Queue(id, ...)
	Queue[#Queue+1] = (function(...)
		local args = {...};
		return function()
			local g = GoblinCache[id];
			if g then g.Function(g, unpack(args)); end
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

local GoblinPrototype = {
	RegisterEvent = function(self, Event)
		self.Frame:RegisterEvent(Event);
	end,
	UnregisterEvent = function(self, Event)
		self.Frame:UnregisterEvent(Event);
	end,
	UnregisterAllEvents = function(self)
		self.Frame:UnregisterAllEvents();
	end,
}
GoblinMetatable = {
	__index = GoblinPrototype,
	__call = function(self, ...)
		return self:Function(...);
	end,
}
