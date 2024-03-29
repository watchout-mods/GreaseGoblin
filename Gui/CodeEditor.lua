local MAJOR, Addon = ...;

---
-- DISCLAIMER: I have no clue where I originally got this from. I know that I
-- (heavily) modified an existing widget, so I will take no credit for creating
-- it.
-- Though it is seriously buggy, so I intended from the start to write a new one
-- just lacking the time to do so...

local Type, Version = "CodeEditor", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

-- Lua APIs
local _G, pairs
    = _G, pairs

-- WoW APIs
local GetCursorInfo, GetSpellInfo, ClearCursor, CreateFrame, UIParent
    = GetCursorInfo, GetSpellInfo, ClearCursor, CreateFrame, UIParent;
local LuaTokenizer = LibStub("LuaTokenizer-1.0");
local Highlighter = {};
do
	local op = "|cFFE8E2B7";
	local token = {
		NUMBER = "|cffFFCD22", KEYWORD = "|cff93C763", ID       = "|cffe0e2e4",
		STRING = "|cffEC7600", COMMENT = "|cff66747B", GLOBALID = "|cffd33682",
		HEXNUM = "|cff268bd2", ERROR   = "|cffdc322f", MLSTRING = "|cffEC7600",
		["<="] = op, [">="] = op, ["=="] = op, ["~="] = op, [".."] = op,
		["--"] = op, ["..."] = op,
		["<"] = op, [">"] = op, ["="] = op, ["^"] = op, ["/"] = op, ["*"] = op,
		["+"] = op, ["-"] = op, ["%"] = op, ["#"] = op, ["-"] = op, [","] = op,
		["["] = op, ["]"] = op, ["("] = op, [")"] = op, ["{"] = op, ["}"] = op,
		[":"] = op, ["."] = op, [";"] = op
	};

	local function cb(t, V, LS, LE, CS, CE, ...)
		if t == "\t" then -- normalizes tabs
			return '    ';
		elseif t == "NEWLINE" then -- normalizes newlines
			return "\r\n";
		elseif token[t] then
			return ('%s%s|r'):format(token[t], V or t or "");
		end
		return V or t;
	end
	function Highlighter:Highlight(str)
		return table.concat(LuaTokenizer:Tokenize(str, cb));
	end

	function Highlighter:StripColors(str)
		return str:gsub("||","|!"):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|!","||");
	end
end

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: SAVE_CHANGES (="Save Changes"), ChatFontNormal

--[[----------------------------------------------------------------------------
Support functions
------------------------------------------------------------------------------]]

if not CodeEditorInsertLink then
	-- upgradeable hook
	hooksecurefunc("ChatEdit_InsertLink", function(...) return _G.CodeEditorInsertLink(...) end)
end

function _G.CodeEditorInsertLink(text)
	for i = 1, AceGUI:GetWidgetCount(Type) do
		local editbox = _G[("%s%uEdit"):format(Type, i)]
		if editbox and editbox:IsVisible() and editbox:HasFocus() then
			editbox:Insert(text:gsub("|", "||"))
			return true
		end
	end
end


local function Layout(self)
	self:SetHeight(self.numlines * 14 + (self.disablebutton and 19 or 41) + self.labelHeight)

	if self.labelHeight == 0 then
		self.scrollBar:SetPoint("TOP", self.frame, "TOP", 0, -23)
	else
		self.scrollBar:SetPoint("TOP", self.label, "BOTTOM", 0, -19)
	end

	if self.disablebutton then
		self.scrollBar:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 21)
		self.scrollBG:SetPoint("BOTTOMLEFT", 0, 4)
	else
		self.scrollBar:SetPoint("BOTTOM", self.button, "TOP", 0, 18)
		self.scrollBG:SetPoint("BOTTOMLEFT", self.button, "TOPLEFT")
	end
end

