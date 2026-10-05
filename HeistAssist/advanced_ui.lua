-- BeardLib owns input capture, cursor handling, scrolling and slider behavior.
if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local A = HeistAssist
dofile(ModPath .. "theme_colors.lua")
if not BeardLib or not MenuUI then error("BeardLib MenuUI is not available") end
if A.advanced_ui then
    if A.advanced_ui:Enabled() then A.advanced_ui:Disable()
    else A:refresh_advanced(); A.advanced_ui:Enable() end
    return
end
local blue = Color(0.96, 0.015, 0.035, 0.05)
local card = Color(1, 0.035, 0.11, 0.16)
local gold = Color(1, 0.05, 0.78, 1)
local white = Color(1, 0.91, 0.95, 1)
local muted = Color(1, 0.52, 0.67, 0.79)
local asset_name = "guis/textures/brandons_menu/"
if not A.art_registered then
    for _, name in ipairs({"backdrop_neutral_v13", "switches_theme_v13"}) do
        BeardLib.Managers.File:AddFile(Idstring("texture"), Idstring(asset_name .. name), ModPath .. "assets/" .. name .. ".texture")
    end
    A.art_registered = true
end
local ui = MenuUI:new({name = "BrandonsAdvancedMenu", layer = 100000, background_color = Color(0.25, 0, 0, 0),
    use_default_close_key = true, disable_player_controls = true, animate_toggle = true,
    font = tweak_data.menu.pd2_small_font, size = 32, font_size = 18, foreground = white,
    foreground_highlight = gold, highlight_color = Color(1, 0.12, 0.26, 0.39),
    help_background_color = card, help_color = white})
A.advanced_ui = ui
local original_disable=ui.Disable
function ui:Disable(...)
    A:save_settings()
    return original_disable(self,...)
end
local root = ui._panel
-- Keep the dashboard's proportions and input hitboxes together at 75% size.
local scale = 0.75
local ox, oy = root:w() * (1 - scale) / 2, root:h() * (1 - scale) / 2
local backdrop = root:bitmap({texture = asset_name .. "backdrop_neutral_v13", x = ox, y = oy,
    w = root:w() * scale, h = root:h() * scale, layer = 0})
local theme_nodes = {}
function A:apply_background()
    -- A gray/black saved color cannot show hue changes. Restore visible rainbow.
    if self.appearance.cycle then
        if self.appearance.saturation <= 0.02 then self.appearance.saturation = 1 end
        if self.appearance.brightness <= 0.02 then self.appearance.brightness = 1 end
    end
    local previous,previous_card=gold,card
    local c=self:hsv_color(self.appearance.hue,self.appearance.saturation,self.appearance.brightness)
    backdrop:set_color(c)
    gold=self:hsv_color(self.appearance.hue,self.appearance.saturation,math.max(0.35,self.appearance.brightness))
    card=Color(1,0.03+gold.red*0.09,0.03+gold.green*0.09,0.03+gold.blue*0.09)
    for _,entry in ipairs(theme_nodes) do if alive(entry[1]) then entry[1]:set_color(gold:with_alpha(entry[2])) end end
    local function recolor(menu)
        local cycling=menu:GetItem("cycle")
        if cycling then cycling:SetValue(self.appearance.cycle,false) end
        local hue=menu:GetItem("theme_hue")
        if hue and self.appearance.cycle then hue:SetValue(self.appearance.hue,false) end
        menu.foreground_highlight=gold; menu.highlight_color=card; menu.accent_color=gold
        for _,item in pairs(menu:Items() or {}) do
            if item.foreground==previous then item.foreground=gold end
            if item.background_color==previous_card then item.background_color=card end
            item.foreground_highlight=gold; item.highlight_color=card
            if item.DoHighlight then item:DoHighlight(item.highlighted) end
            if alive(item.pill) then item.pill:set_color(item.value and gold or Color.white) end
            if alive(item.toggle) then item.toggle:set_color(gold); item.toggle_value:set_color(gold) end
            if alive(item.sfg) then item.sfg:set_color(gold); item.sbg:set_color(gold:with_alpha(0.25)); item.circle:set_color(gold) end
            if alive(item.active_rail) then item.active_rail:set_color(gold) end
        end
    end
    for _,menu in ipairs(ui._menus) do recolor(menu) end
