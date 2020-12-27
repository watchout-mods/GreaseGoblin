---
-- Grease goblin.
-- Grease goblin is an add-on 
local MAJOR, Addon = ...;
local DBVERSION = 2;
LibStub("AceAddon-3.0"):NewAddon(Addon, MAJOR, "AceEvent-3.0");

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
print("Hello I'm your first grease goblin! Use /ggb to display the GUI!");
print("My arguments are:", ...);
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
-- Ace-Addon OnInitialize handler
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

-- Ace-Addon OnEnable handler
function Addon:OnEnable()
	local i=1
	for id, rawcode in pairs(self.Options.profile.Scripts) do
		local _dummy = GoblinCache[id];
	end
end

--
-- Prepares a Goblin (script) with name `id`.
-- You probably don't want to call this externally.
-- @param id The unique name of the Goblin to act on
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
		elseif key == "Prototype" and value == "true" then
			Addon:Queue(id, "LOAD");
			tpl = "%s";
		elseif key == "Enabled" and value ~= "true" then
			Goblin.Enabled = false;
		elseif key == nil then
			if not line:match("^%-%-") then
				break; -- only parse lines from the first block of uninterrupted comments
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
	
	-- This code is unreachable unless there was some error above
	if err then
		geterrorhandler()(err);
	end
	
	-- Clean up the Goblin
	Goblin.Events = {};
	Goblin.Frame:UnregisterAllEvents();
	Goblin.Frame:SetScript("OnEvent", nil);
	Goblin.Frame:Hide();
end

---
-- Enable a Goblin.
-- @param id The unique name of the Goblin to act on
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

---
-- Disable a Goblin.
-- @param id The unique name of the Goblin to act on
function Addon:DisableGoblin(id)
	Addon.Options.profile.ScriptStates[id] = false;
	local g = GoblinCache[id];
	if g then
		g.Frame:UnregisterAllEvents();
		g.Frame:Hide();
	end
end

---
-- Toggle the state of a Goblin.
-- @param id The unique name of the Goblin to act on
function Addon:ToggleGoblin(id)
	if Addon:IsGoblinEnabled(id) then
		Addon:DisableGoblin(id);
	else
		Addon:EnableGoblin(id);
	end
end

---
-- Return whether a Goblin is working.
-- @param id The unique name of the Goblin to investigate
function Addon:IsGoblinEnabled(id)
	return Addon.Options.profile.ScriptStates[id] ~= false;
end

---
-- Force a Goblin to work.
-- @param id  The unique name of the Goblin to kic... I mean encourage.
-- @param ... Additional arguments passed to the Goblin
function Addon:RunGoblin(id, ...)
	local g = GoblinCache[id];
	if g then
		g.Function(g, ...);
	end
end

---
-- Rename a Goblin. They need not get used to an actual identity.
-- @param from The name of the Goblin to act on
-- @param to   The new name of the Goblin
-- @return `true` if renaming was successful, false otherwise
function Addon:RenameGoblin(from, to)
	local s = Addon.Options.profile.Scripts
	if not s[to] then
		s[to] = Addon:GoblinOrders(from);
		GoblinCache[from], s[from] = nil, nil;
		return GoblinCache[to] and true
	else
		return false
	end
end

---
-- Get the orders of a Goblin.
-- @param id The name of the Goblin to investigate
-- @return The source code of the Goblin
function Addon:GoblinOrders(id)
	return Addon.Options.profile.Scripts[id or "?"];
end

---
-- Update the orders of a Goblin
-- @param id The name of the Goblin to act on
-- @param code The orders of a Goblin
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

---
-- Remove a Goblin
-- @param id The name of the Goblin to act on
function Addon:DeleteGoblin(id)
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

---
-- The prototype of a goblin
-- @name Goblin
-- @class table
-- @field Frame `UI-Object` The underlying WoW Frame widget. This frame is used
--   for running the Goblin from its OnEvent handler. Break it and you keep it.
-- @field Code `string` The source-code of the Goblin.
--   Informative / Not used.
-- @field Events `table` The events from the Metadata comment header.
--   Not used after initialisation.
-- @field Function `function` The function generated from the source-code.
-- @field Metadata `table` Contains all metadata from the comment header.
-- @field RegisterEvent `Method` Register this Goblin for an additional event.
-- @field UnregisterEvent `Method` Unregister this Goblin from an event.
-- @field UnregisterAllEvents `Method` Unregister this Goblin from all events.
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
