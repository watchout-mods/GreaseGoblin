local MAJOR, Addon = ...;
local DBVERSION = 2;
LibStub("AceAddon-3.0"):NewAddon(Addon, MAJOR,
	"AceEvent-3.0"
);
_G.greasegoblin = Addon; -- debug
local pairs, tremove, max
    = pairs, tremove, max;

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
	},
};

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
	self.Options = AceDB:New("Greasegoblins", DefaultOptions, true);
	
	local O = self.Options.profile;
	if O._Version == false then
		O._Version = DBVERSION;
		if #O.Scripts == 0 then
			O.Scripts.Hello = [==[
-- OnLoad: true
print("Hello World!", ...);
]==]
		end
	end
end

function Addon:OnEnable()
	for id, rawcode in pairs(self.Options.profile.Scripts) do
		local _dummy = GoblinCache[id];
	end
end

---
-- Prepares a Goblin (script) with ID `id`
-- You probably don't want to call this externally.
function Addon:PrepareGoblin(id, rawcode)
	local Goblin = setmetatable({ Code = rawcode, Frame = CreateFrame("frame")},
		GoblinMetatable);
	local isinit, tpl = false, "return function(self, ...) %s end";
	for line in rawcode:gmatch("(.-)[\n\r]+") do
		local key, value = line:match("^%-%-%s*(.-)%s*:%s*(.-)%s*$");
		--print("match", key, value, "[END]");
		if key == "OnEvent" then
			Goblin.Frame:RegisterEvent(value);
		elseif key == "OnLoad" and value == "true" then
			Addon:Queue(id, "LOAD");
		elseif key == "IsInit" and value == "true" then
			Addon:Queue(id, "LOAD");
			tpl = "%s";
		elseif key == nil then
			break; -- only allow the first lines of the script for special comments
		else
			-- ignore unknown keys
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
	
	Goblin.Frame:UnregisterAllEvents();
	Goblin.Frame:SetScript("OnEvent");
	Goblin.Frame:Hide();
end

function Addon:RunGoblin(id, ...)
	GoblinCache[id].Function(GoblinCache[id], ...);
end

function Addon:UpdateGoblin(id, code)
	if id ~= "?" then
		GoblinCache[id].Frame:UnregisterAllEvents();
		GoblinCache[id].Frame:Hide();
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

local GoblinPrototype = {
	RegisterEvent = function(self, Event, Callback)
		local goblin = self;
		self.Frame:RegisterEvent(Event);
		if self.Frame:IsEventRegistered(Event) then
			self.EventHandlers[Event] = Callback;
			self.Frame:SetScript("OnEvent", function(self, e, ...)
				if goblin.EventHandlers[Event] then
					pcall(goblin.EventHandlers[Event])
				end
			end);
		end
	end,
	UnregisterEvent = function(self, Event)
		self.EventHandlers[Event] = nil;
		self.Frame:UnregisterEvent(Event);
	end,
	UnregisterAllEvents = function(self)
		self.EventHandlers = {};
		self.Frame:UnregisterAllEvents();
	end,
	
}
GoblinMetatable = {
	__index = GoblinPrototype,
	__call = function(self, ...)
		return self:Function(...);
	end,
}
