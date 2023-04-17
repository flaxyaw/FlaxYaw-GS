--[[
regionlist: -DEPENDENCIES
            -USER_DATA
            -REFERENCES
            -VARIABLES
            -FUNCS
            -UI_LAYOUT
            -AA_CALLBACKS
            -UI_RENDER
]]

-- @region DEPENDENCIES start
local function try_require(module, msg)
    local success, result = pcall(require, module)
    if success then return result else return error(msg) end
end

local images = try_require("gamesense/images", "Download images library: https://gamesense.pub/forums/viewtopic.php?id=22917")
local bit = try_require("bit")
local base64 = try_require("gamesense/base64", "Download base64 encode/decode library: https://gamesense.pub/forums/viewtopic.php?id=21619")
local antiaim_funcs = try_require("gamesense/antiaim_funcs", "Download anti-aim functions library: https://gamesense.pub/forums/viewtopic.php?id=29665")
local ffi = try_require("ffi", "Failed to require FFI, please make sure Allow unsafe scripts is enabled!")
local vector = try_require("vector", "Missing vector")
local http = try_require("gamesense/http", "Download HTTP library: https://gamesense.pub/forums/viewtopic.php?id=21619")
local clipboard = try_require("gamesense/clipboard", "Download Clipboard library: https://gamesense.pub/forums/viewtopic.php?id=28678")
local ent = try_require("gamesense/entity", "Download Entity Object library: https://gamesense.pub/forums/viewtopic.php?id=27529")
local csgo_weapons = try_require("gamesense/csgo_weapons", "Download CS:GO weapon data library: https://gamesense.pub/forums/viewtopic.php?id=18807")
-- @region DEPENDENCIES end

-- @region USERDATA start
local userdata = {
    username = username == nil and 'admin' or username,
    build = build ~= nil and build:gsub("debug", "dev"):gsub("beta", "alpha"):gsub("stable", "user") or "nightly"
}
local lua_color = {r = 119, g =30, b = 198}
local lua_name = "flaxyaw"
local lua = {}
lua.database = {
    configs = ":" .. lua_name .. "::configs:"
}
local presets = {}
-- @region USERDATA end

-- @region REFERENCES start
local refs = {
    legit = ui.reference("LEGIT", "Aimbot", "Enabled"),
    dmgOverride = {ui.reference("RAGE", "Aimbot", "Minimum damage override")},
    fakeDuck = ui.reference("RAGE", "Other", "Duck peek assist"),
    minDmg = ui.reference("RAGE", "Aimbot", "Minimum damage"),
    hitChance = ui.reference("RAGE", "Aimbot", "Minimum hit chance"),
    safePoint = ui.reference("RAGE", "Aimbot", "Force safe point"),
    forceBaim = ui.reference("RAGE", "Aimbot", "Force body aim"),
    dtLimit = ui.reference("RAGE", "Aimbot", "Double tap fake lag limit"),
    quickPeek = {ui.reference("RAGE", "Other", "Quick peek assist")},
    dt = {ui.reference("RAGE", "Aimbot", "Double tap")},
    enabled = ui.reference("AA", "Anti-aimbot angles", "Enabled"),
    pitch = {ui.reference("AA", "Anti-aimbot angles", "pitch")},
    roll = ui.reference("AA", "Anti-aimbot angles", "roll"),
    yawBase = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
    yaw = {ui.reference("AA", "Anti-aimbot angles", "Yaw")},
    flLimit = ui.reference("AA", "Fake lag", "Limit"),
    fsBodyYaw = ui.reference("AA", "anti-aimbot angles", "Freestanding body yaw"),
    edgeYaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
    yawJitter = {ui.reference("AA", "Anti-aimbot angles", "Yaw jitter")},
    bodyYaw = {ui.reference("AA", "Anti-aimbot angles", "Body yaw")},
    freeStand = {ui.reference("AA", "Anti-aimbot angles", "Freestanding")},
    os = {ui.reference("AA", "Other", "On shot anti-aim")},
    slow = {ui.reference("AA", "Other", "Slow motion")},
    fakeLag = {ui.reference("AA", "Fake lag", "Limit")},
    legMovement = ui.reference("AA", "Other", "Leg movement"),
    indicators = {ui.reference("VISUALS", "Other ESP", "Feature indicators")},
    ping = {ui.reference("MISC", "Miscellaneous", "Ping spike")},
}
-- @region REFERENCES end

