CleanMainMenu = CleanMainMenu or {
    mod_path = ModPath,
    options_path = ModPath .. "menu/options.txt",
    save_path = SavePath .. "CleanMainMenu.txt",
    loc_path = ModPath .. "menu/loc/",
    settings = {}
}

local default_settings = {
    hide_promotional_banner = true,
    hide_dlc_promo_text = true,
    hide_menu_option_description = true,
    hide_payday_logo = true,
    mod_manager_widget_mode = 3,
    hide_statistics = false,
    hide_announcements_feed = true,
    hide_build_version = true,
    hide_background_pattern = false,
    hide_smoke = false,
    hide_particles = false,
    hide_character = false
}

for key, value in pairs(default_settings) do
    if CleanMainMenu.settings[key] == nil then
        CleanMainMenu.settings[key] = value
    end
end

function CleanMainMenu:load_settings()
    local file = io.open(self.save_path, "r")

    if file then
        local data = json.decode(file:read("*all"))
        file:close()

        for key, value in pairs(data or {}) do
            if self.settings[key] ~= nil then
                self.settings[key] = value
            end
        end
    end
end

function CleanMainMenu:save_settings()
    local file = io.open(self.save_path, "w+")

    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

function CleanMainMenu:is_enabled(setting)
    return self.settings[setting] == true
end

local statistics_original_bottom

function CleanMainMenu:apply_statistics_layout(gui)
    if not gui or not alive(gui._panel) then
        return
    end

    gui._panel:set_visible(not self:is_enabled("hide_statistics"))

    if alive(gui._panel:parent()) then
        local parent = gui._panel:parent()

        if not statistics_original_bottom then
            statistics_original_bottom = gui._panel:bottom()
        end

        if self:is_enabled("hide_announcements_feed") then
            gui._panel:set_bottom(parent:h() - 10)
        else
            gui._panel:set_bottom(statistics_original_bottom)
        end
    end

    self:hide_profile_decorations(gui._panel)
end

function CleanMainMenu:hide_profile_decorations(gui)
    if not alive(gui) then
        return
    end

    local remove_children = {}

    for _, child in ipairs(gui:children() or {}) do
        local texture = child.texture and child:texture()

        if texture and (
            string.find(texture, "shared_skillpoint_symbol", 1, true) or
            string.find(texture, "crimenet_marker_glow", 1, true)
        ) then
            table.insert(remove_children, child)
        elseif child.children then
            self:hide_profile_decorations(child)
        end
    end

    for _, child in ipairs(remove_children) do
        if alive(child) then
            gui:remove(child)
        end
    end
end

local MAIN_MENU_SCENE_UNITS = {
    pattern = { "units/menu/menu_scene/menu_cylinder_pattern" },
    smoke = {
        "units/menu/menu_scene/menu_smokecylinder1",
        "units/menu/menu_scene/menu_smokecylinder2",
        "units/menu/menu_scene/menu_smokecylinder3"
    }
}

local function unit_name_key(unit)
    if not alive(unit) or not unit.name then
        return nil
    end

    local ok, id = pcall(function()
        return unit:name()
    end)

    if not ok or not id then
        return nil
    end

    return id.key and id:key() or nil
end

local function set_unit_enabled(unit, enabled)
    if not alive(unit) then
        return false
    end

    if unit.set_enabled then
        unit:set_enabled(enabled)
    elseif unit.set_visible then
        unit:set_visible(enabled)
    else
        return false
    end

    return true
end

