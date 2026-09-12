local function install_clean_main_menu_hooks()
    if CleanMainMenuHooksInstalled then
        return
    end

    CleanMainMenuHooksInstalled = true

    function MenuCallbackHandler:get_latest_dlc_locked()
        return false
    end

    function MenuComponentManager:create_new_heists_gui()
        return
    end

    function MenuComponentManager:create_newsfeed_gui()
        return
    end

    function MenuNodeMainGui:_add_version_string()
        return
    end

    function MenuRenderer:set_bottom_text()
        return
    end

    Hooks:PostHook(MenuComponentManager, "create_player_profile_gui", "CleanMainMenu_MoveProfilePanel", function(self)
        local EDGE_PADDING = 16

        if self._player_profile_gui and alive(self._player_profile_gui._panel) then
            local parent = self._player_profile_gui._panel:parent()
            self._player_profile_gui._panel:set_left(EDGE_PADDING)
            self._player_profile_gui._panel:set_bottom(parent:h() - EDGE_PADDING)
        end
    end)

    Hooks:PostHook(MenuSceneManager, "set_scene_template", "CleanMainMenu_HideLogo", function(self, template)
        if template == "standard" and alive(self._menu_logo) then
            self._menu_logo:set_visible(false)
        end
    end)

    if BLTNotificationsGui then
        local function hide_notifications(gui)
            gui._enabled = false

            for _, panel_name in ipairs({
                "_panel",
                "_content_panel",
                "_buttons_panel",
                "_downloads_panel",
                "_beardlib_panel"
            }) do
                local panel = gui[panel_name]
                if alive(panel) then
                    panel:set_visible(false)
                end
            end
        end

        Hooks:PreHook(BLTNotificationsGui, "init", "CleanMainMenu_HideBLTNotifications", hide_notifications)
        Hooks:PreHook(BLTNotificationsGui, "_setup", "CleanMainMenu_HideBLTNotificationPanels", hide_notifications)
        Hooks:PostHook(BLTNotificationsGui, "init", "CleanMainMenu_HideBLTNotificationsAfterInit", hide_notifications)
        Hooks:PostHook(BLTNotificationsGui, "_setup", "CleanMainMenu_HideBLTPanelsAfterSetup", hide_notifications)
        Hooks:PostHook(BLTNotificationsGui, "update", "CleanMainMenu_KeepBLTNotificationsHidden", hide_notifications)
    end
end

Hooks:Add("MenuManagerPostInitialize", "CleanMainMenu_InstallHooks", install_clean_main_menu_hooks)
