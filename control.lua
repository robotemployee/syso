--control.lua

-- NOTE: Silently announces AFK status to people who are AFK. Active players will hear the sounds... all players will hear panic pause alerts.

script.on_init(function()
    storage.syso = {afk_players = {}, is_world_afk = false}
end
)

-- okay, i am returning to this now and it seems to have been written before i realized that non-strictly-typed code NEEDS COMMENTS EVERYWHERE
-- like i a
-- forgot what i was gonna say. whatever
-- anyways, for future reference:

-- storage.syso.afk_players:
-- key is the player index, value is a boolean of whether they're afk
-- if they're not afk, it is nil.
-- man i wish i encapsulated ts

function update_world_afk()
    for k,v in pairs(game.connected_players) do
        if not storage.syso.afk_players[v.index] then
            if storage.syso.is_world_afk then
                game.print({"syso.world-unafk"})
                storage.syso.is_world_afk = false
                if game.tick_paused then unpause() end
            end
            return
        end

    end

    storage.syso.is_world_afk = true
    game.print({"syso.world-afk"}, {sound = defines.print_sound.never})
end

---comment
---@param time integer
---@return boolean
function should_player_afk(time)
    return time > settings.global["syso-time-to-afk"].value * 60
end

---comment
---@param time integer
---@return boolean
function should_player_overtime_afk(time)
    return time > settings.global["syso-max-world-afk-time"].value * 60
end

---comment
---@param player_index integer
---@return unknown
function can_player_unpause(player_index)
    -- why game.is_multiplayer????
    return game.is_multiplayer() or settings.global["syso-can-anyone-unpause"].value or game.get_player(event.player_index).admin
end

function pause()
    --game.tick_paused = true
end

function unpause()
    --[[for k,v in pairs(game.connected_players) do
        v.remove_alert({message = v.request_translation({"syso-afk-panic"})}) -- this capital S Sucks
    end]]--
    game.tick_paused = false
end

-- Note that it will run for 3 more seconds before actually pausing. This is a horrible way to allow a buffer for you to move after unpausing.
function panic_pause(victim)
    local identifier = victim.is_player() and victim.name or victim.gps_tag
    game.print({"syso.afk-panic", identifier}, {sound_path = "utility/alert_destroyed"})
    game.print({"syso.how-to-resume"})
    for k,v in pairs(game.connected_players) do
        --v.add_custom_alert(victim, {type = "virtual", name = "signal-deny"}, {"syso-afk-panic"}, true)
        create_panic_prompt(v.index, victim)
    end
    -- if 
    if settings.global["syso-should-save-on-world-afk"].value then game.auto_save("afk") end
    pause()
end

-- Reconsider everyone who's AFK every half-second. This is trash
script.on_nth_tick(30, function(event)
    for k,v in pairs(storage.syso.afk_players) do
        local player = game.get_player(k)
        if not (player.connected and should_player_afk(player.afk_time)) then
            storage.syso.afk_players[k] = nil
            update_world_afk()
        end
    end
end
)