function CleanMainMenu:refresh_main_menu_scene_units(scene)
    if not scene then
        return
    end

    local cache = scene._clean_main_menu_scene_units or {}
    scene._clean_main_menu_scene_units = cache

    local required_keys = {}
    for category, names in pairs(MAIN_MENU_SCENE_UNITS) do
        required_keys[category] = {}
        for _, name in ipairs(names) do
            required_keys[category][Idstring(name):key()] = true
        end
    end

    local needs_scan = false
    for category, keys in pairs(required_keys) do
        cache[category] = cache[category] or {}

        for key in pairs(keys) do
            local unit = cache[category][key]
            if not alive(unit) then
                needs_scan = true
                break
            end
        end
    end

    if not needs_scan then
        return
    end

    for _, unit in ipairs(World:find_units_quick("all") or {}) do
        local key = unit_name_key(unit)

        if key then
            for category, keys in pairs(required_keys) do
                if keys[key] then
                    cache[category][key] = unit
                end
            end
        end
    end
end

function CleanMainMenu:get_main_menu_money_spawner(scene)
    if not scene or not alive(scene._bg_unit) or not scene._bg_unit.effect_spawner then
        return nil
    end

    return scene._bg_unit:effect_spawner(Idstring("e_money"))
end

function CleanMainMenu:set_character_tree_visible(scene, visible)
    if not scene or not alive(scene._character_unit) then
        return
    end

    if scene._set_character_and_outfit_visibility then
        scene:_set_character_and_outfit_visibility(scene._character_unit, visible)

        if not visible then
            return
        end
    end

    local function set_tree(unit)
        if not alive(unit) then
            return
        end

        set_unit_enabled(unit, visible)

        if unit.children then
            for _, child_unit in ipairs(unit:children() or {}) do
                set_tree(child_unit)
            end
        end
    end

    set_tree(scene._character_unit)
end

function CleanMainMenu:apply_main_menu_scene_visibility(scene)
    if not scene or scene._current_scene_template ~= "standard" then
        return
    end

    self:refresh_main_menu_scene_units(scene)

    local cache = scene._clean_main_menu_scene_units or {}
    local hide_pattern = self:is_enabled("hide_background_pattern")
    local hide_smoke = self:is_enabled("hide_smoke")
    local hide_particles = self:is_enabled("hide_particles")
    local hide_character = self:is_enabled("hide_character")

    for _, unit in pairs(cache.pattern or {}) do
        set_unit_enabled(unit, not hide_pattern)
    end

    for _, unit in pairs(cache.smoke or {}) do
        set_unit_enabled(unit, not hide_smoke)
    end

    local money_spawner = self:get_main_menu_money_spawner(scene)
    if money_spawner and money_spawner.set_enabled then
        money_spawner:set_enabled(not hide_particles)
    end

    self:set_character_tree_visible(scene, not hide_character)
end

function CleanMainMenu:update_mod_manager_widget(gui)
    if not gui then
        return
    end

    local mode = tonumber(self.settings.mod_manager_widget_mode) or 1
    local has_notifications = (gui._notifications_count or 0) > 0
    local visible = mode == 2 or (mode == 3 and has_notifications)
    gui._enabled = visible

    for _, panel_name in ipairs({
        "_panel",
        "_content_panel",
        "_buttons_panel",
        "_downloads_panel",
        "_beardlib_panel",
        "_notification_panel",
        "_notification_button",
        "_button",
        "_badge"
    }) do
        local panel = gui[panel_name]
        if alive(panel) and panel.set_visible then
            panel:set_visible(visible)
        end
    end
end

function CleanMainMenu:refresh_runtime_state()
    local menu_component = managers and managers.menu_component

    if menu_component and menu_component._newsfeed_gui and alive(menu_component._newsfeed_gui._panel) then
        menu_component._newsfeed_gui._panel:set_visible(not self:is_enabled("hide_announcements_feed"))
    end

    self:update_mod_manager_widget(self._notification_gui)

    local active_menu = managers.menu and managers.menu:active_menu()
    local renderer = active_menu and active_menu.renderer
    local node_gui = renderer and renderer:active_node_gui()

    if node_gui and alive(node_gui._version_string) then
        node_gui._version_string:set_visible(not self:is_enabled("hide_build_version"))
    end

    if renderer and alive(renderer._bottom_text) and self:is_enabled("hide_menu_option_description") then
        renderer._bottom_text:set_text("")
    end

    if managers.menu_scene and alive(managers.menu_scene._menu_logo) then
        managers.menu_scene._menu_logo:set_visible(not self:is_enabled("hide_payday_logo"))
    end

    if menu_component and menu_component._player_profile_gui and alive(menu_component._player_profile_gui._panel) then
        self:apply_statistics_layout(menu_component._player_profile_gui)
    end

    if managers.menu_scene then
        self:apply_main_menu_scene_visibility(managers.menu_scene)
    end