--[[----------------------------------------------------------------------------
Scripts
------------------------------------------------------------------------------]]
local function GetSelection(self)
	local T, C = self:GetText(), self:GetCursorPosition();
	local L = #T;
	
	-- create a token not found in the string
	local function gen() return "#"..tostring({}).."#"; end
	local token = gen();
	while T:find(token, 1, true) do token = gen(); end
	
	-- replace edit box content with token
	self:Insert(token);
	local NT = self:GetText();
	local NL = #NT;
	
	-- find the token
	local s = NT:find(token, 1, true)-1;
	
	-- length of selection
	local len = L-(NL-#token);
	
	-- reset box
	self:SetText(T);
	if len > 0 then
		self:HighlightText(s, s+len)
	end
	self:SetCursorPosition(C);
	return s, s+len;
end

local function HasSelection(self)
	local a, b = self:GetSelection();
	return (a ~= b)
end

local function OnTabPressed(self, ...)                                -- EditBox
	if false and IsControlKeyDown() then -- Debug
		local a,b = self:GetSelection();
		-- find start of first line in selection
		local t = self:GetText();
		
		return print(self:GetCursorPosition(), GetSelection(self));
	end
	local a,b = self:GetSelection();
	if a==b and not IsShiftKeyDown() then
		return self:Insert("    ");
	end
	local shift = IsShiftKeyDown();
	if a~=b then -- in/dedent all lines in selection
		
	else
		if IsShiftKeyDown() then -- Detab line
			local t, c = self:GetText(), self:GetCursorPosition();
			c = (t:find("\n", c+1) or (c+1))-1;
			t = t:sub(1, c);
			local pos, _, endpos = t:match("\n()(% % ?% ?% ?)()[^\n]*$");
			if pos then
				t = self:GetText();
				t = t:sub(1, pos-1) .. t:sub(endpos);
				self:SetText(t);
				-- find first non-whitespace character
				pos = t:match("()[^ ]", pos)-1;
				self:SetCursorPosition(min(pos, #t));
				
				-- Mark edit box as dirty
				local this = self.obj
				this:Fire("OnTextChanged", self:GetText())
				this.button:Enable()
			end
		end
	end
	
end

local function OnEnterPressed(self, ...)                              -- EditBox
	if IsControlKeyDown() then
		self.obj.button:Click();
	else
		local t = self:GetText();
		t = t:sub(1, self:GetCursorPosition());
		local pos, indent = t:match("\n()(% +)[^\n]*$");
		
		if indent then
			self:Insert("\n"..indent);
		else
			self:Insert("\n");
		end
	end
end

local function OnClick(self)                                           -- Button
	self = self.obj
	self.editBox:ClearFocus()
	if not self:Fire("OnEnterPressed", self:GetText()) then
		self.button:Disable()
	end
end

local function OnCursorChanged(self, x, y, _, cursorHeight)           -- EditBox
	self, y = self.obj.scrollFrame, -y
	local offset = self:GetVerticalScroll()
	if y < offset then
		self:SetVerticalScroll(y)
	else
		y = y + cursorHeight - self:GetHeight()
		if y > offset then
			self:SetVerticalScroll(y)
		end
	end
end

local function OnEditFocusLost(self)                                  -- EditBox
	self:HighlightText(0, 0)
	self.obj:Fire("OnEditFocusLost")
end

local function OnEnter(self)                            -- EditBox / ScrollFrame
	self = self.obj
	if not self.entered then
		self.entered = true
		self:Fire("OnEnter")
	end
end

local function OnLeave(self)                            -- EditBox / ScrollFrame
	self = self.obj
	if self.entered then
		self.entered = nil
		self:Fire("OnLeave")
	end
end

local function OnMouseUp(self)                                    -- ScrollFrame
	self = self.obj.editBox
	self:SetFocus()
	self:SetCursorPosition(self:GetNumLetters())
end

local function OnReceiveDrag(self)                      -- EditBox / ScrollFrame
	local type, id, info = GetCursorInfo()
	if type == "spell" then
		info = GetSpellInfo(id, info)
	elseif type ~= "item" then
		return
	end
	ClearCursor()
	self = self.obj
	local editBox = self.editBox
	if not editBox:HasFocus() then
		editBox:SetFocus()
		editBox:SetCursorPosition(editBox:GetNumLetters())
	end
	editBox:Insert(info)
	self.button:Enable()
end

local function OnSizeChanged(self, width, height)                 -- ScrollFrame
	self.obj.editBox:SetWidth(width)
end

local function OnTextChanged(self, userInput)                         -- EditBox
	--print(self:GetCursorPosition())
	if userInput then
		self = self.obj
		self:Fire("OnTextChanged", self:GetText())
		self.button:Enable()
	end
end

local function OnTextSet(self)                                        -- EditBox
	self:HighlightText(0, 0)
	self:SetCursorPosition(self:GetNumLetters())
	self:SetCursorPosition(0)
	self.obj.button:Disable()
end

local function OnVerticalScroll(self, offset)                     -- ScrollFrame
	local editBox = self.obj.editBox
	editBox:SetHitRectInsets(0, 0, offset, editBox:GetHeight() - offset - self:GetHeight())
end

local function OnShowFocus(frame)
	frame.obj.editBox:SetFocus()
	frame:SetScript("OnShow", nil)
end

local function OnEditFocusGained(frame)
	AceGUI:SetFocus(frame.obj)
	frame.obj:Fire("OnEditFocusGained")
end

--[[-----------------------------------------------------------------------------
Widget Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.editBox:SetText("")
		self:SetDisabled(false)
		self:SetWidth(200)
		self:DisableButton(false)
		self:SetNumLines()
		self.entered = nil
		self:SetMaxLetters(0)
	end,

	["OnRelease"] = function(self)
		self:ClearFocus()
	end,

	["SetDisabled"] = function(self, disabled)
		local editBox = self.editBox
		if disabled then
			editBox:ClearFocus()
			editBox:EnableMouse(false)
			editBox:SetTextColor(0.5, 0.5, 0.5)
			self.label:SetTextColor(0.5, 0.5, 0.5)
			self.scrollFrame:EnableMouse(false)
			self.button:Disable()
		else
			editBox:EnableMouse(true)
			editBox:SetTextColor(.9, .9, .9)
			self.label:SetTextColor(1, 0.82, 0)
			self.scrollFrame:EnableMouse(true)
		end
	end,

	["SetLabel"] = function(self, text)
		if text and text ~= "" then
			self.label:SetText(text)
			if self.labelHeight ~= 10 then
				self.labelHeight = 10
				self.label:Show()
			end
		elseif self.labelHeight ~= 0 then
			self.labelHeight = 0
			self.label:Hide()
		end
		Layout(self)
	end,

	["SetNumLines"] = function(self, value)
		if not value               then value = 4 end 
		if value > 0 and value < 4 then value = 4 end
		self.expand   = value < 0
		self.numlines = abs(value)
		Layout(self)
	end,

	["SetText"] = function(self, text)
		self.editBox:SetText(Highlighter:Highlight(text:gsub("|","||")))
	end,

	["GetText"] = function(self)
		return Highlighter:StripColors(self.editBox:GetText()):gsub("||","|")
	end,

	["SetRealText"] = function(self, text)
		self.editBox:SetText(text);
	end,

	["GetRealText"] = function(self)
		return self.editBox:GetText();
	end,

	["SetMaxLetters"] = function (self, num)
		self.editBox:SetMaxLetters(num or 0)
	end,

	["DisableButton"] = function(self, disabled)
		self.disablebutton = disabled
		if disabled then
			self.button:Hide()
		else
			self.button:Show()
		end
		Layout(self)
	end,
	
	["ClearFocus"] = function(self)
		self.editBox:ClearFocus()
		self.frame:SetScript("OnShow", nil)
	end,

	["SetFocus"] = function(self)
		self.editBox:SetFocus()
		if not self.frame:IsShown() then
			self.frame:SetScript("OnShow", OnShowFocus)
		end
	end,

	["GetCursorPosition"] = function(self)
		return self.editBox:GetCursorPosition()
	end,

	["SetCursorPosition"] = function(self, ...)
		return self.editBox:SetCursorPosition(...)
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local backdrop = {
	bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
	insets = { left = 4, right = 3, top = 4, bottom = 3 }
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()
	
	local widgetNum = AceGUI:GetNextWidgetNum(Type)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
	label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -4)
	label:SetJustifyH("LEFT")
	label:SetText(SAVE_CHANGES)
	label:SetHeight(10)

	local button = CreateFrame("Button", ("%s%dButton"):format(Type, widgetNum),
			frame, "UIPanelButtonTemplate" or "UIPanelButtonTemplate2")
	button:SetPoint("BOTTOMLEFT", 0, 4)
	button:SetHeight(22)
	button:SetWidth(label:GetStringWidth() + 24)
	button:SetText(SAVE_CHANGES)
	button:SetScript("OnClick", OnClick)
	button:Disable()
	
	local text = button:GetFontString()
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
	text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 1)
	text:SetJustifyV("MIDDLE")

	local scrollBG = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	scrollBG:SetBackdrop(backdrop)
	scrollBG:SetBackdropColor(0, 0, 0)
	scrollBG:SetBackdropBorderColor(0.4, 0.4, 0.4)

	local scrollFrame = CreateFrame("ScrollFrame", ("%s%dScrollFrame"):format(Type, widgetNum),
			frame, "UIPanelScrollFrameTemplate")

	local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("TOP", label, "BOTTOM", 0, -19)
	scrollBar:SetPoint("BOTTOM", button, "TOP", 0, 18)
	scrollBar:SetPoint("RIGHT", frame, "RIGHT")

	scrollBG:SetPoint("TOPRIGHT", scrollBar, "TOPLEFT", 0, 19)
	scrollBG:SetPoint("BOTTOMLEFT", button, "TOPLEFT")

	scrollFrame:SetPoint("TOPLEFT", scrollBG, "TOPLEFT", 5, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -4, 4)
	scrollFrame:SetScript("OnEnter", OnEnter)
	scrollFrame:SetScript("OnLeave", OnLeave)
	scrollFrame:SetScript("OnMouseUp", OnMouseUp)
	scrollFrame:SetScript("OnReceiveDrag", OnReceiveDrag)
	scrollFrame:SetScript("OnSizeChanged", OnSizeChanged)
	scrollFrame:HookScript("OnVerticalScroll", OnVerticalScroll)

	local editBox = CreateFrame("EditBox", ("%s%dEdit"):format(Type, widgetNum), scrollFrame)
	editBox:SetAllPoints()
	editBox:SetFont("Interface\\Addons\\GreaseGoblin\\UbuntuMono-R.ttf", 13, "")
	--editBox:SetFontObject(ChatFontNormal)
	--local fontPath = LibStub("LibSharedMedia-3.0"):Fetch("font", "Jack Input");
	--editBox:SetFont(fontPath, 13, "")
	editBox:SetMultiLine(true)
	editBox:EnableMouse(true)
	editBox:SetAutoFocus(false)
	editBox:SetCountInvisibleLetters(false)
	editBox:SetScript("OnCursorChanged", OnCursorChanged)
	editBox:SetScript("OnEditFocusLost", OnEditFocusLost)
	editBox:SetScript("OnEnter", OnEnter)
	editBox:SetScript("OnTabPressed", OnTabPressed)
	editBox:SetScript("OnEnterPressed", OnEnterPressed)
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	editBox:SetScript("OnLeave", OnLeave)
	editBox:SetScript("OnMouseDown", OnReceiveDrag)
	editBox:SetScript("OnReceiveDrag", OnReceiveDrag)
	editBox:SetScript("OnTextChanged", OnTextChanged)
	editBox:SetScript("OnTextSet", OnTextSet)
	editBox:SetScript("OnEditFocusGained", OnEditFocusGained)
	editBox.GetSelection = GetSelection;
	

	scrollFrame:SetScrollChild(editBox)

	local widget = {
		button      = button,
		editBox     = editBox,
		frame       = frame,
		label       = label,
		labelHeight = 10,
		numlines    = 4,
		scrollBar   = scrollBar,
		scrollBG    = scrollBG,
		scrollFrame = scrollFrame,
		type        = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	button.obj, editBox.obj, scrollFrame.obj = widget, widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