-- @region VARIABLES start
local vars = {
    localPlayer = 0,
    hitgroup_names = { 'Generic', 'Head', 'Chest', 'Stomach', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Neck', '?', 'Gear' },
    aaStates = {"Standing", "Moving", "Slowwalking", "Crouching", "Air", "Air-Crouching", "Crouch-Moving"},
    pStates = {"S", "M", "SW", "C", "A", "AC", "CM"},
	sToInt = {["Standing"] = 1, ["Moving"] = 2, ["Slowwalking"] = 3, ["Crouching"] = 4, ["Air"] = 5, ["Air-Crouching"] = 6, ["Crouch-Moving"] = 7},
    intToS = {[1] = "Standing", [2] = "Moving", [3] = "Slowwalking", [4] = "Crouching", [5] = "Air", [6] = "Air+", [7] = "Crouch-Moving"},
    activeState = 1,
    pState = 1
}
-- @region VARIABLES end

-- #region FUNCS start
local func = {
    table_contains = function(tbl, value)
        for i = 1, #tbl do
            if tbl[i] == value then
                return true
            end
        end
        return false
    end,
    setAATab = function(ref)
        ui.set_visible(refs.enabled, ref)
        ui.set_visible(refs.pitch[1], ref)
        ui.set_visible(refs.pitch[2], ref)
        ui.set_visible(refs.roll, ref)
        ui.set_visible(refs.yawBase, ref)
        ui.set_visible(refs.yaw[1], ref)
        ui.set_visible(refs.yaw[2], ref)
        ui.set_visible(refs.yawJitter[1], ref)
        ui.set_visible(refs.yawJitter[2], ref)
        ui.set_visible(refs.bodyYaw[1], ref)
        ui.set_visible(refs.bodyYaw[2], ref)
        ui.set_visible(refs.freeStand[1], ref)
        ui.set_visible(refs.freeStand[2], ref)
        ui.set_visible(refs.fsBodyYaw, ref)
        ui.set_visible(refs.edgeYaw, ref)
    end,
    findDist = function (x1, y1, z1, x2, y2, z2)
        return math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
    end,
    resetAATab = function()
        ui.set(refs.enabled, false)
        ui.set(refs.pitch[1], "Off")
        ui.set(refs.pitch[2], 0)
        ui.set(refs.roll, 0)
        ui.set(refs.yawBase, "local view")
        ui.set(refs.yaw[1], "Off")
        ui.set(refs.yaw[2], 0)
        ui.set(refs.yawJitter[1], "Off")
        ui.set(refs.yawJitter[2], 0)
        ui.set(refs.bodyYaw[1], "Off")
        ui.set(refs.bodyYaw[2], 0)
        ui.set(refs.freeStand[1], false)
        ui.set(refs.freeStand[2], "On hotkey")
        ui.set(refs.fsBodyYaw, false)
        ui.set(refs.edgeYaw, false)
    end,
    type_from_string = function(input)
        if type(input) ~= "string" then return input end

        local value = input:lower()

        if value == "true" then
            return true
        elseif value == "false" then
            return false
        elseif tonumber(value) ~= nil then
            return tonumber(value)
        else
            return tostring(input)
        end
    end,
    lerp = function(start, vend, time)
        return start + (vend - start) * time
    end,
    hex = function(arg)
        local result = "\a"
        for key, value in next, arg do
            local output = ""
            while value > 0 do
                local index = math.fmod(value, 16) + 1
                value = math.floor(value / 16)
                output = string.sub("0123456789ABCDEF", index, index) .. output 
            end
            if #output == 0 then 
                output = "00" 
            elseif #output == 1 then 
                output = "0" .. output 
            end 
            result = result .. output
        end 
        return result .. "FF"
    end,
    time_to_ticks = function(t)
        return math.floor(0.5 + (t / globals.tickinterval()))
    end,
    RGBAtoHEX = function(redArg, greenArg, blueArg, alphaArg)
        return string.format('%.2x%.2x%.2x%.2x', redArg, greenArg, blueArg, alphaArg)
    end,
    create_color_array = function(r, g, b, string)
        local colors = {}
        for i = 0, #string do
            local color = {r, g, b, 255 * math.abs(1 * math.cos(2 * math.pi * globals.curtime() / 4 + i * 5 / 30))}
            table.insert(colors, color)
        end
        return colors
    end
}

local animate_text = function(time, string, r, g, b, a)
    local t_out, t_out_iter = { }, 1

    local l = string:len( ) - 1

    local r_add = (255 - r)
    local g_add = (255 - g)
    local b_add = (255 - b)
    local a_add = (155 - a)

    for i = 1, #string do
        local iter = (i - 1)/(#string - 1) + time
        t_out[t_out_iter] = "\a" .. func.RGBAtoHEX( r + r_add * math.abs(math.cos( iter )), g + g_add * math.abs(math.cos( iter )), b + b_add * math.abs(math.cos( iter )), a + a_add * math.abs(math.cos( iter )) )

        t_out[t_out_iter + 1] = string:sub( i, i )

        t_out_iter = t_out_iter + 2
    end

    return t_out
end
-- @region FUNCS end

-- @region UI_LAYOUT start
local tab, container = "AA", "Anti-aimbot angles"
local label = ui.new_label(tab, container, "flaxyaw")
local empty = ui.new_label(tab, container, " ")
local tabPicker = ui.new_combobox(tab, container, "Tab", "Anti-aim", "Builder", "Visuals", "Misc", "Config")
local aaBuilder = {}
local stateContainer = {}
local statePicker = ui.new_combobox(tab, container, "Anti-aim state", vars.aaStates)
for i=1, #vars.aaStates do
    stateContainer[i] = func.hex({200,200,200}) .. "(" .. func.hex({222,55,55}) .. "" .. vars.pStates[i] .. "" .. func.hex({200,200,200}) .. ")" .. func.hex({155,155,155}) .. " "
    aaBuilder[i] = {
        enableState = ui.new_checkbox(tab, container, "Enable " .. func.hex({lua_color.r, lua_color.g, lua_color.b}) .. vars.aaStates[i]:lower() .. func.hex({200,200,200}) .. " state"),
        pitch = ui.new_combobox(tab, container, "Pitch\n" .. stateContainer[i], "Off", "Default", "Up", "Down", "Minimal", "Random", "Custom"),
        pitchSlider = ui.new_slider(tab, container, "\nPitch add" .. stateContainer[i], -89, 89, 0, true, "°", 1),
        yawBase = ui.new_combobox(tab, container, "Yaw base\n" .. stateContainer[i], "Local view", "At targets"),
        yaw = ui.new_combobox(tab, container, "Yaw\n" .. stateContainer[i], "Off", "180", "Spin", "Static", "180 Z", "Crosshair"),
        yawLeft = ui.new_slider(tab, container, "Left\nyaw" .. stateContainer[i], -180, 180, 0, true, "°", 1),
        yawRight = ui.new_slider(tab, container, "Right\nyaw" .. stateContainer[i], -180, 180, 0, true, "°", 1),
        yawJitter = ui.new_combobox(tab, container, "Yaw jitter\n" .. stateContainer[i], "Off", "Offset", "Center", "3-Way", "Random"),
        yawJitterLeft = ui.new_slider(tab, container, "Left\nyaw jitter" .. stateContainer[i], -180, 180, 0, true, "°", 1),
        yawJitterRight = ui.new_slider(tab, container, "Right\nyaw jitter" .. stateContainer[i], -180, 180, 0, true, "°", 1),
        bodyYaw = ui.new_combobox(tab, container, "Body yaw\n" .. stateContainer[i], "Off", "Opposite", "Jitter", "Static"),
        bodyYawLeft = ui.new_slider(tab, container, "Left\nbody yaw" .. stateContainer[i], -180, 180, 0, true, "°", 1),
        bodyYawRight = ui.new_slider(tab, container, "Right\nbody yaw" .. stateContainer[i], -180, 180, 0, true, "°", 1),
        roll = ui.new_slider(tab, container, "Roll\n" .. stateContainer[i], -45, 45, 0, true, "°"),
    }
end

local aaContainer = "(" .. func.hex({lua_color.r, lua_color.g, lua_color.b}) .. "AA" .. func.hex({200,200,200}) .. ") "
local mContainer = "(" .. func.hex({lua_color.r, lua_color.g, lua_color.b}) .. "M" .. func.hex({200,200,200}) .. ") "
local menu = {
    aaTab = {
        legitAAHotkey = ui.new_hotkey(tab, container, aaContainer .. "Legit aa"),
        freestandHotkey = ui.new_hotkey(tab, container, aaContainer .. "Freestand"),
        exploits = ui.new_multiselect(tab, container, "Exploits", "Pitch flick in air", "Air tick switcher", "Force defensive in air"),
        manualLeft = ui.new_hotkey(tab, container, mContainer .. "Left"),
        manualRight = ui.new_hotkey(tab, container, mContainer .. "Right"),
        manualForward = ui.new_hotkey(tab, container, mContainer .. "Forward"),
    },
    visualsTab = {
        label = ui.new_label(tab, container, "WIP")
    },
    miscTab = {
        avoidBackstab = ui.new_checkbox(tab, container, mContainer .. "Avoid backstab"),
        fixHideshots = ui.new_checkbox(tab, container, mContainer .. "Fix hideshots"),
        manualsOverFs = ui.new_checkbox(tab, container, mContainer .. "Manuals over freestanding"),
        animations = ui.new_multiselect(tab, container, "Animations", "Static legs in air", "Leg fucker", "Moonwalk", "0 pitch on landing"),
    },
    configTab = {
        list = ui.new_listbox(tab, container, "Configs", ""),
        name = ui.new_textbox(tab, container, "Config name", ""),
        load = ui.new_button(tab, container, "Load", function() end),
        save = ui.new_button(tab, container, "Save", function() end),
        delete = ui.new_button(tab, container, "Delete", function() end),
        import = ui.new_button(tab, container, "Import", function() end),
        export = ui.new_button(tab, container, "Export", function() end)
    }
}

local function getConfig(name)
    local database = database.read(lua.database.configs) or {}

    for i, v in pairs(database) do
        if v.name == name then
            return {
                config = v.config,
                index = i
            }
        end
    end

    for i, v in pairs(presets) do
        if v.name == name then
            return {
                config = v.config,
                index = i
            }
        end
    end

    return false
end
local function saveConfig(name)
    local db = database.read(lua.database.configs) or {}
    local config = {}

    if name:match("[^%w]") ~= nil then
        return
    end

    for key, value in pairs(vars.pStates) do
        config[value] = {}
        for k, v in pairs(aaBuilder[key]) do
            config[value][k] = ui.get(v)
        end
    end

    local cfg = getConfig(name)

    if not cfg then
        table.insert(db, { name = name, config = config })
    else
        db[cfg.index].config = config
    end

    database.write(lua.database.configs, db)
end
local function deleteConfig(name)
    local db = database.read(lua.database.configs) or {}

    for i, v in pairs(db) do
        if v.name == name then
            table.remove(db, i)
            break
        end
    end

    for i, v in pairs(presets) do
        if v.name == name then
            return false
        end
    end

    database.write(lua.database.configs, db)
end
local function getConfigList()
    local database = database.read(lua.database.configs) or {}
    local config = {}

    for i, v in pairs(presets) do
        table.insert(config, v.name)
    end

    for i, v in pairs(database) do
        table.insert(config, v.name)
    end

    return config
end
local function typeFromString(input)
    if type(input) ~= "string" then return input end

    local value = input:lower()

    if value == "true" then
        return true
    elseif value == "false" then
        return false
    elseif tonumber(value) ~= nil then
        return tonumber(value)
    else
        return tostring(input)
    end
end
local function loadSettings(config)
    for key, value in pairs(vars.pStates) do
        for k, v in pairs(aaBuilder[key]) do
            if (config[value][k] ~= nil) then
                ui.set(v, config[value][k])
            end
        end 
    end
end
local function importSettings()
    loadSettings(json.parse(clipboard.get()))
end
local function exportSettings(name)
    local config = getConfig(name)
    clipboard.set(json.stringify(config.config))
end
local function loadConfig(name)
    local config = getConfig(name)
    loadSettings(config.config)
end

local function initDatabase()
    if database.read(lua.database.configs) == nil then
        database.write(lua.database.configs, {})
    end

    local link = ""

    http.get(link, function(success, response)
        if not success then
            print("Failed to get presets")
            return
        end
    
        data = json.parse(response.body)
    
        for i, preset in pairs(data.presets) do
            table.insert(presets, { name = "*"..preset.name, config = preset.config})
            ui.set(menu.configTab.name, "*"..preset.name)
        end
        ui.update(menu.configTab.list, getConfigList())
    end)
end

-- @region UI_LAYOUT end

-- @region AA_CALLBACKS start
local aa = {
	ignore = false,
	manualAA= 0,
	input = 0,
}
client.set_event_callback("player_connect_full", function() 
	aa.ignore = false
	aa.manualAA= 0
	aa.input = 0
end)
client.set_event_callback("setup_command", function(cmd)
    vars.localPlayer = entity.get_local_player()
    if not vars.localPlayer  or not entity.is_alive(vars.localPlayer) then return end
	local flags = entity.get_prop(vars.localPlayer, "m_fFlags")
    local onground = bit.band(flags, 1) ~= 0 and cmd.in_jump == 0
	local valve = entity.get_prop(entity.get_game_rules(), "m_bIsValveDS")
	local origin = vector(entity.get_prop(vars.localPlayer, "m_vecOrigin"))
	local velocity = vector(entity.get_prop(vars.localPlayer, "m_vecVelocity"))
	local camera = vector(client.camera_angles())
	local eye = vector(client.eye_position())
	local speed = math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y) + (velocity.z * velocity.z))
    local weapon = entity.get_player_weapon()
	local pStill = math.sqrt(velocity.x ^ 2 + velocity.y ^ 2) < 5
    local bodyYaw = entity.get_prop(vars.localPlayer, "m_flPoseParameter", 11) * 120 - 60

    local isSlow = ui.get(refs.slow[1]) and ui.get(refs.slow[2])
	local isOs = ui.get(refs.os[1]) and ui.get(refs.os[2])
	local isFd = ui.get(refs.fakeDuck)
	local isDt = ui.get(refs.dt[1]) and ui.get(refs.dt[2])
    local isLegitAA = ui.get(menu.aaTab.legitAAHotkey)

    local manualsOverFs = ui.get(menu.miscTab.manualsOverFs) == true and true or false

    -- manual aa
    ui.set(menu.aaTab.manualLeft, "On hotkey")
    ui.set(menu.aaTab.manualRight, "On hotkey")
    ui.set(menu.aaTab.manualForward, "On hotkey")
    if aa.input + 0.22 < globals.curtime() then
        if aa.manualAA == 0 then
            if ui.get(menu.aaTab.manualLeft) then
                aa.manualAA = 1
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualRight) then
                aa.manualAA = 2
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualForward) then
                aa.manualAA = 3
                aa.input = globals.curtime()
            end
        elseif aa.manualAA == 1 then
            if ui.get(menu.aaTab.manualRight) then
                aa.manualAA = 2
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualForward) then
                aa.manualAA = 3
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualLeft) then
                aa.manualAA = 0
                aa.input = globals.curtime()
            end
        elseif aa.manualAA == 2 then
            if ui.get(menu.aaTab.manualLeft) then
                aa.manualAA = 1
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualForward) then
                aa.manualAA = 3
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualRight) then
                aa.manualAA = 0
                aa.input = globals.curtime()
            end
        elseif aa.manualAA == 3 then
            if ui.get(menu.aaTab.manualForward) then
                aa.manualAA = 0
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualLeft) then
                aa.manualAA = 1
                aa.input = globals.curtime()
            elseif ui.get(menu.aaTab.manualRight) then
                aa.manualAA = 2
                aa.input = globals.curtime()
            end
        end
    end
    if aa.manualAA == 1 or aa.manualAA == 2 or aa.manualAA == 3 then
        aa.ignore = true
        if aa.manualAA == 1 then
            ui.set(refs.yawJitter[1], "Off")
            ui.set(refs.yawJitter[2], 0)
            ui.set(refs.bodyYaw[1], "Static")
            ui.set(refs.bodyYaw[2], -180)
            ui.set(refs.yawBase, "local view")
            ui.set(refs.yaw[1], "180")
            ui.set(refs.yaw[2], -90)
        elseif aa.manualAA == 2 then
            ui.set(refs.yawJitter[1], "Off")
            ui.set(refs.yawJitter[2], 0)
            ui.set(refs.bodyYaw[1], "Static")
            ui.set(refs.bodyYaw[2], -180)
            ui.set(refs.yawBase, "local view")
            ui.set(refs.yaw[1], "180")
            ui.set(refs.yaw[2], 90)
        elseif aa.manualAA == 3 then
            ui.set(refs.yawJitter[1], "Off")
            ui.set(refs.yawJitter[2], 0)
            ui.set(refs.bodyYaw[1], "Static")
            ui.set(refs.bodyYaw[2], -180)
            ui.set(refs.yawBase, "local view")
            ui.set(refs.yaw[1], "180")
            ui.set(refs.yaw[2], 180)
        end
    else
        aa.ignore = false
    end

    local nextAttack = entity.get_prop(vars.localPlayer, "m_flNextAttack")
    local nextPrimaryAttack = entity.get_prop(entity.get_player_weapon(vars.localPlayer), "m_flNextPrimaryAttack")
    local dtActive = false
    local isFl = ui.get(ui.reference("AA", "Fake lag", "Enabled"))
    if nextPrimaryAttack ~= nil then
        dtActive = not (math.max(nextPrimaryAttack, nextAttack) > globals.curtime())
    end

    if pStill then vars.pState = 1 end
    if not pStill then vars.pState = 2 end
    if isSlow then vars.pState = 3 end
    if entity.get_prop(vars.localPlayer, "m_flDuckAmount") > 0.1 then vars.pState = 4 end
    if not pStill and entity.get_prop(vars.localPlayer, "m_flDuckAmount") > 0.1 then vars.pState = 7 end
    if not onground then vars.pState = 5 end
    if not onground and entity.get_prop(vars.localPlayer, "m_flDuckAmount") > 0.1 then vars.pState = 6 end

    -- apply antiaim
    local side = bodyYaw > 0 and 1 or -1
    local in_bombzone   = entity.get_prop(vars.localPlayer, "m_bInBombZone") > 0
    local weapon_ent = entity.get_player_weapon(vars.localPlayer)
    local wtype = csgo_weapons(weapon_ent)
    local holding_bomb  = wtype.type == "c4"
    local bomb_table    = entity.get_all("CPlantedC4")
    local bomb_planted  = #bomb_table > 0
    local bomb_distance = 100
    local defusing = bomb_distance < 62 and entity.get_prop(vars.localPlayer, "m_iTeamNum") == 3

    if not ui.get(menu.aaTab.legitAAHotkey) and aa.ignore == false then
        if ui.get(aaBuilder[vars.pState].enableState) then
            local pitchTypes = {[1] = "Up", [2] = ui.get(aaBuilder[vars.pState].pitch)}
            local flick
            if (onground) then
                flick = globals.realtime()
            end

            if func.table_contains(ui.get(menu.aaTab.exploits), "Pitch flick in air") and not onground and flick ~= nil then
                if (globals.realtime() - flick > 0.5) then
                    ui.set(refs.pitch[1], "Up")
                    flick = globals.realtime()
                else
                    ui.set(refs.pitch[1], ui.get(aaBuilder[vars.pState].pitch))
                end
            elseif ui.get(aaBuilder[vars.pState].pitch) ~= "Custom" then
                ui.set(refs.pitch[1], ui.get(aaBuilder[vars.pState].pitch))
            else
                ui.set(refs.pitch[1], ui.get(aaBuilder[vars.pState].pitch))
                ui.set(refs.pitch[2], ui.get(aaBuilder[vars.pState].pitchSlider))
            end

            ui.set(refs.yawBase, ui.get(aaBuilder[vars.pState].yawBase))

            if cmd.chokedcommands == 0 then
                ui.set(refs.yaw[1], ui.get(aaBuilder[vars.pState].yaw))
                ui.set(refs.yaw[2],(side == 1 and ui.get(aaBuilder[vars.pState].yawLeft) or ui.get(aaBuilder[vars.pState].yawRight)))
            end

            if ui.get(aaBuilder[vars.pState].yawJitter) == "3-Way" then
                ui.set(refs.yawJitter[1], "Center")
                ui.set(refs.yawJitter[2], (side == 1 and ui.get(aaBuilder[vars.pState].yawJitterLeft)*math.random(-1, 1)  or ui.get(aaBuilder[vars.pState].yawJitterRight)*math.random(-1, 1) ))
            else
                ui.set(refs.yawJitter[1], ui.get(aaBuilder[vars.pState].yawJitter))
                ui.set(refs.yawJitter[2], (side == 1 and ui.get(aaBuilder[vars.pState].yawJitterLeft) or ui.get(aaBuilder[vars.pState].yawJitterRight)))
            end


            if ui.get(aaBuilder[vars.pState].bodyYaw) == "Jitter" then
                ui.set(refs.bodyYaw[1], "Static")
                ui.set(refs.bodyYaw[2], globals.tickcount() % 2 == 1 and 180 or -180)
            else
                ui.set(refs.bodyYaw[1], ui.get(aaBuilder[vars.pState].bodyYaw))
                ui.set(refs.bodyYaw[2], (side == 1 and ui.get(aaBuilder[vars.pState].bodyYawLeft) or ui.get(aaBuilder[vars.pState].bodyYawRight)))
            end

            ui.set(refs.roll, ui.get(aaBuilder[vars.pState].roll))
        elseif not ui.get(aaBuilder[vars.pState].enableState) then
            ui.set(refs.pitch[1], "Off")
            ui.set(refs.yawBase, "Local view")
            ui.set(refs.yaw[1], "Off")
            ui.set(refs.yaw[2], 0)
            ui.set(refs.yawJitter[1], "Off")
            ui.set(refs.yawJitter[2], 0)
            ui.set(refs.bodyYaw[1], "Off")
            ui.set(refs.bodyYaw[2], 0)
            ui.set(refs.fsBodyYaw, false)
            ui.set(refs.edgeYaw, false)
            ui.set(refs.roll, 0)
        end
    elseif ui.get(menu.aaTab.legitAAHotkey) and aa.ignore == false then
        if weapon ~= nil and entity.get_classname(weapon) == "CC4" or (in_bombzone and holding_bomb or defusing) then
            cmd.in_use = 1
        else
            cmd.in_use = 0
            ui.set(refs.pitch[1], "Off")
            ui.set(refs.yawBase, "Local view")
            ui.set(refs.yaw[1], "Off")
            ui.set(refs.yaw[2], 0)
            ui.set(refs.yawJitter[1], "Off")
            ui.set(refs.yawJitter[2], 0)
            ui.set(refs.bodyYaw[1], "Opposite")
            ui.set(refs.bodyYaw[2], 0)
            ui.set(refs.fsBodyYaw, true)
            ui.set(refs.edgeYaw, false)
            ui.set(refs.roll, 0)
        end
    end

    -- fix hideshots
	if ui.get(menu.miscTab.fixHideshots) then
		if isOs and not isDt and not isFd then
            if not hsSaved then
                hsValue = ui.get(refs.fakeLag[1])
                hsSaved = true
            end
			ui.set(refs.fakeLag[1], 1)
		elseif hsSaved then
			ui.set(refs.fakeLag[1], hsValue)
            hsSaved = false
		end
	end

    -- avoid backstab
    if ui.get(menu.miscTab.avoidBackstab) then
        local players = entity.get_players(true)

        for i=1, #players do
            local x, y, z = entity.get_prop(players[i], "m_vecOrigin")
            local distance = func.findDist(origin.x, origin.y, origin.z, x, y, z)
            local weapon = entity.get_player_weapon(players[i])
            if entity.get_classname(weapon) == "CKnife" and distance <= 200 then
                ui.set(refs.yaw[2], 180)
                ui.set(refs.pitch[1], "Off")
            end
        end
    end

    -- freestand
    if (ui.get(menu.aaTab.freestandHotkey)) then
        if manualsOverFs == true and aa.ignore == true then
            ui.set(refs.freeStand[2], "On hotkey")
            return
        else
            ui.set(refs.freeStand[2], "Always on")
            ui.set(refs.freeStand[1], true)
        end
    else
        ui.set(refs.freeStand[1], false)
        ui.set(refs.freeStand[2], "On hotkey")
    end

    if func.table_contains(ui.get(menu.aaTab.exploits), "Air tick switcher") and not onground then
        if dtSaved == nil then
            dtSaved = ui.get(refs.dt[3])
        end
        ui.set(refs.dt[3], globals.tickcount() % 2 == 1 and "Offensive" or "Defensive")
    else
        if dtSaved ~= nil then
            ui.set(refs.dt[3], dtSaved)
            dtSaved = nil
        end
    end

    local defensiveKey = ( isDt and not onground and func.table_contains(ui.get(menu.aaTab.exploits), "Force defensive in air") )

    cmd.force_defensive = defensiveKey == true and true or false

    isDefensive = cmd.force_defensive == true and true or false
