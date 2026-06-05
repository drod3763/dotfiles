hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos = {
    PaperWM = {
        url = "https://github.com/mogenson/PaperWM.spoon",
        desc = "PaperWM.spoon repository",
        branch = "release",
    }
}

ActiveSpace = hs.loadSpoon("ActiveSpace")
ActiveSpace:start()

-- use three finger swipe to focus nearby window
local current_id, threshold
Swipe = hs.loadSpoon("Swipe")
Swipe:start(3, function(direction, distance, id)
    if id == current_id then
        if distance > threshold then
            threshold = math.huge -- only trigger once per swipe

            -- use "natural" scrolling
            if direction == "left" then
                hs.window.focusedWindow():focusWindowEast()
            elseif direction == "right" then
                hs.window.focusedWindow():focusWindowWest()
            elseif direction == "up" then
                hs.window.focusedWindow():focusWindowSouth()
            elseif direction == "down" then
                hs.window.focusedWindow():focusWindowNorth()
            end
        end
    else
        current_id = id
        threshold = 0.2 -- swipe distance > 20% of trackpad
    end
end)

WarpMouse = hs.loadSpoon("WarpMouse")
WarpMouse.margin = 8  -- optionally set how far past a screen edge the mouse should warp, default is 2 pixels
WarpMouse:start()

