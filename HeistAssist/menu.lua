if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local A = HeistAssist
if BeardLib and MenuUI then
    local ok, message = pcall(dofile, ModPath .. "advanced_ui.lua")
    if ok then return end
    log("[HeistAssist] Advanced UI failed: " .. tostring(message))
    if A.advanced_ui then pcall(function() A.advanced_ui:Disable() end); A.advanced_ui = nil end
end
if not A.show_menu then
    A.menu_groups = {
        {name = "Player features - host usually not required", note = "Player-side hooks. Client behavior is unverified and can depend on the host.", items = {
            {"god_mode", "God mode"}, {"unlimited_ammo", "Unlimited firearm ammo"},
            {"no_recoil", "No camera recoil"}, {"no_spread", "No bullet spread"},
            {"unlimited_stamina", "Unlimited stamina"}, {"instant_mask", "Instant mask"},
            {"no_fall_damage", "No fall damage"}, {"no_movement_penalty", "No movement penalty"},
            {"shock_proof", "Shock proof"}, {"flashbang_immunity", "Flashbang immunity"},
            {"concussion_immunity", "Concussion immunity"}, {"instant_weapon_swap", "Instant weapon swap"}
        }},
        {name = "Solo / hosting - shared game features", note = "Host controls pagers, drills and sentries. Equipment and interactions can be rejected by another host.", items = {
            {"unlimited_cable_ties", "Unlimited cable ties"}, {"unlimited_equipment", "Unlimited equipment"},
            {"instant_deployment", "Instant deployment"}, {"instant_interactions", "Instant interactions"},
            {"undetectable", "Guards / cameras ignore you (host)"},
            {"keep_stealth", "Keep stealth: block alarms (host)"},
            {"instant_timers", "Finish drills / device timers (host)"},
            {"unlimited_pagers", "Unlimited answered pagers"}, {"no_drill_jamming", "No drill jamming"},
            {"one_hit_kills", "One-hit kills / high damage"}, {"unlimited_sentry_ammo", "Unlimited sentry ammo"},
            {"unlimited_sentry_health", "Unlimited sentry health"}
        }}
    }
    function A:role()
        local session = managers.network and managers.network:session()
        if not session then return "MAIN MENU / NO LOBBY" end
        return Network:is_server() and "SOLO / HOST" or "ONLINE CLIENT"
    end
    function A:show_menu(group_index, page)
        if not QuickMenu or not managers.system_menu then return end
        if self.dialog then self.dialog:hide() end
        local options = {}
        local description = "Session: " .. self:role() .. "\nChanges apply immediately and are saved. ESC closes."
        if group_index then
            local group = self.menu_groups[group_index]
            page = page or 1
            local per_page = 6
            local pages = math.ceil(#group.items / per_page)
            description = description .. "\n\n" .. group.name .. "\n" .. group.note .. "\nPage " .. page .. " / " .. pages
            for index = (page - 1) * per_page + 1, math.min(page * per_page, #group.items) do
                local item = group.items[index]
                local key, label = item[1], item[2]
                table.insert(options, {text = (self.config[key] and "[ON]  " or "[OFF] ") .. label,
                    callback = function()
                        self.config[key] = not self.config[key]
                        self:save_settings()
                        self:show_menu(group_index, page)
                    end})
            end
            if pages > 1 then
                table.insert(options, {text = "Next page", callback = function()
                    self:show_menu(group_index, page % pages + 1)
                end})
            end
            table.insert(options, {text = "Back to categories", callback = function() self:show_menu() end})
        else
            table.insert(options, {text = "Movement speed / bag capacity", callback = function() self:show_adjustments() end})
            for index, group in ipairs(self.menu_groups) do
                local group_id = index
                table.insert(options, {text = group.name, callback = function() self:show_menu(group_id, 1) end})
            end
            table.insert(options, {text = "Turn ALL features OFF", callback = function()
                for key, value in pairs(self.config) do
                    if type(value) == "boolean" then self.config[key] = false end
                end
                self.config.speed_multiplier = 1
                self.config.bag_limit = 1
                self.config.damage_multiplier = 1
                self:save_settings()
                self:show_menu()
            end})
            table.insert(options, {text = "Turn ALL features ON", callback = function()
                for key, value in pairs(self.config) do
                    if type(value) == "boolean" then self.config[key] = true end
                end
                self:save_settings()
                self:show_menu()
            end})
            description = description .. "\n\nGod mode also blocks fall and taser damage.\nTurn it off to test those individual switches."
        end
        table.insert(options, {text = "Close", is_cancel_button = true})
        self.dialog = QuickMenu:new("Brandon's New Menu", description, options, true)
    end
end
function A:show_adjustments()
    if self.dialog then self.dialog:hide() end
    local stacker = _G.BLT_CarryStacker
    local ready = stacker and stacker.stack and type(stacker.CanCarry) == "function"
    local status = ready and "Carry Stacker detected. Bag limit applies while solo / hosting." or
        "Bag capacity requires Carry Stacker Reloaded (not installed / not loaded)."
    local count = ready and #stacker.stack or 0
    local text = "Speed: " .. string.format("%.2fx", self.config.speed_multiplier) ..
        "   |   Bag limit: " .. tostring(self.config.bag_limit) .. "\nBags carried: " .. count ..
        "\n\n" .. status .. "\nReducing capacity never deletes carried bags. Drop extras normally."
    local function change(key, step, minimum, maximum)
        self.config[key] = math.max(minimum, math.min(maximum, self.config[key] + step))
        self:save_settings()
        self:show_adjustments()
    end
    self.dialog = QuickMenu:new("Brandon's New Menu - Speed / Bags", text, {
        {text = "Speed +0.25x", callback = function() change("speed_multiplier", 0.25, 0.5, 5) end},
        {text = "Gun damage +0.5x (host)", callback = function() change("damage_multiplier", 0.5, 1, 20) end},
        {text = "Gun damage -0.5x (host)", callback = function() change("damage_multiplier", -0.5, 1, 20) end},
        {text = "Speed -0.25x", callback = function() change("speed_multiplier", -0.25, 0.5, 5) end},
        {text = "Carry one more bag", callback = function() change("bag_limit", 1, 1, 20) end},
        {text = "Carry one fewer bag", callback = function() change("bag_limit", -1, 1, 20) end},
        {text = "Reset: normal speed / one bag", callback = function()
            self.config.speed_multiplier = 1; self.config.bag_limit = 1
            self:save_settings(); self:show_adjustments()
        end},
        {text = "Back", callback = function() self:show_menu() end},
        {text = "Close", is_cancel_button = true}
    }, true)
end
if A.dialog and A.dialog.visible then A.dialog:hide() else A:show_menu() end
