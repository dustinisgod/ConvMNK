local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local pull = require('pull')

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
    if not mq.TLO.Target() or mq.TLO.Target.Type() ~= "NPC" then
        return
    end

    if mq.TLO.Target() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange and mq.TLO.Stick() == "OFF" and not mq.TLO.Target.Mezzed() then
        if gui.stickFront then
            mq.cmd('/nav stop')
            mq.delay(100)
            mq.cmd("/stick moveback 0")
            mq.delay(100)
            mq.cmdf("/stick front %d uw", gui.stickDistance)
            mq.delay(100)
        elseif gui.stickBehind then
            mq.cmd('/nav stop')
            mq.delay(100)
            mq.cmd("/stick moveback 0")
            mq.delay(100)
            mq.cmdf("/stick behind %d uw", gui.stickDistance)
            mq.delay(100)
        end

        while mq.TLO.Target() and mq.TLO.Target.Distance() > gui.stickDistance and mq.TLO.Stick() == "ON" do
            mq.delay(10)
        end

        if mq.TLO.Target() and not mq.TLO.Target.Mezzed() and mq.TLO.Target.PctHPs() <= gui.assistPercent and mq.TLO.Target.Distance() <= gui.assistRange then
            mq.cmd("/squelch /attack on")
        elseif mq.TLO.Target() and (mq.TLO.Target.Mezzed() or mq.TLO.Target.PctHPs() > gui.assistPercent or mq.TLO.Target.Distance() > (gui.assistRange + 30)) then
            mq.cmd("/squelch /attack off")
        end
    end

    if mq.TLO.Me.CombatState() == "COMBAT" and mq.TLO.Target() and mq.TLO.Target.Dead() ~= ("true" or "nil") then

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

        if mq.TLO.Target() and mq.TLO.Target.Distance() <= gui.assistRange then

            local kick = "Kick"
            local tigerClaw = "Tiger Claw"
            local flyingKick = "Flying Kick"

            if mq.TLO.Me.AbilityReady(kick) and (charLevel >= 1 and charLevel < 30) then
                mq.cmdf('/squelch /doability %s', kick)
                mq.delay(100)
            end
            if mq.TLO.Me.AbilityReady(tigerClaw) and charLevel >= 10 then
                mq.cmdf('/squelch /doability %s', tigerClaw)
                mq.delay(100)
            end
            if mq.TLO.Me.AbilityReady(flyingKick) and charLevel >= 30 then
                mq.cmdf('/squelch /doability %s', flyingKick)
                mq.delay(100)
            end
        end

        if mq.TLO.Target() and mq.TLO.Stick() == "ON" then
            local stickDistance = gui.stickDistance
            local lowerBound = 5
            local targetDistance = mq.TLO.Target.Distance()
        
            if targetDistance > stickDistance then
                mq.cmdf("/stick moveback %s", stickDistance)
                mq.delay(100)
                
            elseif targetDistance < lowerBound then
                mq.cmdf("/stick moveback %s", stickDistance)
                mq.delay(100)
            end
        end
    
    mq.delay(50)
    end
end

return assist