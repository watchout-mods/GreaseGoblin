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

local function Window( ... )
	local AceGUI, Selected, this = LibStub("AceGUI-3.0"), nil, {}
	-- Create a container frame
	local f = AceGUI:Create("Frame")
	f:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
	end)
	f:SetTitle("Greasy Goblins")
	f:SetStatusText("Status Bar")
	f:SetLayout("Fill")

	-- Selection box
	local List = AceGUI:Create("TreeGroup")
	List:SetLayout("Flow")

	-- CONTROLS
	local controls = AceGUI:Create("SimpleGroup")
	controls:SetLayout("Flow")
	controls:SetFullWidth(true)

	local iName = AceGUI:Create("EditBox")
	iName:SetLabel("Goblin name")

	local bEnable = AceGUI:Create("Button")
	bEnable:SetWidth(90)
	bEnable:SetText("Enable")
	bEnable:SetCallback("OnClick", function(widget)
		if Selected then
			Addon:ToggleGoblin(Selected)
			this:Update()
		end
	end)

	local bDelete = AceGUI:Create("Button")
	bDelete:SetWidth(67)
	bDelete:SetText("Trash")
	bDelete:SetCallback("OnClick", function(widget)
		Addon:DeleteGoblin(Selected)
		this:Update()
	end)

	local bRun = AceGUI:Create("Button")
	bRun:SetWidth(67)
	bRun:SetText("Run")
	bRun:SetCallback("OnClick", function(widget)
		Addon:RunGoblin(Selected, "EXECUTE")
	end)

	controls:AddChild(iName)
	controls:AddChild(bEnable)
	controls:AddChild(bRun)
	controls:AddChild(bDelete)

	-- EDIT BOX
	local editbox = AceGUI:Create("CodeEditor")
	editbox:SetFullHeight(true)
	editbox:SetFullWidth(true)
	editbox:SetLabel("Source code")

	-- Logic: filling, etc.
	List:SetCallback("OnGroupSelected", function(obj, event, group, ...)
		print(obj, event, group, ...)
		if group then
			editbox:SetText(Addon.Options.profile.Scripts[group] or "")
			iName:SetText(group)
			bEnable:SetText(Addon:IsGoblinEnabled(group) and "Disable" or "Enable")
			Selected = group
		else -- selected the "new" entry
			local p, i = Addon.Options.profile.Scripts, 1;
			while p["new "..i] do i=i+1 end
			p["new "..i] = "";
			this:Update()
			List:SelectByValue("new "..i)
			Selected = "new "..i
		end
	end)
	editbox:SetCallback("OnEnterPressed", function(obj, event, text)
		Addon:UpdateGoblin(Selected, text)
		editbox:SetText(text)
	end)

	-- Assemble
	List:AddChild(controls)
	List:AddChild(editbox)
	f:AddChild(List)
	List:SelectByPath(1)

	this = {
		Create = function()
			-- body
		end,
		Update = function(self, selection)
			local tree = {}
			selection = selection or this:GetSelected()

			for k,v in pairs(Addon.Options.profile.Scripts) do
				tree[#tree+1] = { value=k, text=k }
			end
			table.sort(tree, function(a, b) return a.value < b.value end)
			table.insert(tree,1,{value=false,text="New",icon="Interface\\Icons\\Spell_ChargePositive"})
			table.insert(tree,2,{value=false,text="",disabled=true})
			-- body
			List:SetTree(tree)
			if selection then
				List:SelectByValue(selection)
			end
		end,
		GetSelected = function()
			return Selected
		end,
		Select = function(self, which)
			List:SelectByValue(which)
		end,
	}
	this:Update()
	return this
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
		Window()
	end;
	SLASH_GREASEGOBLIN1 = "/ggoblin";
	SLASH_GREASEGOBLIN2 = "/ggb";
end
