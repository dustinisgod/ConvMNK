local mq = require('mq')
local utils = require('utils')
local commands = require('commands')
local gui = require('gui')
local nav = require('nav')
local pull = require('pull')

local class = mq.TLO.Me.Class()
if class ~= "Monk" then
    print("This script is only for Monks.")
    mq.exit()
end

utils.PluginCheck()

mq.cmd('/assist off')

mq.imgui.init('controlGUI', gui.controlGUI)

commands.init()

local toggleboton = false
local lastPullOnState = false

local function returnChaseToggle()
    -- Check if bot is on and return-to-camp is enabled, and only set camp if toggleboton is false
    if gui.botOn and gui.returnToCamp and not toggleboton then
        nav.setCamp()
        toggleboton = true
    elseif not gui.botOn and toggleboton then
        -- Clear camp if bot is turned off after being on
        nav.clearCamp()
        toggleboton = false
    end

    -- Check if pullOn has changed state and return-to-camp is enabled, only set camp if needed
    if gui.pullOn ~= lastPullOnState then
        lastPullOnState = gui.pullOn
        if gui.pullOn and gui.returnToCamp then
            nav.setCamp()
        elseif not gui.pullOn then
            nav.clearCamp()
        end
    end
end

utils.loadPullConfig()

while gui.controlGUI do

    returnChaseToggle()

    if gui.botOn then

        utils.monitorNav()

        if gui.pullOn then
            pull.pullRoutine()
        end
        
        if gui.assistMelee then
            utils.assistMonitor()
        end
    end

    mq.doevents()
    mq.delay(100)
end