-- Check whether anyone should start to be considered AFK every minute.
script.on_nth_tick(180, function(event)
    if storage.syso.is_world_afk and not game.tick_paused then
        local unfortunate_soul_index
        for k,v in pairs(game.connected_players) do
            unfortunate_soul_index = v.index
            if not should_player_overtime_afk(v.afk_time) then return end
        end
            local characters = game.get_player(unfortunate_soul_index).get_associated_characters()
            for k,v in pairs(characters) do
                game.print("found character at ".. v.gps_tag)
                return
            end
            --panic_pause(game.get_player(unfortunate_soul_index).get_associated_characters()[0])
        return
    end

    for k,v in pairs(game.connected_players) do
        -- if they're not considered afk but should be considered afk...
        if (not storage.syso.afk_players[v.index]) and should_player_afk(v.afk_time) then
            -- if it's multiplayer, announce the person's afk status in the chat
            -- don't play a sound for the player themself (they know what they are), but play a sound for the uhhh other people. like any other console message
            if game.is_multiplayer() then
                -- No sound for the person who is AFK (they're doing something else), but sound for others for consistency
                v.print({"syso.player-now-afk", v.name}, {sound = defines.print_sound.never})
                for a,b in pairs(game.connected_players) do
                    if b.index ~= v.index then b.print({"syso.player-now-afk", v.name}) end
                end
            end
            storage.syso.afk_players[v.index] = true
            update_world_afk()
        end
    end
end
)

-- For the basic functionality we don't actually have to count AFK status for every player, but I wanted to make it be announced to the server in multiplayer.

-- Update the list of players considered AFK when they move
--[[
script.on_event(defines.events.on_player_changed_position, function(event)
    if  should_player_afk(game.get_player(event.player_index).afk_time) and storage.syso.afk_players[event.player_index] == true then
        storage.syso.afk_players[event.player_index] = nil
        update_world_afk()
    end
end
)
]]--

-- Runs when something important dies
script.on_event(defines.events.on_entity_died, function(event)
    if true or (storage.syso.is_world_afk and not game.tick_paused) then panic_pause(event.entity) end
end,
    {
        {filter = "name", name = "character"}, {filter = "crafting-machine"}, {filter = "turret"}, 
        {filter = "rail"}, {filter = "vehicle"}, {filter = "rolling-stock"}, {filter = "circuit-network-connectable"}
    }
)
--[[,
    {
        {filter = "name", name = "character"}, {filter = "crafting-machine"}, {filter = "turret"}, 
        {filter = "rail"}, {filter = "vehicle"}, {filter = "rolling-stock"}, {filter = "circuit-network-connectable"}
    }]]--

script.on_event(defines.events.on_entity_damaged, function(event)
    if true or (storage.syso.is_world_afk and not game.tick_paused) then panic_pause(event.entity) end
end,
    {{filter = "name", name = "character"}}
)

-- Removes players from the list of AFKs when they leave
script.on_event(defines.events.on_player_left_game, function(event)
    if storage.syso.afk_players[event.player_index] == true then
        storage.syso.afk_players[event.player_index] = nil
        update_world_afk()
    end
end
)

function create_panic_prompt(player_index, victim)
    local player = game.get_player(player_index)
    if player.gui.screen.syso_panic_pause then return end

    local screen_element = player.gui.screen
    local main_frame = screen_element.add{type="frame", name="syso_panic_pause", caption={"?",{"syso.autopaused"},{"multiplayer.game-paused", victim.name}}}
    --main_frame.auto_center = true

    local content_frame = main_frame.add{type="frame", name="content_frame", direction="vertical", style="entity_frame"}
    local controls_flow = content_frame.add{type="flow", name="controls_flow", direction="vertical", style="padded_vertical_flow"}

    local label = controls_flow.add{type="label", name="label", caption="Sorry You Spaced Out"}
    local minimap = controls_flow.add{type="minimap", name="minimap", position=victim.position, surface_index=victim.surface_index}
    minimap.style.size = {320,320}
    --local minimap_controls_flow = controls_flow.add{type="flow", name="controls_flow", direction="horizontal", style="padded_horizontal_flow"}
    local gps_label = controls_flow.add{type="label", name="gps_label", caption=victim.gps_tag}
    gps_label.style.rich_text_setting = defines.rich_text_setting.highlight
    gps_label.style.font="default-game"
    local gps_button = controls_flow.add{type="button", name="syso_show",caption={"?",{"syso.show"},"Take me there"}}
    
    -- in the event that something died, we have to add functionality to the "take me there" option
    if victim.health == 0 then
        local remnant = find_corpse(player.surface, victim.position, victim.prototype.corpses)
        minimap.entity = remnant
    else
        minimap.entity = victim
    end


    generate_unpause_button(player_index, controls_flow)
end

function find_corpse(surface, position, corpses)
    for k,_ in pairs(corpses) do
        game.print(k)
        local found = surface.find_entity(k, position)
        if found then return found end
    end
    return nil
end

function generate_unpause_button(player_index, controls_flow)
    if controls_flow.syso_unpause then controls_flow.syso_unpause.destroy() end
    local unpause_button = controls_flow.add{type="button", name="syso_unpause", caption={"gui-menu.unpause-game"}, style="menu_button"}
    if not can_player_unpause(player_index) then
        -- disable the button if they can't unpause
        unpause_button.tooltip = {"syso.deny-unpause"}
        unpause_button.enabled = false
    end
end

-- TODO https://lua-api.factorio.com/latest/concepts/LocalisedString.html

script.on_event(defines.events.on_gui_click, function(event)
    if event.element.name == "syso_unpause" then
        storage.syso.afk_players[event.player_index] = nil 
        -- the player is no longer AFK, but the world is not unpaused
        -- only continue if the player is allowed to unpause the world
        -- NOTE players who can't unpause the world should not be able to see the button anyway
        if not can_player_unpause(event.player_index) then return end

        -- mark the world as no longer AFK
        game.print({"multiplayer.player-resumed-game", game.get_player(event.player_index).name})
        for k,v in pairs(game.connected_players) do
            v.gui.screen.syso_panic_pause.destroy()
        end
        update_world_afk()
        unpause()
    elseif event.element.name == "syso_show" then
        local player = game.get_player(event.player_index)
        local entity = player.gui.screen.syso_panic_pause.content_frame.controls_flow.minimap.entity
        --print(entity.valid)
        player.centered_on = entity -- all this just to avoid .5 seconds of using storage
    end
end
)

script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not player.gui.screen.syso_panic_pause then return end
    if storage.syso.is_world_afk then
        -- we do this in the event that a player was disallowed from unpausing since last join. they still won't be able to unpause, but at least now it's consistent
        generate_unpause_button(event.player_index, player.gui.screen.syso_panic_pause.content_frame.controls_flow)
    else
        player.gui.screen.syso_panic_pause.destroy()
    end
end
)

commands.add_command("tick-unpause", {"syso-commands.tick-unpause"}, function(command)
    -- mark the world as no longer AFK
    if command.player_index == nil or not can_player_unpause(event.player_index) then return end
    storage.syso.afk_players[command.player_index] = nil
    game.print({"syso.game-unpaused", game.get_player(event.player_index).name})
    update_world_afk()
    unpause()
end
)

commands.add_command("tick-pause", {"syso-commands.tick-pause"}, function(command)
    if command.player_index == nil then return end
    
    game.print({"syso.game-unpaused", game.get_player(event.player_index).name})
    pause()
end
)

commands.add_command("tick-advance", {"syso-commands.tick-advance"}, function(command)
    if command.player_index == nil then return end
    if game.tick_paused == false then
        game.get_player(command.player_index).print({"syso-commands.tick-advance-error-1"})
        return
    end
    game.ticks_to_run = math.min(1, tonumber(command.parameter or 1))
end
)