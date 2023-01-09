------------------------------
--- Initialize Saved Variables
------------------------------

if icbat_bamg_character_map == nil then
    -- holds full player name (slug + server) -> money in copper
    icbat_bamg_character_map = {}
end

if icbat_bamg_character_class_name == nil then
    -- char name -> class name
    icbat_bamg_character_class_name = {}
end

local function get_my_qualified_name()
    local name, realm = UnitFullName("player")
    local qualified_name = name .. "-" .. realm
    return qualified_name
end

local function update_cached_data(my_raw_gold)
    local include_server_name = true
    local my_full_name = get_my_qualified_name()
    local _localized_class_name, canonical_class_name = UnitClass("player")
    icbat_bamg_character_map[my_full_name] = my_raw_gold
    icbat_bamg_character_class_name[my_full_name] = canonical_class_name
end

local function calculate_total_known_gold()
    local total = 0
    for _, gold_in_copper in pairs(icbat_bamg_character_map) do
       total = total + gold_in_copper
    end
    return total
end

local function add_header(self)
    local colspan = 2
    self:AddLine()
    self:SetCell(1, 1, GetMoneyString(calculate_total_known_gold()), nil, "CENTER", colspan)
end

local function color_first_col_by_class_name(self, full_character_name)
    local class_name = icbat_bamg_character_class_name[full_character_name]
    if class_name ~= nil then
        local rgb = C_ClassColor.GetClassColor(class_name)
        self:SetCellTextColor(self:GetLineCount(), 1, rgb.r, rgb.g, rgb.b, 1)
    end
end


local function build_tooltip(self)
    add_header(self)
    self:AddSeparator()

    for full_character_name, gold in pairs(icbat_bamg_character_map) do
        self:AddLine(Ambiguate(full_character_name, "all"), GetMoneyString(gold))
        color_first_col_by_class_name(self, full_character_name)
    end
end

--------------------
--- Wiring/LDB/QTip
--------------------

local ADDON, namespace = ...
local LibQTip = LibStub('LibQTip-1.0')
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject(ADDON, {
    type = "data source",
    text = "Broker: All My Gold"
})

local function OnRelease(self)
    LibQTip:Release(self.tooltip)
    self.tooltip = nil
end

local function anchor_OnEnter(self)
    if self.tooltip then
        LibQTip:Release(self.tooltip)
        self.tooltip = nil
    end

    local tooltip = LibQTip:Acquire(ADDON, 2, "LEFT", "RIGHT")
    self.tooltip = tooltip
    tooltip.OnRelease = OnRelease
    tooltip.OnLeave = OnLeave
    tooltip:SetAutoHideDelay(.1, self)

    build_tooltip(tooltip)

    tooltip:SmartAnchorTo(self)

    tooltip:Show()
end

function dataobj:OnEnter()
    anchor_OnEnter(self)
end

--- Nothing to do. Needs to be defined for some display addons apparently
function dataobj:OnLeave()
end

local function set_label(my_gold_raw)
    dataobj.text = GetMoneyString(my_gold_raw)
end

local function event_handler()
    local my_gold_raw = GetMoney() -- in copper
    set_label(my_gold_raw)
    update_cached_data(my_gold_raw)
end

-- invisible frame for updating/hooking events
local f = CreateFrame("frame")
-- on login
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_MONEY")
f:SetScript("OnEvent", event_handler)