end
A:apply_background()
backdrop:animate(function(o)
    local repaint=0
    while alive(o) do
        local dt=math.max(0,tonumber(coroutine.yield()) or 0)
        if ui:Enabled() and A.appearance.cycle then
            A.appearance.hue=(A.appearance.hue+dt*360/A.appearance.seconds)%360
            repaint=repaint+dt
            if repaint>=0.05 then A:apply_background(); repaint=0 end
        end
    end
end)
local function scaled(params)
    params = clone(params)
    for _, key in ipairs({"w", "h", "size", "font_size", "border_size", "scroll_width", "text_shrink"}) do
        if type(params[key]) == "number" then params[key] = params[key] * scale end
    end
    return params
end
local original_menu = ui.Menu
function ui:Menu(params)
    local p = scaled(params)
    p.position = {ox + params.position[1] * scale, oy + params.position[2] * scale}
    local menu = original_menu(self, p)
    for _, method in ipairs({"Button", "Toggle", "Slider", "TextBox"}) do
        local original = menu[method]
        local control_type = method
        menu[method] = function(owner, options)
            if control_type == "Slider" and not options.size then options = clone(options); options.size = 28 end
            return original(owner, scaled(options))
        end
    end
    return menu
end
ui.size, ui.font_size = ui.size * scale, ui.font_size * scale
local w, h = root:w() - 28, root:h() - 24
local x, y = (root:w() - w) / 2, (root:h() - h) / 2
local shell = root:panel({x = ox + x * scale, y = oy + y * scale, w = w * scale, h = h * scale, layer = 1})
local function text(panel, content, xpos, ypos, width, size, color)
    local node=panel:text({text = content, x = xpos * scale, y = ypos * scale, w = width * scale, h = (size + 12) * scale,
        font = tweak_data.menu.pd2_small_font, font_size = size * scale, color = color or white, layer = 3})
    if color==gold then table.insert(theme_nodes,{node,1}) end
    return node
end
local nav_w, gap, top = 176, 12, 142
local center_x = nav_w + gap
local center_w = math.floor((w - nav_w - gap * 2) * 0.61)
local right_x, right_w = center_x + center_w + gap, w - center_x - center_w - gap
local function frame(px, py, pw, ph)
    local p = shell:panel({x = px * scale, y = py * scale, w = pw * scale, h = ph * scale, layer = 0})
    p:rect({color = blue})
    for _, spec in ipairs({{0,0,pw,1},{0,ph-1,pw,1},{0,0,1,ph},{pw-1,0,1,ph}}) do
        local node=p:rect({x=spec[1]*scale, y=spec[2]*scale, w=spec[3]*scale, h=spec[4]*scale, color=gold:with_alpha(0.45), layer=1})
        table.insert(theme_nodes,{node,0.45})
    end
    for _, corner in ipairs({{0,0},{pw-12,0},{0,ph-2},{pw-12,ph-2}}) do
        local node=p:rect({x=corner[1]*scale,y=corner[2]*scale,w=12*scale,h=2*scale,color=gold,layer=2})
        table.insert(theme_nodes,{node,1})
    end
    return p
