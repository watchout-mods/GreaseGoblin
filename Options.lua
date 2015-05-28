local MODULE, ADDON, Addon = "Options", ...;
local MAJOR = ADDON.."#"..MODULE;
local Module = Addon:NewModule(MODULE);

local function Window( ... )
	local AceGUI, Selected, this, tree = LibStub("AceGUI-3.0"), nil, {}, {}
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
		local id = nil
		-- find id of entry, if possible
		for i=1, #tree do
			if Selected == tree[i].value then id = i; break end
		end
		Addon:DeleteGoblin(Selected)
		if id == #tree then
			this:Update(tree[#tree-1].value)
		elseif id > 2 and id < #tree then
			this:Update(tree[id+1].value)
		else
			this:Update()
		end
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

	this = {
		Create = function()
			-- TBI
		end,
		Update = function(self, selection)
			wipe(tree)
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
			elseif #tree > 0 then
				List:SelectByPath(1)
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
	SlashCmdList["GREASEGOBLIN"] = function(...)
		Window()
	end;
	SLASH_GREASEGOBLIN1 = "/ggoblin";
	SLASH_GREASEGOBLIN2 = "/ggb";
end
