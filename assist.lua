local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local pull = require('pull')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local assist = {}

local charLevel = mq.TLO.Me.Level()

function assist.assistRoutine()

    if not gui.botOn or not gui.assistMelee then
        return
    end

    if gui.pullOn and pull.campQueueCount < 0 then
        return
    elseif gui.pullOn and gui.keepMobsInCamp and gui.keepMobsInCampAmount < pull.campQueueCount then
        return
    end

    -- Use reference location to find mobs within assist range
    local mobsInRange = utils.referenceLocation(gui.assistRange) or {}
    if #mobsInRange == 0 then
        return
    end

    -- Check if the main assist is a valid PC, is alive, and is in the same zone
    local mainAssistSpawn = mq.TLO.Spawn(gui.mainAssist)
    if mainAssistSpawn and mainAssistSpawn.Type() == "PC" and not mainAssistSpawn.Dead() then
        mq.cmdf("/assist %s", gui.mainAssist)
        mq.delay(200)  -- Short delay to allow the assist command to take effect
    else
        return
    end

    -- Re-check the target after assisting to confirm it's an NPC within range
    if not mq.TLO.Target() or (mq.TLO.Target() and mq.TLO.Target.Type() ~= "NPC") then
        debugPrint("No target or target is not an NPC.")
        return
    end

    if mq.TLO.Target() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange and mq.TLO.Stick() == "OFF" and not mq.TLO.Target.Mezzed() then
        if gui.stickFront then
            if mq.TLO.Navigation.Active() then
                mq.cmd('/nav stop')
                mq.delay(100)
            end
            mq.cmd("/stick moveback 0")
            mq.delay(100)
            mq.cmdf("/stick front %d uw", gui.stickDistance)
            mq.delay(100)
        elseif gui.stickBehind then
            if mq.TLO.Navigation.Active() then
                mq.cmd('/nav stop')
                mq.delay(100)
            end
            mq.cmd("/stick moveback 0")
            mq.delay(100)
            mq.cmdf("/stick behind %d uw", gui.stickDistance)
            mq.delay(100)
        end

        while mq.TLO.Target() and mq.TLO.Target.Distance() > gui.stickDistance and mq.TLO.Stick() == "ON" do
            mq.delay(10)
        end

        if mq.TLO.Target() and not mq.TLO.Target.Mezzed() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange and not mq.TLO.Me.Combat() then
            mq.cmd("/squelch /attack on")
        elseif mq.TLO.Target() and (mq.TLO.Target.Mezzed() or mq.TLO.Target.PctHPs() > gui.assistPercent or mq.TLO.Target.Distance() > (gui.assistRange + 30)) and mq.TLO.Me.Combat() then
            mq.cmd("/squelch /attack off")
        end
    end

    if mq.TLO.Target() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange and mq.TLO.Stick() == "ON" and not mq.TLO.Target.Mezzed() and not mq.TLO.Me.Combat() then
        mq.cmd("/squelch /attack on")
    end

    while mq.TLO.Me.CombatState() == "COMBAT" and mq.TLO.Target() and not mq.TLO.Target.Dead() do

        if not gui.botOn and not gui.assistOn then
            return
        end

        if gui.switchWithMA then
            mq.cmd("/squelch /assist %s", gui.mainAssist)
        end

        -- Re-check the target after assisting to confirm it's an NPC within range
        if not mq.TLO.Target() or (mq.TLO.Target() and mq.TLO.Target.Type() ~= "NPC") then
            debugPrint("No target or target is not an NPC.")
            return
        end

        if mq.TLO.Target() and not mq.TLO.Target.Mezzed() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange then
            mq.cmd("/squelch /attack on")
        elseif mq.TLO.Target() and (mq.TLO.Target.Mezzed() or mq.TLO.Target.PctHPs() > gui.assistPercent or mq.TLO.Target.Distance() > (gui.assistRange + 30)) then
            mq.cmd("/squelch /attack off")
        end

        if gui.feignAggro then
            local feigndeath = "Feign Death"
            if mq.TLO.Target() and gui.feignAggro and mq.TLO.Me.AbilityReady(feigndeath) and mq.TLO.Me.PctAggro() >= 80 and mq.TLO.Target.Distance() <= gui.assistRange and not mq.TLO.Navigation.Active() then
                mq.cmdf('/doability %s', feigndeath)
                while mq.TLO.Me.PctAggro() > 80 and mq.TLO.Target.AggroHolder() do
                    mq.delay(10)
                end
                mq.cmd("/squelch /stand")
                mq.delay(100)
                mq.cmd("/squelch /attack on")
            end
        end

        if gui.useMend then
            local mend = "Mend"
            if mq.TLO.Me.PctHPs() < 50 and mq.TLO.Me.AbilityReady(mend) and charLevel >= 10 then
                mq.cmdf('/squelch /doability %s', mend)
                mq.delay(100)
            end
        end

        local epicbuff = "Celestial Tranquility"
        local epic = "Celestial Fists"
        if gui.useEpic and not mq.TLO.Me.Buff(epicbuff)() then
            mq.cmdf('/squelch /useitem %s', epic)
            mq.delay(100)
        end

        if mq.TLO.Target() and mq.TLO.Target.Distance() <= gui.assistRange then

            local kick = "Kick"
            local tigerClaw = "Tiger Claw"
            local flyingKick = "Flying Kick"

            if mq.TLO.Target() and mq.TLO.Me.AbilityReady(kick) and (charLevel >= 1 and charLevel < 30) then
                mq.cmdf('/squelch /doability %s', kick)
                mq.delay(100)
            end
            if mq.TLO.Target() and mq.TLO.Me.AbilityReady(tigerClaw) and charLevel >= 10 then
                mq.cmdf('/squelch /doability %s', tigerClaw)
                mq.delay(100)
            end
            if mq.TLO.Target() and mq.TLO.Me.AbilityReady(flyingKick) and charLevel >= 30 then
                mq.cmdf('/squelch /doability %s', flyingKick)
                mq.delay(100)
            end
        end

        local lastStickDistance = nil

        if mq.TLO.Target() and mq.TLO.Stick.Active() then
            local stickDistance = gui.stickDistance -- current GUI stick distance
            local lowerBound = stickDistance * 0.9
            local upperBound = stickDistance * 1.1
            local targetDistance = mq.TLO.Target.Distance()
            
            -- Check if stickDistance has changed
            if lastStickDistance ~= stickDistance then
                lastStickDistance = stickDistance
                mq.cmdf("/squelch /stick moveback %s", stickDistance)
            end
    
            -- Check if the target distance is out of bounds and adjust as necessary
            if mq.TLO.Target.ID() then
                if targetDistance > upperBound then
                    mq.cmdf("/squelch /stick moveback %s", stickDistance)
                    mq.delay(100)
                elseif targetDistance < lowerBound then
                    mq.cmdf("/squelch /stick moveback %s", stickDistance)
                    mq.delay(100)
                end
            end
        end

        if mq.TLO.Me.Combat() and not mq.TLO.Stick() then
            mq.cmd("/squelch /attack off")
        end

        if mq.TLO.Target() and mq.TLO.Target.Dead() or not mq.TLO.Target() then
            mq.cmd("/squelch /attack off")
            return
        end

    mq.delay(50)
    end
end

return assist