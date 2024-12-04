local mq = require('mq')
local gui = require('gui')
local nav = require('nav')

local DEBUG_MODE = false

-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local corpsedrag = {}

local function returnToCampIfNeeded()
    local utils = require('utils')
    if nav.campLocation then
        -- Retrieve player and camp coordinates
        local playerX, playerY, playerZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
        local campX = tonumber(nav.campLocation.x) or 0
        local campY = tonumber(nav.campLocation.y) or 0
        local campZ = tonumber(nav.campLocation.z) or 0

        -- Calculate distance to camp
        local distanceToCamp = math.sqrt((playerX - campX)^2 + (playerY - campY)^2 + (playerZ - campZ)^2)

        -- Navigate back to camp if beyond threshold
        if distanceToCamp > 50 then
            mq.cmdf("/squelch /nav loc %f %f %f", campY, campX, campZ)
            while mq.TLO.Navigation.Active() do
                mq.delay(50)
            end
            mq.cmd("/face fast")  -- Face camp direction after reaching camp
        end
    end
end

function corpsedrag.corpsedragRoutine()
    if not gui.botOn then
        debugPrint("Bot is not active. Exiting routine.")
        return
    end

    if not gui.corpsedrag and (not gui.returntocamp or not nav.campLocation) then
        debugPrint("Corpsedrag is off, and no return to camp configured. Exiting routine.")
        return
    end

    debugPrint("Starting corpse drag routine.")

    -- Helper to find dead members
    local function getDeadMembers()
        local deadMembers = {}

        -- Check raid members
        if mq.TLO.Raid.Members() > 0 then
            debugPrint("Raid members found.")
            for i = 1, mq.TLO.Raid.Members() do
                local member = mq.TLO.Raid.Member(i)
                if member then
                    local memberName = member.Name()
                    if memberName and mq.TLO.Spawn(memberName)() and mq.TLO.Spawn(memberName).Dead() then
                        debugPrint("Found dead raid member: ", memberName)
                        table.insert(deadMembers, memberName)
                    end
                end
            end
        elseif mq.TLO.Group.Members() > 0 then
            debugPrint("Group members found.")
            for i = 0, mq.TLO.Group.Members() - 1 do
                local member = mq.TLO.Group.Member(i)
                if member then
                    local memberName = member.Name()
                    if memberName and mq.TLO.Spawn(memberName)() and mq.TLO.Spawn(memberName).Dead() then
                        debugPrint("Found dead group member: ", memberName)
                        table.insert(deadMembers, memberName)
                    end
                end
            end
        end

        return deadMembers
    end

    local deadMembers = getDeadMembers()
    if #deadMembers == 0 then
        debugPrint("No dead members found in group or raid.")
        return
    end

    for _, memberName in ipairs(deadMembers) do
        if not gui.botOn then
            debugPrint("Bot turned off. Exiting routine.")
            return
        end

        debugPrint("Searching for corpse of: ", memberName)
        local corpse = mq.TLO.Spawn(memberName)
        local corpseID = mq.TLO.Spawn(memberName).ID()
        local corpseIDString = tostring(corpseID)
        if not corpse() then
            debugPrint("No corpse found for: ", memberName)
        else
            debugPrint("Corpse found for: ", memberName)

            mq.cmdf('/target id %d', corpseID)
            mq.delay(300)

            if mq.TLO.Target() and corpseID and mq.TLO.Target.ID() == corpseID and mq.TLO.Target.Distance() < 75 then
                return
            elseif mq.TLO.Target() and mq.TLO.Target.Distance() > 75 then
                if mq.TLO.Target() and mq.TLO.Target.ID() == corpseID then
                    if mq.TLO.Navigation.PathExists("id " .. corpseIDString)() then
                        debugPrint("Path found to corpse of: ", memberName)
                        mq.cmdf('/nav id %d', corpseID)
                        while mq.TLO.Target() and mq.TLO.Navigation.Active() and mq.TLO.Target.Distance() > 95 do
                            mq.delay(100)
                        end

                        mq.cmd('/nav stop')
                        debugPrint("Within 100 units of corpse. Dragging corpse of: ", memberName)
                        mq.delay(100)
                        mq.cmd('/corpsedrag')
                        mq.delay(500)

                        if gui.returntocamp then
                            returnToCampIfNeeded()
                        end

                        mq.cmd('/corpsedrop')
                        debugPrint("Dropped corpse of: ", memberName)
                    else
                        debugPrint("No path found to corpse of: ", memberName)
                    end
                else
                    debugPrint("Failed to target corpse of: ", memberName)
                end
            else
                debugPrint("Corpse of: ", memberName, " is in space.")
            end
        end
    end

    debugPrint("Corpse drag routine completed.")
end

return corpsedrag