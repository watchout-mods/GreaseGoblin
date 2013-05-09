local MODULE, ADDON, Addon = "Localization", ...;
local MAJOR = ADDON.."#"..MODULE;
local Module = Addon:NewModule(MODULE);

local function CreateLocales()
local AL, L = LibStub("AceLocale-3.0");

L = AL:NewLocale(MAJOR, "enUS", true);
L.ADDONNAME = ADDON;
L.NAME = "Goblin name";
L.ADDONDESC = "Get those filthy grease goblins to work for you!";
L.EXECUTE = "Run now";
L.CODENAME = "Source code";

L = AL:NewLocale(MAJOR, "deDE");
if L then
L.ADDONNAME = ADDON;
L.NAME = "Goblinname";
L.ADDONDESC = "";
L.EXECUTE = "Jetzt ausführen";
L.CODENAME = "Quelltext";
end

end

function Addon:GetLocale()
	local AL = LibStub("AceLocale-3.0");
	if CreateLocales and not AL:GetLocale(MAJOR, true) then
		CreateLocales();
		CreateLocales = nil; -- save some memory
	end

	return AL:GetLocale(MAJOR);
end