end
frame(w - 254, 8, 254, 105)
text(shell, "PAYDAY 2  /  BRANDON", w - 240, 19, 235, 18, gold)
local session_text = text(shell, "", w - 240, 48, 235, 16, white)
text(shell, "F5 toggle   /   ESC close", w - 240, 77, 235, 14, muted)
frame(0, top, nav_w, h - top - 48)
frame(center_x, top, center_w, h - top - 48)
frame(right_x, top, right_w, h - top - 48)
shell:rect({y=(h-30)*scale, w=w*scale, h=30*scale, color=Color(0.97,0.005,0.014,0.02), layer=2})
local state_text = text(shell, "", 12, h - 27, w - 270, 14, muted)
local save_text = text(shell, "READY", w - 230, h - 27, 220, 14, gold)
local sidebar = ui:Menu({name = "navigation", position = {x + 8, y + top + 12}, w = nav_w - 16, h = h - top - 70,
    auto_height = false, auto_align = true, background_color = Color.transparent, size = 36, font_size = 18,
    foreground = muted, foreground_highlight = gold, highlight_color = card, layer = 10})
local search = ui:Menu({name = "search", position = {x + center_x + 12, y + top + 10}, w = center_w - 24, h = 34,
    auto_height = false, auto_align = true, background_color = card, layer = 10})
local content = ui:Menu({name = "content", position = {x + center_x + 12, y + top + 52}, w = center_w - 24, h = h - top - 116,
    auto_height = false, auto_align = true, background_color = Color.transparent, layer = 10,
    foreground = white, foreground_highlight = gold, highlight_color = card,
    size = 32, font = tweak_data.menu.pd2_small_font, font_size = 17, accent_color = gold})
local tools = ui:Menu({name = "tools", position = {x + right_x + 12, y + top + 12}, w = right_w - 24, h = h - top - 76,
    auto_height = false, auto_align = true, layer = 10, size = 34, font_size = 16,
    background_color = Color.transparent, foreground = white, foreground_highlight = gold, highlight_color = card})
local nav_items = {}
A.ui_page = "Player"
A.ui_search = ""
local groups = {
    {"Weapons", {{"unlimited_ammo", "Unlimited firearm ammo"}, {"no_recoil", "No recoil"},
        {"no_spread", "No spread"}, {"instant_weapon_swap", "Instant weapon swap"}, {"one_hit_kills", "High damage / one-hit kills"}}},
    {"Player", {{"god_mode", "God mode"}, {"unlimited_stamina", "Unlimited stamina"},
        {"instant_mask", "Instant mask"}, {"no_fall_damage", "No fall damage"}, {"no_movement_penalty", "No movement penalties"}}},
    {"Protection", {{"shock_proof", "Shock proof"}, {"flashbang_immunity", "Flashbang immunity"},
        {"concussion_immunity", "Concussion immunity"}}},
    {"Equipment", {{"unlimited_cable_ties", "Unlimited cable ties"}, {"unlimited_equipment", "Unlimited equipment"},
        {"instant_timers", "Finish drills / device timers"},
        {"instant_deployment", "Instant deployment"}, {"instant_interactions", "Instant interactions"},
        {"unlimited_sentry_ammo", "Unlimited sentry ammo"}, {"unlimited_sentry_health", "Unlimited sentry health"}}},
    {"Stealth", {{"undetectable", "Guards / cameras ignore you"}, {"keep_stealth", "Keep stealth: block alarms"}, {"unlimited_pagers", "Unlimited answered pagers"}, {"no_drill_jamming", "No drill jams"}}}
}
local host_features = {instant_timers = true, keep_stealth = true, undetectable = true, one_hit_kills = true, unlimited_equipment = true, instant_deployment = true,
    instant_interactions = true, unlimited_pagers = true, no_drill_jamming = true,
    unlimited_sentry_ammo = true, unlimited_sentry_health = true, unlimited_cable_ties = true}
