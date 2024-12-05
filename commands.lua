local mq = require 'mq'
local gui = require 'gui'
local nav = require 'nav'
local utils = require 'utils'

local commands = {}

-- Existing functions

local function setExit()
    print("Closing..")
    gui.isOpen = false
end

local function setSave()
    gui.saveConfig()
end

-- Helper function for on/off commands
local function setToggleOption(option, value, name)
    if value == "on" then
        gui[option] = true
        print(name .. " is now enabled.")
    elseif value == "off" then
        gui[option] = false
        print(name .. " is now disabled.")
    else
        print("Usage: /convMNK " .. name .. " on/off")
    end
end

-- Helper function for numeric value commands
local function setNumericOption(option, value, name)
    if value == "" then
        print("Usage: /convMNK " .. name .. " <number>")
        return
    end
    if not string.match(value, "^%d+$") then
        print("Error: " .. name .. " must be a number with no letters or symbols.")
        return
    end
    gui[option] = tonumber(value)
    print(name .. " set to", gui[option])
end

-- On/Off Commands
local function setBotOnOff(value) setToggleOption("botOn", value, "Bot") end
local function setKeepMobsInCamp(value) setToggleOption("keepMobsInCamp", value, "Keep Mobs In Camp") end
local function setSwitchWithMA(value) setToggleOption("switchWithMA", value, "Switch with MA") end
local function setPullOnOff(value)
    if value == "on" then
        gui.pullOn = true
        gui.chase = false
        gui.returntocamp = true
        print("Pulling is now enabled.")
    elseif value == "off" then
        gui.pullOn = false
        print("Pulling is now disabled.")
    else
        print("Usage: /convMNK Pull on/off")
    end
end
local function setPullPause(value) setToggleOption("pullPause", value, "Pull Pause") end

-- Numeric Commands
local function setPullAmount(value) setNumericOption("pullAmount", value, "PullAmount") end
local function setPullDistance(value) setNumericOption("pullDistance", value, "PullDistance") end
local function setPullLevelMin(value) setNumericOption("pullLevelMin", value, "PullLevelMin") end
local function setPullLevelMax(value) setNumericOption("pullLevelMax", value, "PullLevelMax") end
local function setPullPauseTimer(value) setNumericOption("pullPauseTimer", value, "PullPauseTimer") end
local function setPullPauseDuration(value) setNumericOption("pullPauseDuration", value, "PullPauseDuration") end
local function setKeepMobsInCampAmount(value) setNumericOption("keepMobsInCampAmount", value, "KeepMobsInCampAmount") end

-- Combined function for setting main assist, range, and percent
local function setAssist(name, range, percent)
    if name then
        utils.setMainAssist(name)
        print("Main Assist set to", name)
    else
        print("Error: Main Assist name is required.")
        return
    end

    -- Set the assist range if provided
    if range and string.match(range, "^%d+$") then
        gui.assistRange = tonumber(range)
        print("Assist Range set to", gui.assistRange)
    else
        print("Assist Range not provided or invalid. Current range:", gui.assistRange)
    end

    -- Set the assist percent if provided
    if percent and string.match(percent, "^%d+$") then
        gui.assistPercent = tonumber(percent)
        print("Assist Percent set to", gui.assistPercent)
    else
        print("Assist Percent not provided or invalid. Current percent:", gui.assistPercent)
    end
end

local function setFeignDeath(value)
    if value and string.match(value, "^%d+$") then
        gui.feignAggro = true
        gui.feignAggroPercent = value

        print("Feign Death percent set to:", gui.feignAggroPercent)
    elseif value == 'off' then
        gui.feignAggro = false
        print("Feign Death disabled.")
    else
        print("Error: Invalid cooldown for Feign Death. Expected a number, received:", value)
        return
    end
end

local function setMend(value)
    if value and string.match(value, "^%d+$") then
        gui.useMend = true
        gui.useMendPercent = value

        print("Mend percent set to:", gui.useMendPercent)
    elseif value == 'off' then
        gui.useMend = false
        print("Mend disabled.")
    else
        print("Error: Invalid cooldown for Feign Death. Expected a number, received:", value)
        return
    end
end


local function setChaseOnOff(value)
    if value == "" then
        print("Usage: /convMNK Chase <targetName> <distance> or /convMNK Chase off/on")
    elseif value == 'on' then
        gui.chaseon = true
        gui.returntocamp = false
        gui.pullOn = false
        print("Chase enabled.")
    elseif value == 'off' then
        gui.chaseon = false
        print("Chase disabled.")
    else
        -- Split value into targetName and distance
        local targetName, distanceStr = value:match("^(%S+)%s*(%S*)$")
        
        if not targetName then
            print("Invalid input. Usage: /convMNK Chase <targetName> <distance>")
            return
        end
        
        -- Convert distance to a number, if it's provided
        local distance = tonumber(distanceStr)
        
        -- Check if distance is valid
        if not distance then
            print("Invalid distance provided. Usage: /convMNK Chase <targetName> <distance> or /convMNK Chase off")
            return
        end
        
        -- Pass targetName and valid distance to setChaseTargetAndDistance
        nav.setChaseTargetAndDistance(targetName, distance)
    end
end