end)

local legsSaved = false
local legsTypes = {[1] = "Off", [2] = "Always slide", [3] = "Never slide"}
local ground_ticks = 0
client.set_event_callback("pre_render", function()
    if not entity.get_local_player() then return end
    local flags = entity.get_prop(entity.get_local_player(), "m_fFlags")
    ground_ticks = bit.band(flags, 1) == 0 and 0 or (ground_ticks < 5 and ground_ticks + 1 or ground_ticks)

    if func.table_contains(ui.get(menu.miscTab.animations), "Static legs in air") then
        entity.set_prop(entity.get_local_player(), "m_flPoseParameter", 1, 6) 
    end

   if func.table_contains(ui.get(menu.miscTab.animations), "Leg fucker") or func.table_contains(ui.get(menu.miscTab.animations), "Moonwalk") then
        if not legsSaved then
            legsSaved = ui.get(refs.legMovement)
        end
        ui.set_visible(refs.legMovement, false)
        if func.table_contains(ui.get(menu.miscTab.animations), "Leg fucker") and not func.table_contains(ui.get(menu.miscTab.animations), "Moonwalk") then
            ui.set(refs.legMovement, legsTypes[math.random(1, 3)])
            entity.set_prop(entity.get_local_player(), "m_flPoseParameter", 8, 0)
        elseif func.table_contains(ui.get(menu.miscTab.animations), "Moonwalk")then
            entity.set_prop(entity.get_local_player(), "m_flPoseParameter", 0, 7)
            local me = ent.get_local_player()
            local flags = me:get_prop("m_fFlags")
            local onground = bit.band(flags, 1) ~= 0
            if not onground then
                local my_animlayer = me:get_anim_overlay(6) -- MOVEMENT_MOVE
                my_animlayer.weight = 1
            end
            ui.set(refs.legMovement, "Off")
        end
    elseif (legsSaved == "Off" or legsSaved == "Always slide" or legsSaved == "Never slide") then
        ui.set_visible(refs.legMovement, true)
        ui.set(refs.legMovement, legsSaved)
        legsSaved = false
    end
    if func.table_contains(ui.get(menu.miscTab.animations), "0 pitch on landing") then
        ground_ticks = bit.band(flags, 1) == 1 and ground_ticks + 1 or 0

        if ground_ticks > 20 and ground_ticks < 150 then
            entity.set_prop(entity.get_local_player(), "m_flPoseParameter", 0.5, 12)
        end
    end
end)
-- @region AA_CALLBACKS end