local notes = {
    Weapons = "High damage depends on host authority and enemy damage caps.",
    Player = "God mode also blocks fall and taser damage; those switches overlap.",
    Protection = "Blocks ordinary player effects. Scripted effects can differ.",
    Equipment = "Use solo / host for shared equipment and sentry changes.",
    Stealth = "Solo / host. Block alarms before discoveries. NPCs can still react; scripts may bypass.",
    Movement = "Speed applies live. Multi-bag carry requires Carry Stacker Reloaded.",
    Presets = "Presets update live settings. Normal play turns all assists off."
    ,Appearance = "Every RGB color. White text stays readable; very dark accents get a visibility floor."
}
local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end
local function changed()
    local ok = A:save_settings()
    save_text:set_text(ok and "SETTINGS SAVED" or "SAVE FAILED - check log")
    for _, entry in ipairs({{tools,"quick_speed",A.config.speed_multiplier},{tools,"quick_bags",A.config.bag_limit},
        {content,"speed",A.config.speed_multiplier},{content,"bags",A.config.bag_limit}}) do
        local item = entry[1]:GetItem(entry[2])
        if item then item:SetValue(entry[3], false) end
    end
    A:update_advanced_status()
end
function A:update_advanced_status()
    local session = managers.network and managers.network:session()
    local role = not session and "MAIN MENU" or Network:is_server() and "SOLO / HOST" or "ONLINE CLIENT"
    session_text:set_text(role)
    local enabled = 0
    for _, value in pairs(self.config) do if value == true then enabled = enabled + 1 end end
    state_text:set_text(tostring(enabled) .. " assists ON   |   Damage " .. string.format("%.1fx", self.config.damage_multiplier) .. "   |   Speed " .. string.format("%.2fx", self.config.speed_multiplier) ..
        "   |   Bag cap " .. tostring(self.config.bag_limit))
end
function A:apply_preset(name)
    for key, value in pairs(self.config) do if type(value) == "boolean" then self.config[key] = false end end
    self.config.speed_multiplier, self.config.bag_limit = 1, 1
    self.config.damage_multiplier = 1
    local selected = name == "Stealth practice" and {"instant_mask", "instant_interactions", "unlimited_pagers", "unlimited_cable_ties"}
        or name == "Loud practice" and {"god_mode", "unlimited_ammo", "no_recoil", "no_spread", "unlimited_stamina"} or {}
    for _, key in ipairs(selected) do self.config[key] = true end
    changed()
    self:refresh_advanced()