end

CleanMainMenu:load_settings()

Hooks:Add("MenuManagerPostInitialize", "CleanMainMenu_InstallHooks", function()
    if CleanMainMenuHooksInstalled then
        return
    end

    CleanMainMenuHooksInstalled = true

    local original_get_latest_dlc_locked = MenuCallbackHandler.get_latest_dlc_locked

    function MenuCallbackHandler:get_latest_dlc_locked()
        if CleanMainMenu:is_enabled("hide_dlc_promo_text") then
            return false
        end

        return original_get_latest_dlc_locked and original_get_latest_dlc_locked(self) or false
    end

    Hooks:PostHook(MenuComponentManager, "create_new_heists_gui", "CleanMainMenu_HidePromotionalBanner", function(self)
        if CleanMainMenu:is_enabled("hide_promotional_banner") and self._new_heists_gui then
            self:close_new_heists_gui()
        end
    end)

    Hooks:PostHook(MenuComponentManager, "create_newsfeed_gui", "CleanMainMenu_HideAnnouncementsFeed", function(self)
        if CleanMainMenu:is_enabled("hide_announcements_feed") and self._newsfeed_gui then
            if alive(self._newsfeed_gui._panel) then
                self._newsfeed_gui._panel:set_visible(false)
            else
                self:close_newsfeed_gui()
            end
        end
    end)

    Hooks:PostHook(MenuNodeMainGui, "_add_version_string", "CleanMainMenu_HideBuildVersion", function(self)
        if CleanMainMenu:is_enabled("hide_build_version") and alive(self._version_string) then
            self._version_string:set_visible(false)
        end
    end)

    Hooks:PostHook(MenuRenderer, "set_bottom_text", "CleanMainMenu_HideOptionDescription", function(self)
        if CleanMainMenu:is_enabled("hide_menu_option_description") and alive(self._bottom_text) then
            self._bottom_text:set_text("")
        end
    end)

    Hooks:PostHook(MenuComponentManager, "create_player_profile_gui", "CleanMainMenu_HideStatistics", function(self)
        CleanMainMenu:apply_statistics_layout(self._player_profile_gui)
    end)

    Hooks:PostHook(MenuSceneManager, "set_scene_template", "CleanMainMenu_HideLogo", function(self)
        if alive(self._menu_logo) and CleanMainMenu:is_enabled("hide_payday_logo") then
            self._menu_logo:set_visible(false)
        end
    end)

    Hooks:PostHook(MenuSceneManager, "update", "CleanMainMenu_KeepLogoHidden", function(self)
        if CleanMainMenu:is_enabled("hide_payday_logo") and alive(self._menu_logo) and self._menu_logo:visible() then
            self._menu_logo:set_visible(false)
        end
    end)

    if BLTNotificationsGui then
        local function update_notifications_visibility(gui)
            CleanMainMenu._notification_gui = gui
            CleanMainMenu:update_mod_manager_widget(gui)
        end

        Hooks:PostHook(BLTNotificationsGui, "init", "CleanMainMenu_UpdateBLTNotifications", update_notifications_visibility)
        Hooks:PostHook(BLTNotificationsGui, "_setup", "CleanMainMenu_UpdateBLTNotificationPanels", update_notifications_visibility)
        Hooks:PostHook(BLTNotificationsGui, "update", "CleanMainMenu_KeepBLTNotificationsState", update_notifications_visibility)
    end

    if MenuSceneManager then
        Hooks:PostHook(MenuSceneManager, "_setup_bg", "CleanMainMenu_CaptureSceneUnits", function(self)
            self._clean_main_menu_scene_units = nil
            if self._current_scene_template == "standard" then
                CleanMainMenu:apply_main_menu_scene_visibility(self)
            end
        end)

        Hooks:PostHook(MenuSceneManager, "set_scene_template", "CleanMainMenu_ApplySceneVisibility", function(self)
            if self._current_scene_template == "standard" then
                CleanMainMenu:apply_main_menu_scene_visibility(self)
            end
        end)

        Hooks:PostHook(MenuSceneManager, "_chk_character_visibility", "CleanMainMenu_KeepCharacterHidden", function(self)
            if self._current_scene_template ~= "standard" then
                return
            end

            if CleanMainMenu:is_enabled("hide_character") then
                CleanMainMenu:set_character_tree_visible(self, false)
            else
                CleanMainMenu:set_character_tree_visible(self, true)
            end
        end)

        Hooks:PostHook(MenuSceneManager, "update", "CleanMainMenu_KeepSceneElementsHidden", function(self)
            if self._current_scene_template == "standard" then
                CleanMainMenu:apply_main_menu_scene_visibility(self)
            end
        end)
    end

    CleanMainMenu:refresh_runtime_state()
end)

