local MODULE, ADDON, Addon = "Options", ...;
local MAJOR = ADDON.."#"..MODULE;
local Module = Addon:NewModule(MODULE);

local function CreateOptionsTable()
	local L = Addon:GetLocale();
	
	local options = {
		type = "group",
		name = L.ADDONNAME,
		args = {
			new = {
				name = "New",
				type = "execute",
				order = 3,
				width = "half",
				func = function()
					local i = 1;
					local p = Addon.Options.profile.Scripts;
					while p["new "..i] do
						i = i+1;
					end
					p["new "..i] = "";
				end
			},
		}
	}
	
	for k,v in pairs(Addon.Options.profile.Scripts) do
		if k:match("^%w") then
			options.args["goblin_"..k] = {
				name = k,
				type = "group",
				args = {
					name = {
						name = L.NAME,
						type = "input",
						order = 1,
						width = "normal",
						arg = k,
						pattern = "^%w",
						usage = "Name must start with a letter",
						get = function(info) return k end,
						set = function(info, val)
							if val ~= info.arg then
								local S = Addon.Options.profile.Scripts;
								S[val] = S[info.arg];
								S[info.arg] = nil;
							end
						end,
						
					},
					toggle = {
						name = function(i)
							return Addon:IsGoblinEnabled(i.arg)and DISABLE or ENABLE;
						end,
						type = "execute",
						order = 2,
						width = "half",
						arg = k,
						func = function(info)
							if Addon:IsGoblinEnabled(info.arg) then
								Addon:DisableGoblin(info.arg);
							else
								Addon:EnableGoblin(info.arg);
							end
						end
					},
					delete = {
						name = "Delete",
						type = "execute",
						order = 3,
						width = "half",
						arg = k,
						func = function(info)
							Addon:DeleteGoblin(info.arg);
						end
					},
					exec = {
						name = "Execute",
						type = "execute",
						order = 4,
						width = "half",
						arg = k,
						func = function(info)
							Addon:RunGoblin(info.arg, "EXECUTE");
						end
					},
					code = {
						name = L.CODENAME,
						type = "input",
						order = 5,
						width = "full",
						multiline = -15,
						dialogControl = "CodeEditor",
						arg = k,
						get = function(info) return Addon.Options.profile.Scripts[info.arg] end,
						set = function(info, val) Addon:UpdateGoblin(info.arg, val) end,
					},
				},
			}
		end
	end

	
	return options;
end

function Module:OnInitialize()
	-- load config from acedb-savedvariable
	Config = LibStub("AceDB-3.0"):New("Greasegoblins", DefaultConfig, true);
	
	local AceConfig = LibStub("AceConfig-3.0");
	local AceConfigDialog = LibStub("AceConfigDialog-3.0");
	AceConfig:RegisterOptionsTable(ADDON, CreateOptionsTable);
	local optionstablecategory = AceConfigDialog:AddToBlizOptions(ADDON, nil, nil);
	
	SlashCmdList["GREASEGOBLIN"] = function(...)
		-- local Addon = select(select('#', ...), ...); -- Addon table
		LibStub("AceConfigDialog-3.0"):Open(ADDON);
	end;
	SLASH_GREASEGOBLIN1 = "/ggoblin";
	SLASH_GREASEGOBLIN2 = "/ggb";
end