-- @region UI_CALLBACKS start
ui.update(menu.configTab.list,getConfigList())
if database.read(lua.database.configs) == nil then
    database.write(lua.database.configs, {})
end
ui.set(menu.configTab.name, #database.read(lua.database.configs) == 0 and "" or database.read(lua.database.configs)[ui.get(menu.configTab.list)+1].name)
ui.set_callback(menu.configTab.list, function(value)
    local protected = function()
        if value == nil then return end
        local name = ""
    
        local configs = getConfigList()
        if configs == nil then return end
    
        name = configs[ui.get(value)+1] or ""
    
        ui.set(menu.configTab.name, name)
    end

    if pcall(protected) then

    end
end)

ui.set_callback(menu.configTab.load, function()

    local name = ui.get(menu.configTab.name)
    if name == "" then return end
    local protected = function()
        loadConfig(name)
    end

    if pcall(protected) then
        name = name:gsub('*', '')
    else
    end
end)

ui.set_callback(menu.configTab.save, function()


        local name = ui.get(menu.configTab.name)
        if name == "" then return end
    
        for i, v in pairs(presets) do
            if v.name == name:gsub('*', '') then
                return
            end
        end

        if name:match("[^%w]") ~= nil then
            return
        end
    local protected = function()
        saveConfig(name)
        ui.update(menu.configTab.list, getConfigList())
    end
    if pcall(protected) then

    end
end)

ui.set_callback(menu.configTab.delete, function()
    local name = ui.get(menu.configTab.name)
    if name == "" then return end

    if deleteConfig(name) == false then
        ui.update(menu.configTab.list, getConfigList())
        return
    end

    for i, v in pairs(presets) do
        if v.name == name:gsub('*', '') then

            return
        end
    end

    local protected = function()
        deleteConfig(name)
    end

    if pcall(protected) then
        ui.update(menu.configTab.list, getConfigList())
        ui.set(menu.configTab.list, #presets + #database.read(lua.database.configs) - #database.read(lua.database.configs))
        ui.set(menu.configTab.name, #database.read(lua.database.configs) == 0 and "" or getConfigList()[#presets + #database.read(lua.database.configs) - #database.read(lua.database.configs)+1])
    end
end)

ui.set_callback(menu.configTab.import, function()


    local protected = function()
        importSettings()
    end

    if pcall(protected) then
    end
end)

ui.set_callback(menu.configTab.export, function()
    local name = ui.get(menu.configTab.name)
    if name == "" then return end

    local protected = function()
        exportSettings(name)
    end

    if pcall(protected) then

    end
end)
-- @region UI_CALLBACKS end

-- @region UI_RENDER start
client.set_event_callback("paint_ui", function()
    vars.activeState = vars.sToInt[ui.get(statePicker)]
    local isEnabled = true
    local isAATab = ui.get(tabPicker) == "Anti-aim"
    local isBuilderTab = ui.get(tabPicker) == "Builder"
    local isVisualsTab = ui.get(tabPicker) == "Visuals"
    local isMiscTab = ui.get(tabPicker) == "Misc"
    local isCFGTab = ui.get(tabPicker) == "Config"

    local aA = func.create_color_array(lua_color.r, lua_color.g, lua_color.b, "flaxyaw")
    ui.set(label, string.format("\a%sf\a%sl\a%sa\a%sx\a%sy\a%sa\a%sw", func.RGBAtoHEX(unpack(aA[1])), func.RGBAtoHEX(unpack(aA[2])), func.RGBAtoHEX(unpack(aA[3])), func.RGBAtoHEX(unpack(aA[4])), func.RGBAtoHEX(unpack(aA[5])), func.RGBAtoHEX(unpack(aA[6])),  func.RGBAtoHEX(unpack(aA[7])) ) )

    for i = 1, #vars.aaStates do
        local stateEnabled = ui.get(aaBuilder[i].enableState)
        ui.set_visible(aaBuilder[i].enableState, vars.activeState == i and isBuilderTab and isEnabled)
        ui.set_visible(aaBuilder[i].pitch, vars.activeState == i and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].pitchSlider , vars.activeState == i and isBuilderTab and stateEnabled and ui.get(aaBuilder[i].pitch) == "Custom" and isEnabled)
        ui.set_visible(aaBuilder[i].yawBase, vars.activeState == i and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].yaw, vars.activeState == i and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].yawLeft, vars.activeState == i and ui.get(aaBuilder[i].yaw) ~= "Off" and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].yawRight, vars.activeState == i and ui.get(aaBuilder[i].yaw) ~= "Off" and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].yawJitter, vars.activeState == i and ui.get(aaBuilder[i].yaw) ~= "Off" and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].yawJitterLeft, vars.activeState == i and ui.get(aaBuilder[i].yawJitter) ~= "Off" and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].yawJitterRight, vars.activeState == i and ui.get(aaBuilder[i].yawJitter) ~= "Off" and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].bodyYaw, vars.activeState == i and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].bodyYawLeft, vars.activeState == i and ui.get(aaBuilder[i].bodyYaw) ~= "Off" and ui.get(aaBuilder[i].bodyYaw) ~= "Opposite" and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].bodyYawRight, vars.activeState == i and ui.get(aaBuilder[i].bodyYaw) ~= "Off" and ui.get(aaBuilder[i].bodyYaw) ~= "Opposite" and isBuilderTab and stateEnabled and isEnabled)
        ui.set_visible(aaBuilder[i].roll, vars.activeState == i and isBuilderTab and stateEnabled and isEnabled)
    end

    ui.set_visible(statePicker, isBuilderTab and isEnabled)

    for i, feature in pairs(menu.aaTab) do
        if type(feature) ~= "table" then
            ui.set_visible(feature, isAATab and isEnabled)
        end
	end 

    for i, feature in pairs(menu.visualsTab) do
        if type(feature) ~= "table" then
            ui.set_visible(feature, isVisualsTab and isEnabled)
        end
	end 

    for i, feature in pairs(menu.miscTab) do
        if type(feature) ~= "table" then
            ui.set_visible(feature, isMiscTab and isEnabled)
        end
	end

    for i, feature in pairs(menu.configTab) do
		ui.set_visible(feature, isCFGTab and isEnabled)
	end

    if not isEnabled and not saved then
        func.resetAATab()
        ui.set(refs.fsBodyYaw, isEnabled)
        ui.set(refs.enabled, isEnabled)
        saved = true
    elseif isEnabled and saved then
        ui.set(refs.fsBodyYaw, not isEnabled)
        ui.set(refs.enabled, isEnabled)
        saved = false
    end
    func.setAATab(not isEnabled)

end)
-- @region UI_RENDER end

client.set_event_callback("shutdown", function()
    if legsSaved ~= false then
        ui.set(refs.legMovement, legsSaved)
    end
    if hsValue ~= nil then
        ui.set(refs.fakeLag[1], hsValue)
    end
    if dtSaved ~= nil then
        ui.set(refs.dt[3], dtSaved)
    end
    func.setAATab(true)
end)
--End for now