Hooks:Add("LocalizationManagerPostInit", "CleanMainMenu_LoadLocalization", function(localization_manager)
    localization_manager:load_localization_file(CleanMainMenu.loc_path .. "english.txt")

    local current_language = SystemInfo:language():key()

    for _, filename in pairs(file.GetFiles(CleanMainMenu.loc_path) or {}) do
        local language_name = filename:match("^(.*)%.txt$")

        if language_name and Idstring(language_name):key() == current_language then
            localization_manager:load_localization_file(CleanMainMenu.loc_path .. filename)
            break
        end
    end
end)

Hooks:Add("MenuManagerInitialize", "CleanMainMenu_InitializeOptions", function()
    local toggle_settings = {
        hide_promotional_banner = "hide_promotional_banner",
        hide_dlc_promo_text = "hide_dlc_promo_text",
        hide_menu_option_description = "hide_menu_option_description",
        hide_statistics = "hide_statistics",
        hide_announcements_feed = "hide_announcements_feed",
        hide_build_version = "hide_build_version",
        hide_payday_logo = "hide_payday_logo",
        hide_character = "hide_character",
        hide_particles = "hide_particles",
        hide_smoke = "hide_smoke",
        hide_background_pattern = "hide_background_pattern"
    }

    local function resolve_toggle_setting(parameters)
        parameters = parameters or {}

        for _, field in ipairs({"value", "name", "id"}) do
            local candidate = parameters[field]

            if type(candidate) == "string" then
                candidate = candidate:gsub("^clean_main_menu_", "")

                if toggle_settings[candidate] then
                    return toggle_settings[candidate]
                end
            end
        end

        return nil
    end

    MenuCallbackHandler.callback_clean_main_menu_toggle = function(_, item)
        local setting = resolve_toggle_setting(item:parameters())

        if setting then
            CleanMainMenu.settings[setting] = item:value() == "on"
            CleanMainMenu:save_settings()
            CleanMainMenu:refresh_runtime_state()
        end
    end

    MenuCallbackHandler.callback_clean_main_menu_mod_manager_widget = function(_, item)
        CleanMainMenu.settings.mod_manager_widget_mode = tonumber(item:value()) or 1
        CleanMainMenu:save_settings()
        CleanMainMenu:refresh_runtime_state()
    end

    MenuCallbackHandler.callback_clean_main_menu_close = function()
    end

    MenuHelper:LoadFromJsonFile(CleanMainMenu.options_path, CleanMainMenu, CleanMainMenu.settings)
end)