end
local preset_path = SavePath .. "brandons_menu_preset.json"
function A:refresh_advanced()
    content:ClearItems()
    self:update_advanced_status()
    if tools:GetItem("quick_speed") then
        tools:GetItem("quick_speed"):SetValue(self.config.speed_multiplier, false)
        tools:GetItem("quick_bags"):SetValue(self.config.bag_limit, false)
    end
    for page, item in pairs(nav_items) do
        item.title:set_color(page == self.ui_page and gold or muted)
        item.bg:set_color(page == self.ui_page and card or Color.transparent)
        item.active_rail:set_visible(page == self.ui_page)
    end
    local note = notes[self.ui_page] or "Search across all feature categories."
    content:Button({name = "page_title", text = string.upper(self.ui_page), enabled = false,
        size = 27, font_size = 20, foreground = gold, disabled_alpha = 1})
    content:Button({name = "page_note", text = note, enabled = false, size = 40,
        font_size = 13, disabled_alpha = 1, foreground = muted, size_by_text = false})
    if self.ui_page == "Appearance" and self.ui_search == "" then
        local rainbow=content:Button({text="",enabled=false,disabled_alpha=1,size=18})
        for i=0,47 do
            rainbow.panel:rect({x=i*rainbow.panel:w()/48,w=rainbow.panel:w()/48+1,h=rainbow.panel:h(),
                color=self:hsv_color(i*360/48,1,1),layer=2})
        end
        content:Toggle({name="cycle",text="Automatically cycle the whole rainbow",value=self.appearance.cycle,
            on_callback=function(item)
                self.appearance.cycle=item:Value(); self:apply_background(); changed()
                ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
            end})
        content:Slider({text="Rainbow cycle (seconds)",min=5,max=120,step=1,floats=0,value=self.appearance.seconds,
            on_callback=function(item) self.appearance.seconds=item:Value(); changed() end})
        for _,entry in ipairs({{"hue","Hue",0,360,1},{"saturation","Saturation",0,1,0.01},{"brightness","Brightness",0,1,0.01}}) do
            local key=entry[1]
            content:Slider({name="theme_" .. key,text=entry[2],min=entry[3],max=entry[4],step=entry[5],floats=key=="hue" and 0 or 2,value=self.appearance[key],
                on_callback=function(item)
                    self.appearance[key]=item:Value(); self.appearance.cycle=false
                    if key=="hue" then
                        if self.appearance.saturation <= 0.02 then self.appearance.saturation=1 end
                        if self.appearance.brightness <= 0.02 then self.appearance.brightness=1 end
                        content:GetItem("theme_saturation"):SetValue(self.appearance.saturation,false)
                        content:GetItem("theme_brightness"):SetValue(self.appearance.brightness,false)
                    end
                    self:apply_background(); changed()
                end})
        end
        content:TextBox({text="Exact HEX (Enter)",value="#" .. self:theme_hex(),size=32,
            on_callback=function(item)
                if self:set_theme_hex(item:Value()) then self:apply_background(); changed()
                else save_text:set_text("HEX: USE 6 DIGITS") end
            end})
        content:Button({text="KEEP CURRENT COLOR / STOP CYCLING",foreground=gold,on_callback=function()
            self.appearance.cycle=false; self:apply_background(); changed()
            ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
        end})
        content:Button({text="RESET TO BLUE",foreground=gold,on_callback=function()
            self.appearance.hue=195; self.appearance.saturation=0.95; self.appearance.brightness=1; self.appearance.cycle=false
            self:apply_background(); changed(); ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
        end})
        content:Button({text="Saturation 0 = gray. Brightness 0 = black. Hue restores color from either.",size=40,
            font_size=13,foreground=muted,enabled=false,disabled_alpha=1})
        content:Button({text="SAVE COLOR TO FAVORITES (MAX 8)",on_callback=function()
            local hex=self:theme_hex()
            for _,value in ipairs(self.appearance.favorites) do if value==hex then save_text:set_text("COLOR ALREADY SAVED"); return end end
            if #self.appearance.favorites>=8 then save_text:set_text("8 FAVORITES: CLEAR FIRST"); return end
            table.insert(self.appearance.favorites,hex); changed()
            ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
        end})
        for _,value in ipairs(self.appearance.favorites) do
            local hex=value
            content:Button({text="APPLY FAVORITE  #" .. hex,on_callback=function()
                self:set_theme_hex(hex); self:apply_background(); changed()
                ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
            end})
        end
        content:Button({text="Clear saved colors",on_callback=function()
            self.appearance.favorites={}; changed(); ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
        end})
    elseif self.ui_search ~= "" or self.ui_page ~= "Movement" and self.ui_page ~= "Presets" then
        local matches = 0
        for _, group in ipairs(groups) do
            for _, entry in ipairs(group[2]) do
                local key, label = entry[1], entry[2]
                if (self.ui_search ~= "" and string.find(string.lower(label), self.ui_search, 1, true)) or
                    (self.ui_search == "" and self.ui_page == group[1]) then
                    matches = matches + 1
                    local item = content:Toggle({name = key, text = label, value = self.config[key], size = 34, font_size = 18,
                        help = host_features[key] and "Solo / hosting recommended. Other hosts control shared state." or
                            "Player-side feature. Online client compatibility is unverified.",
                        on_callback = function(item) self.config[key] = item:Value(); changed() end})
                    item.toggle:hide(); item.toggle_value:hide()
                    item.pill = item.panel:bitmap({texture = asset_name .. "switches_theme_v13", texture_rect = {self.config[key] and 256 or 0, 0, 256, 128},
                        w = 44*scale, h = 22*scale, layer = 8, x = item.panel:w() - 48*scale, y = 6*scale})
                    local start_x = item.panel:w() - 48*scale
                    item.knob = item.panel:bitmap({texture=asset_name .. "switches_theme_v13",texture_rect={512,0,128,128},
                        w=18*scale,h=18*scale,x=start_x+(self.config[key] and 24 or 2)*scale,y=8*scale,layer=9})
                    item.panel:rect({y=33*scale, h=1, w=item.panel:w(), color=gold:with_alpha(0.12), layer=2})
                    function item:UpdateToggle(value_changed)
                        if not alive(self.pill) then return end
                        self.pill:set_texture_rect(self.value and 256 or 0, 0, 256, 128)
                        self.pill:set_color(self.value and gold or Color.white)
                        if value_changed and alive(self.knob) then
                            self.knob:stop()
                            local from, target = self.knob:x(), start_x+(self.value and 24 or 2)*scale
                            self.knob:animate(function(o)
                                local elapsed=0
                                while elapsed < 0.13 do
                                    elapsed=elapsed+math.max(0,tonumber(coroutine.yield()) or 0)
                                    local t=math.min(1,elapsed/0.13)
                                    o:set_x(from+(target-from)*(1-(1-t)^3))
                                end
                                o:set_x(target)
                            end)
                        end
                    end
                end
            end
        end
        if matches == 0 then content:Button({text = "No matching features", enabled = false}) end
        if self.ui_page == "Weapons" and self.ui_search == "" then
            content:Button({text="GUN DAMAGE  /  SOLO OR HOST",size=30,font_size=15,foreground=gold,enabled=false,disabled_alpha=1})
            content:Slider({name="damage",text="Damage multiplier",min=1,max=20,step=0.5,floats=1,value=self.config.damage_multiplier,
                help="Adjusting this slider turns one-hit kills OFF. Enemy damage caps can still apply.",
                on_callback=function(item)
                    self.config.damage_multiplier=math.max(1,math.min(20,item:Value()))
                    self.config.one_hit_kills=false
                    content:GetItem("one_hit_kills"):SetValue(false,false)
                    changed()
                end})
            content:Button({text="1x = normal. Adjusting disables one-hit kills.",size=28,font_size=13,foreground=muted,enabled=false,disabled_alpha=1})
        end
    elseif self.ui_page == "Movement" then
        content:Slider({name = "speed", text = "Movement speed", min = 0.5, max = 5, step = 0.25,
            floats = 2, value = self.config.speed_multiplier,
            on_callback = function(item) self.config.speed_multiplier = math.max(0.5, math.min(5, item:Value())); changed() end})
        local stacker = _G.BLT_CarryStacker
        local ready = stacker and type(stacker.CanCarry) == "function" and stacker.stack
        content:Button({text = ready and "Carry Stacker: DETECTED" or "Carry Stacker: REQUIRED for multiple bags",
            enabled = false, enabled_alpha = 1, foreground = gold, font_size = 16})
        content:Slider({name = "bags", text = "Maximum carried bags", min = 1, max = 20, step = 1,
            floats = 0, value = self.config.bag_limit,
            help = "Solo / host. Lowering capacity never deletes carried bags.",
            on_callback = function(item) self.config.bag_limit = math.floor(math.max(1, math.min(20, item:Value()))); changed() end})
        content:Button({text = "Reset speed and bag capacity", on_callback = function()
            self.config.speed_multiplier, self.config.bag_limit = 1, 1
            changed(); ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
        end})
    else
        for _, name in ipairs({"Normal play", "Stealth practice", "Loud practice"}) do
            local preset_name = name
            content:Button({text = preset_name, on_callback = function()
                ui:RunCallbackNextUpdate(function() self:apply_preset(preset_name) end)
            end})
        end
        content:Button({text = "Save my custom preset", on_callback = function()
            local file = io.open(preset_path, "w")
            if file then file:write(json.encode(copy(self.config))); file:close(); save_text:set_text("CUSTOM PRESET SAVED")
            else save_text:set_text("PRESET SAVE FAILED") end
        end})
        content:Button({text = "Load my custom preset", on_callback = function()
            local file = io.open(preset_path, "r")
            if not file then save_text:set_text("NO CUSTOM PRESET YET"); return end
            local raw = file:read("*all"); file:close()
            local valid, preset = pcall(json.decode, raw)
            if not valid or type(preset) ~= "table" then save_text:set_text("INVALID PRESET"); return end
            for key, value in pairs(preset) do
                if type(value) == "boolean" and type(self.config[key]) == "boolean" then self.config[key] = value end
            end
            if type(preset.speed_multiplier) == "number" then self.config.speed_multiplier = math.max(0.5, math.min(5, preset.speed_multiplier)) end
            if type(preset.bag_limit) == "number" then self.config.bag_limit = math.floor(math.max(1, math.min(20, preset.bag_limit))) end
            self.config.damage_multiplier = type(preset.damage_multiplier) == "number" and math.max(1,math.min(20,preset.damage_multiplier)) or 1
            changed(); ui:RunCallbackNextUpdate(function() self:refresh_advanced() end)
        end})
    end
    content:AlignItems()
    self:apply_background()
