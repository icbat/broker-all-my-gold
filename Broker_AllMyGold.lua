------------------------------
--- Initialize Saved Variables
------------------------------

if icbat_bamg_character_map == nil then
    -- [{ qualified_char_name, money_in_copper }]
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

local function upsert_by_qualified_name(qualified_char_name, to_store)
    for i, stored_character in ipairs(icbat_bamg_character_map) do
        if stored_character["qualified_char_name"] == qualified_char_name then
            icbat_bamg_character_map[i] = to_store
            return
        end
    end

    table.insert(icbat_bamg_character_map, to_store)
end

local function update_cached_data(my_gold_in_copper)
    local include_server_name = true
    local my_qualified_char_name = get_my_qualified_name()
    local _localized_class_name, canonical_class_name = UnitClass("player")
    icbat_bamg_character_class_name[my_qualified_char_name] = canonical_class_name

    local to_store = {
        qualified_char_name = my_qualified_char_name,
        money_in_copper = my_gold_in_copper
    }

    upsert_by_qualified_name(my_qualified_char_name, to_store)
end

local function calculate_total_known_gold()
    local total = 0
    for _i, stored in ipairs(icbat_bamg_character_map) do
       total = total + stored["money_in_copper"]
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

    table.sort(icbat_bamg_character_map, function(a,b)
        if a["money_in_copper"] ~= b["money_in_copper"] then
            return a["money_in_copper"] > b["money_in_copper"]
        end

        return a["qualified_char_name"] < b["qualified_char_name"]
    end)

    for _i, stored in ipairs(icbat_bamg_character_map) do
        local qualified_char_name = stored["qualified_char_name"]
        local money_in_copper = stored["money_in_copper"]
        self:AddLine(Ambiguate(qualified_char_name, "all"), GetMoneyString(money_in_copper))
        color_first_col_by_class_name(self, qualified_char_name)
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

local function set_label(my_gold_in_copper)
    dataobj.text = GetMoneyString(my_gold_in_copper)
end

local function event_handler()
    local my_gold_in_copper = GetMoney() -- in copper
    set_label(my_gold_in_copper)
    update_cached_data(my_gold_in_copper)
end

-- invisible frame for updating/hooking events
local f = CreateFrame("frame")
-- on login
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("PLAYER_MONEY")
f:SetScript("OnEvent", event_handler)