-- Combined function for setting camp, return to camp, and chase
local function setCampHere(value1)
    if value1 == "on" then
        gui.chaseon = false
        gui.campLocation = nav.setCamp()
        gui.returntocamp = true
        gui.campDistance = gui.campDistance or 10
        print("Camp location set to current spot. Return to Camp enabled with default distance:", gui.campDistance)
    elseif value1 == "off" then
        -- Disable return to camp
        gui.returntocamp = false
        print("Return To Camp disabled.")
    elseif tonumber(value1) then
        gui.chaseon = false
        gui.campLocation = nav.setCamp()
        gui.returntocamp = true
        gui.campDistance = tonumber(value1)
        print("Camp location set with distance:", gui.campDistance)
    else
        print("Error: Invalid command. Usage: /convMNK camphere <distance>, /convMNK camphere on, /convMNK camphere off")
    end
end

local function setMeleeOptions(meleeOption, stickOption, stickDistance)
    -- Set Assist Melee on or off based on the first argument
    if meleeOption == "on" then
        gui.assistMelee = true
        print("Assist Melee is now enabled")
    elseif meleeOption == "off" then
        gui.assistMelee = false
        print("Assist Melee is now disabled")
    elseif meleeOption == "front" or meleeOption == "behind" or meleeOption == "side" then
        -- Set Stick position based on 'front' or 'behind' and optionally set distance
        gui.assistMelee = true
        if meleeOption == "front" then
            gui.stickFront = true
            gui.stickBehind = false
            gui.stickLeft = false
            gui.stickRight = false
            print("Stick set to front")
        elseif meleeOption == "behind" then
            gui.stickBehind = true
            gui.stickFront = false
            gui.stickLeft = false
            gui.stickRight = false
            print("Stick set to behind")
        elseif meleeOption == "side" then
            gui.stickSide = true
            gui.stickFront = false
            gui.stickBehind = false
            print("Stick set to side")
        end

        -- Check if stickDistance is provided and is a valid number
        if stickOption and tonumber(stickOption) then
            gui.stickDistance = tonumber(stickOption)
            print("Stick distance set to", gui.stickDistance)
        elseif stickOption then
            print("Invalid stick distance. Usage: /convMNK melee front/behind/side <distance>")
        end
    else
        print("Error: Invalid command. Usage: /convMNK melee on/off or /convMNK melee front/behind/side <distance>")
    end
end

local function setPullIgnore(scope, action)
    -- Check for a valid target name
    local targetName = mq.TLO.Target.CleanName()
    if not targetName then
        print("Error: No target selected. Please target a mob to modify the pull ignore list.")
        return
    end

    -- Determine if the scope is global or zone-specific
    local isGlobal = (scope == "global")

    if action == "add" then
        utils.addMobToPullIgnoreList(targetName, isGlobal)
        local scopeText = isGlobal and "global quest NPC ignore list" or "pull ignore list for the current zone"
        print(string.format("'%s' has been added to the %s.", targetName, scopeText))

    elseif action == "remove" then
        utils.removeMobFromPullIgnoreList(targetName, isGlobal)
        local scopeText = isGlobal and "global quest NPC ignore list" or "pull ignore list for the current zone"
        print(string.format("'%s' has been removed from the %s.", targetName, scopeText))

    else
        print("Error: Invalid action. Usage: /convMNK pullignore zone/global add/remove")
    end
end

local function commandHandler(command, ...)
    -- Convert command and arguments to lowercase for case-insensitive matching
    command = string.lower(command)
    local args = {...}
    for i, arg in ipairs(args) do
        args[i] = string.lower(arg)
    end

    if command == "exit" then
        setExit()
    elseif command == "bot" then
        setBotOnOff(args[1])
    elseif command == "save" then
        setSave()
    elseif command == "assist" then
        setAssist(args[1], args[2], args[3])
    elseif command == "melee" then
        setMeleeOptions(args[1], args[2], args[3])
    elseif command == "switchwithma" then
        setSwitchWithMA(args[1])
    elseif command == "camphere" then
        setCampHere(args[1])
    elseif command == "chase" then
        local chaseValue = args[1]
        if args[2] then
            chaseValue = chaseValue .. " " .. args[2]
        end
        setChaseOnOff(chaseValue)
    elseif command == "pull" then
        setPullOnOff(args[1])
    elseif command == "pullamount" then
        setPullAmount(args[1])
    elseif command == "pulldistance" then
        setPullDistance(args[1])
    elseif command == "pulllevelmin" then
        setPullLevelMin(args[1])
    elseif command == "pulllevelmax" then
        setPullLevelMax(args[1])
    elseif command == "pullpause" then
        setPullPause(args[1])
    elseif command == "pullpausetimer" then
        setPullPauseTimer(args[1])
    elseif command == "pullpauseduration" then
        setPullPauseDuration(args[1])
    elseif command == "keepmobsincamp" then
        setKeepMobsInCamp(args[1])
    elseif command == "keepmobsincampamount" then
        setKeepMobsInCampAmount(args[1])
    elseif command == "pullignore" then
        setPullIgnore(args[1], args[2])
    elseif command == "feign" then
        setFeignDeath(args[1])
    elseif command == "mend" then
        setMend(args[1])
    end
end

function commands.init()
    -- Single binding for the /convMNK command
    mq.bind('/convMNK', function(command, ...)
        commandHandler(command, ...)
    end)
end

function commands.initALL()
    -- Single binding for the /convBRD command
    mq.bind('/convALL', function(command, ...)
        commandHandler(command, ...)
    end)
end

return commands