end
search:TextBox({name = "search", text = "Search (Enter)", value = "", size = 30,
    font_size = 15, control_slice = 0.64,
    on_callback = function(item)
        A.ui_search = string.lower(tostring(item:Value() or ""))
        ui:RunCallbackNextUpdate(function() A:refresh_advanced() end)
    end})
for _, name in ipairs({"Weapons", "Player", "Protection", "Equipment", "Stealth", "Movement", "Presets", "Appearance"}) do
    local page = name
    nav_items[page] = sidebar:Button({name = page, text = string.upper(page) .. "   >", size = 36, font_size = 18, on_callback = function()
        A.ui_page = page; A.ui_search = ""
        search:GetItem("search"):SetValue("", false)
        ui:RunCallbackNextUpdate(function() A:refresh_advanced() end)
    end})
    nav_items[page].active_rail=nav_items[page].panel:rect({x=0,y=5*scale,w=2*scale,h=26*scale,color=gold,layer=5,visible=false})
end
sidebar:Button({text = "ALL ASSISTS OFF", size = 40, font_size = 15, foreground = gold,
    on_callback = function() ui:RunCallbackNextUpdate(function() A:apply_preset("Normal play") end) end})
sidebar:Button({text = "CLOSE  [ESC]", size = 36, font_size = 17, foreground = gold, on_callback = function() ui:Disable() end})
tools:Button({text = "QUICK PRESETS", size = 30, font_size = 20, enabled = false, disabled_alpha = 1, foreground = gold})
for _, name in ipairs({"Normal play", "Stealth practice", "Loud practice"}) do
    local preset = name
    tools:Button({text = preset, size = 34, background_color = card, on_callback = function()
        ui:RunCallbackNextUpdate(function() A:apply_preset(preset) end)
    end})
end
tools:Button({text = "LIVE MOVEMENT", size = 40, font_size = 20, enabled = false, disabled_alpha = 1, foreground = gold})
tools:Slider({name = "quick_speed", text = "Speed", min = 0.5, max = 5, step = 0.25, floats = 2, value = A.config.speed_multiplier,
    on_callback = function(item) A.config.speed_multiplier = item:Value(); changed() end})
tools:Slider({name = "quick_bags", text = "Bag limit", min = 1, max = 20, step = 1, floats = 0, value = A.config.bag_limit,
    on_callback = function(item) A.config.bag_limit = math.floor(item:Value()); changed() end})
tools:Button({text = "Bags need Carry Stacker.\nShared features need solo / host.", size = 54, font_size = 13,
    enabled = false, disabled_alpha = 1, foreground = muted})
tools:Button({text = "SAVE / LOAD CUSTOM PRESET  >", size = 38, font_size = 14, foreground = gold,
    on_callback = function()
        A.ui_page = "Presets"; A.ui_search = ""; search:GetItem("search"):SetValue("", false)
        ui:RunCallbackNextUpdate(function() A:refresh_advanced() end)
    end})
tools:AlignItems()
sidebar:AlignItems()
A:refresh_advanced()
ui:Enable()