spoon.SpoonInstall:andUse("PaperWM", {
    repo = "PaperWM",
    config = { screen_margin = 16, window_gap = 10, scroll_window = { "cmd", "alt", "shift", "ctrl" } },
    start = true,
    fn = function(pwm)
        local pip_title = "[Pp]icture[%- ]in[%- ]Picture"
        pwm.window_filter:setAppFilter("Zen", { rejectTitles = pip_title })

        local tiled_border_color = "0xffff4d4f"
        local floating_border_color = "0xff56b4e9"
        local unmanaged_border_color = "0xffcc79a7"

        local function update_border_color(window)
            if not window then
                return
            end

            local color = unmanaged_border_color
            if pwm.floating.isFloating(window) then
                color = floating_border_color
            elseif pwm.state.windowIndex(window) then
                color = tiled_border_color
            end
            hs.task.new("/opt/homebrew/bin/borders", nil, { "active_color=" .. color }):start()
        end

        hs.window.filter.default:subscribe(hs.window.filter.windowFocused, update_border_color)

        if pwm.floating and pwm.floating.toggleFloating then
            local original_toggle_floating = pwm.floating.toggleFloating
            pwm.floating.toggleFloating = function(window)
                original_toggle_floating(window)
                update_border_color(window or hs.window.focusedWindow())
            end
        end

        update_border_color(hs.window.focusedWindow())

        if pwm.windows and pwm.windows.addWindow then
            local original_add_window = pwm.windows.addWindow
            pwm.windows.addWindow = function(window)
                local ok, spaces = pcall(hs.spaces.windowSpaces, window)
                if (not ok) or (not spaces) or (not spaces[1]) then
                    return nil
                end
                return original_add_window(window)
            end
        end

        if pwm.events and pwm.events.scrollHandler then
            local function get_upvalue(fn, name)
                for i = 1, 32 do
                    local key, value = debug.getupvalue(fn, i)
                    if not key then
                        return nil
                    end
                    if key == name then
                        return value
                    end
                end
                return nil
            end

            local original_scroll_handler = pwm.events.scrollHandler
            local slide_windows = get_upvalue(original_scroll_handler, "slide_windows")
            if slide_windows then
                pwm.events.scrollHandler = function(self)
                    local ScrollWheel = hs.eventtap.event.types.scrollWheel
                    local ScrollWheelEventDelta = hs.eventtap.event.properties.scrollWheelEventDeltaAxis1
                    local FlagsChanged = hs.eventtap.event.types.flagsChanged
                    local Window = hs.window
                    local Screen = hs.screen
                    local Spaces = hs.spaces
                    local flags_watcher, scroll_coro = nil, nil

                    local function stop_scroll()
                        self.logger.d("scroll window stop")
                        if scroll_coro then
                            pcall(scroll_coro, nil)
                            scroll_coro = nil
                        end
                        if flags_watcher then
                            pcall(function()
                                flags_watcher:stop()
                            end)
                            flags_watcher = nil
                        end
                    end

                    return function(event)
                        local delete_event = false
                        if self.scroll_window and event:getType() == ScrollWheel
                            and event:getFlags():containExactly(self.scroll_window or {}) then
                            delete_event = true
                            if not scroll_coro then
                                self.logger.d("scroll window start")

                                local focused_window = Window.focusedWindow()
                                if not focused_window then
                                    self.logger.d("focused window not found")
                                    return delete_event
                                end

                                local focused_index = self.state.windowIndex(focused_window)
                                if not focused_index then
                                    self.logger.e("focused index not found")
                                    return delete_event
                                end

                                local screen = Screen(Spaces.spaceDisplay(focused_index.space))
                                if not screen then
                                    self.logger.e("no screen for space")
                                    return delete_event
                                end

                                scroll_coro = coroutine.wrap(slide_windows)
                                local ok, err = pcall(scroll_coro, self, focused_index.space, screen:frame())
                                if not ok then
                                    self.logger.ef("scroll init recovered from error: %s", tostring(err))
                                    scroll_coro = nil
                                    return delete_event
                                end
                            else
                                local ok, err = pcall(scroll_coro,
                                    event:getProperty(ScrollWheelEventDelta) * (self.scroll_gain or 1))
                                if not ok then
                                    self.logger.ef("scroll handler recovered from error: %s", tostring(err))
                                    stop_scroll()
                                end
                            end

                            if not flags_watcher then
                                flags_watcher = hs.eventtap.new({ FlagsChanged }, function(flags_event)
                                    if not flags_event:getFlags():contain(self.scroll_window or {}) then
                                        stop_scroll()
                                    end
                                    return false
                                end):start()
                            end
                        end
                        return delete_event
                    end
                end
            end
        end
    end,
    hotkeys = {
    -- switch to a new focused window in tiled grid
    focus_left  = {{"alt", "cmd"}, "left"},
    focus_right = {{"alt", "cmd"}, "right"},
    focus_up    = {{"alt", "cmd"}, "up"},
    focus_down  = {{"alt", "cmd"}, "down"},

    -- switch windows by cycling forward/backward
    -- (forward = down or right, backward = up or left)
    focus_prev = {{"alt", "cmd"}, "k"},
    focus_next = {{"alt", "cmd"}, "j"},

    -- move windows around in tiled grid
    swap_left  = {{"alt", "cmd", "shift"}, "left"},
    swap_right = {{"alt", "cmd", "shift"}, "right"},
    swap_up    = {{"alt", "cmd", "shift"}, "up"},
    swap_down  = {{"alt", "cmd", "shift"}, "down"},

    -- position and resize focused window
    center_window        = {{"alt", "cmd"}, "c"},
    full_width           = {{"alt", "cmd"}, "f"},
    cycle_width          = {{"alt", "cmd"}, "r"},
    reverse_cycle_width  = {{"ctrl", "alt", "cmd"}, "r"},
    cycle_height         = {{"alt", "cmd", "shift"}, "r"},
    reverse_cycle_height = {{"ctrl", "alt", "cmd", "shift"}, "r"},

    -- increase/decrease width
    increase_width = {{"alt", "cmd"}, "l"},
    decrease_width = {{"alt", "cmd"}, "h"},

    -- move focused window into / out of a column
    slurp_in = {{"alt", "cmd"}, "i"},
    barf_out = {{"alt", "cmd"}, "o"},

    -- move the focused window into / out of the tiling layer
    toggle_floating = {{"alt", "cmd", "shift"}, "escape"},

    -- focus the first / second / etc window in the current space
    focus_window_1 = {{"cmd", "shift"}, "1"},
    focus_window_2 = {{"cmd", "shift"}, "2"},
    focus_window_3 = {{"cmd", "shift"}, "3"},
    focus_window_4 = {{"cmd", "shift"}, "4"},
    focus_window_5 = {{"cmd", "shift"}, "5"},
    focus_window_6 = {{"cmd", "shift"}, "6"},
    focus_window_7 = {{"cmd", "shift"}, "7"},
    focus_window_8 = {{"cmd", "shift"}, "8"},
    focus_window_9 = {{"cmd", "shift"}, "9"},

    switch_space_1 = {{"alt", "cmd"}, "1"},
    switch_space_2 = {{"alt", "cmd"}, "2"},
    switch_space_3 = {{"alt", "cmd"}, "3"},
    switch_space_4 = {{"alt", "cmd"}, "4"},
    switch_space_5 = {{"alt", "cmd"}, "5"},
    switch_space_6 = {{"alt", "cmd"}, "6"},
    switch_space_7 = {{"alt", "cmd"}, "7"},
    switch_space_8 = {{"alt", "cmd"}, "8"},
    switch_space_9 = {{"alt", "cmd"}, "9"},

    -- move focused window to a new space and tile
    move_window_1 = {{"alt", "cmd", "shift"}, "1"},
    move_window_2 = {{"alt", "cmd", "shift"}, "2"},
    move_window_3 = {{"alt", "cmd", "shift"}, "3"},
    move_window_4 = {{"alt", "cmd", "shift"}, "4"},
    move_window_5 = {{"alt", "cmd", "shift"}, "5"},
    move_window_6 = {{"alt", "cmd", "shift"}, "6"},
    move_window_7 = {{"alt", "cmd", "shift"}, "7"},
    move_window_8 = {{"alt", "cmd", "shift"}, "8"},
    move_window_9 = {{"alt", "cmd", "shift"}, "9"}
    }
})
