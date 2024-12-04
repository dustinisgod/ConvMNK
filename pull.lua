local mq = require('mq')
local gui = require('gui')
local utils = require('utils')
local nav = require('nav')

local DEBUG_MODE = false
-- Debug print helper function
local function debugPrint(...)
    if DEBUG_MODE then
        print(...)
    end
end

local pull = {}

local pullQueue = {}
local campQueue = {}
local aggroQueue = {}  -- New queue to track mobs on their way to camp
local campQueueCount = 0  -- Variable to track the number of mobs in campQueue

local pullability = "376"
local cannotSeeFlag = false

local messagePrintedFlags = {
    CLR = false,
    DRU = false,
    SHM = false,
    ENC = false
}
local pullPauseTimer = os.time()  -- Initialize with the current time

local function atan2(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function calculateHeadingTo(targetY, targetX)
    if not targetY or not targetX then
        print("calculateHeadingTo: Invalid target coordinates", targetY, targetX)
        return nil
    end

    local playerY = mq.TLO.Me.Y()
    local playerX = mq.TLO.Me.X()

    if not playerY or not playerX then
        print("calculateHeadingTo: Invalid player coordinates")
        return nil
    end

    local deltaY = targetY - playerY
    local deltaX = targetX - playerX
    local heading = math.deg(atan2(deltaX, deltaY))

    if heading < 0 then heading = heading + 360 end
    return heading
end

local function cannotSeeTarget(line)
    debugPrint("Event Triggered: You cannot see your target.")
    mq.cmd('/echo Event Triggered: You cannot see your target.')
    cannotSeeFlag = true
end

mq.event('CannotSeeTarget', 'You cannot see your target.', cannotSeeTarget)

-- Define a predicate function that checks if the spawn is an NPC
local function isNPC(spawn)
    return spawn.Type() == 'NPC' and spawn.Distance() <= gui.pullDistanceXY
end

local function updatePullQueue()
    debugPrint("Updating pullQueue...")
    pullQueue = {}
    campQueue = utils.referenceLocation(gui.campSize) or {}

    -- Predefined heading ranges
    local headingRanges = {}
    if gui.pullNorth then table.insert(headingRanges, {min = 315, max = 45}) end
    if gui.pullWest then table.insert(headingRanges, {min = 45, max = 135}) end
    if gui.pullSouth then table.insert(headingRanges, {min = 135, max = 225}) end
    if gui.pullEast then table.insert(headingRanges, {min = 225, max = 315}) end

    if #headingRanges == 0 then
        table.insert(headingRanges, {min = 0, max = 360}) -- Default to all headings
    end

    local function isHeadingValid(heading)
        for _, range in ipairs(headingRanges) do
            if range.min <= range.max then
                if heading >= range.min and heading <= range.max then
                    return true
                end
            else -- Handle wrap-around cases
                if heading >= range.min or heading <= range.max then
                    return true
                end
            end
        end
        return false
    end

    -- Pull configuration parameters
    local pullDistanceXY = gui.pullDistanceXY
    local pullDistanceZ = gui.pullDistanceZ
    local pullLevelMin = gui.pullLevelMin
    local pullLevelMax = gui.pullLevelMax

    -- Retrieve all spawns
    local allSpawns = mq.getFilteredSpawns(isNPC)
    local shortestPathLength = math.huge
    local bestTarget = nil

    for _, spawn in ipairs(allSpawns) do
        local targetY = spawn.Y() or mq.TLO.Spawn("id " .. spawn.ID()).Y()
        local targetX = spawn.X() or mq.TLO.Spawn("id " .. spawn.ID()).X()

        -- Skip spawns with invalid coordinates
        if not targetY or not targetX then
            debugPrint("Skipping spawn due to invalid coordinates:", spawn.Name() or "Unnamed")
            goto continue
        end

        -- Calculate heading to the spawn
        local headingToSpawn = calculateHeadingTo(targetY, targetX)
        if not headingToSpawn then
            debugPrint("Skipping spawn due to heading calculation failure:", spawn.Name() or "Unnamed")
            goto continue
        end

        -- Validate against campQueue
        local alreadyInCampQueue = false
        for _, campMob in ipairs(campQueue) do
            if campMob.ID() == spawn.ID() then
                alreadyInCampQueue = true
                break
            end
        end
        if alreadyInCampQueue then
            debugPrint("Skipping spawn already in campQueue:", spawn.Name())
            goto continue
        end

        -- Validate against aggroQueue
        local alreadyInAggroQueue = false
        for _, aggroMob in ipairs(aggroQueue) do
            if aggroMob.ID() == spawn.ID() then
                alreadyInAggroQueue = true
                break
            end
        end
        if alreadyInAggroQueue then
            debugPrint("Skipping spawn already in aggroQueue:", spawn.Name())
            goto continue
        end

        local mobID = spawn.ID()
        local mobName = mq.TLO.Spawn(mobID).CleanName()
        -- Check if spawn's name is in the pull ignore list
        if utils.pullConfig[mq.TLO.Zone.ShortName()] and utils.pullConfig[mq.TLO.Zone.ShortName()][mobName] then
            debugPrint("Skipping spawn due to pullConfig exclusion:", mobName)
            goto continue
        end

        -- Validate heading range
        if not isHeadingValid(headingToSpawn) then
            goto continue
        end

        -- Validate against pull conditions
        local distanceXY = spawn.Distance()
        local distanceZ = spawn.DistanceZ()
        local level = spawn.Level()

        if spawn.Type() == "NPC" and
           level >= pullLevelMin and level <= pullLevelMax and
           distanceXY <= pullDistanceXY and distanceZ <= pullDistanceZ then
            local pathLength = mq.TLO.Navigation.PathLength("id " .. spawn.ID())()
            if pathLength and pathLength > -1 and pathLength < shortestPathLength then
                bestTarget = spawn
                shortestPathLength = pathLength
            end
        end

        ::continue::
    end

    -- Add the best target to the pullQueue if it meets conditions
    if bestTarget then
        table.insert(pullQueue, bestTarget)
        debugPrint("Best target added to pullQueue:", bestTarget.Name(), "Path Length:", shortestPathLength)
    else
        debugPrint("No suitable target found for pulling.")
    end

    -- Sort pullQueue by distance
    table.sort(pullQueue, function(a, b) return a.Distance() < b.Distance() end)
    debugPrint("Updated pullQueue:", #pullQueue)
end

local function returnToCampIfNeeded()
    -- Check if camp location is set
    if nav.campLocation then
        -- Retrieve player and camp coordinates
        local playerX, playerY, playerZ = mq.TLO.Me.X(), mq.TLO.Me.Y(), mq.TLO.Me.Z()
        local campX = tonumber(nav.campLocation.x) or 0
        local campY = tonumber(nav.campLocation.y) or 0
        local campZ = tonumber(nav.campLocation.z) or 0

        -- Calculate distance to camp
        local distanceToCamp = math.sqrt((playerX - campX)^2 + (playerY - campY)^2 + (playerZ - campZ)^2)

        -- Navigate back to camp if beyond threshold
        if distanceToCamp > gui.campDistance then
            mq.cmdf("/squelch /nav loc %f %f %f", campY, campX, campZ)
            while mq.TLO.Navigation.Active() do
                mq.delay(10)
            end
            mq.cmd("/face fast")  -- Face camp direction after reaching camp
            mq.delay(100)
            if mq.TLO.Target() and mq.TLO.Target.PctAggro() > 0 then
                while mq.TLO.Target() and mq.TLO.Target.Distance() > gui.campSize and mq.TLO.Target.PctAggro() == 100 do
                    mq.delay(10)
                end
                return
            end

        else
            debugPrint("Player is within camp distance.")
            return
        end
    else
        print("Camp location is not set. Cannot return to camp.")
        return
    end
end

local function updateAggroQueue()
    -- Retrieve mobs within the camp assist range
    local campMobs = utils.referenceLocation(gui.campSize) or {}

    -- Iterate through aggroQueue in reverse to handle removals
    for i = #aggroQueue, 1, -1 do
        local mobID = aggroQueue[i]
        local mob = mq.TLO.Spawn(mobID)  -- Retrieve mob spawn from ID

        -- Check if mob exists and is alive
        if not mob or not mob() or mob.Dead() then
            table.remove(aggroQueue, i)  -- Remove dead or nonexistent mob
        else
            -- Target the mob to check aggro
            mq.cmdf("/squelch /target id %d", mobID)
            mq.delay(10)  -- Small delay to allow targeting

            -- Verify mob is still the target and has aggro
            if mq.TLO.Target.ID() ~= mobID then
                table.remove(aggroQueue, i)  -- Remove if target doesn't match
            elseif mq.TLO.Target() and mq.TLO.Target.PctAggro() == 0 or not mq.TLO.Target.AggroHolder() then
                table.remove(aggroQueue, i)  -- Remove if no aggro
            else
                -- Check if mob is within the camp assist range
                local inCamp = false
                for _, campMob in ipairs(campMobs) do
                    if campMob.ID() == mobID then
                        inCamp = true
                        break
                    end
                end

                -- Handle mob positioning relative to camp range
                if not inCamp and mob.Distance() and tonumber(mob.Distance()) <= 5 then
                    -- Mob is close but outside camp range (no specific action needed here)
                elseif inCamp then
                    table.insert(campQueue, mob)  -- Add mob to camp queue
                    table.remove(aggroQueue, i)  -- Remove from aggroQueue
                end
            end
        end
    end
end

local function pullTarget()
    debugPrint("Pulling target...")
    if #pullQueue == 0 then
        debugPrint("No targets in pullQueue. Exiting pull routine.")
        return
    end

    local target = pullQueue[1]
    if not target or not target.ID then
        debugPrint("Invalid target. Exiting pull routine.")
        return
    end

    local targetID = target.ID()
    debugPrint("Target:", target.Name())

    -- Clear attack and target the mob
    mq.cmd("/squelch /attack off")
    mq.delay(100)
    mq.cmdf("/squelch /target id %d", targetID)
    mq.delay(200, function() return mq.TLO.Target() and mq.TLO.Target.ID() == targetID end)

    -- Validate target selection
    if not mq.TLO.Target() or mq.TLO.Target.ID() ~= targetID then
        debugPrint("Target is not selected. Exiting pull routine.")
        return
    end

    -- Check if the target is mezzed and within camp size + buffer
    if mq.TLO.Target() and mq.TLO.Target.Mezzed() and mq.TLO.Target.Distance() <= (gui.campSize + 20) then
        debugPrint("Target is mezzed. Adding target to campQueue:", target.Name())
        table.insert(campQueue, target)
        table.remove(pullQueue, 1)
        return
    end

    -- Pull logic: Check line of sight, range, and use ability
    local function tryPullAbility()
        if mq.TLO.Me.AltAbilityReady(pullability) then
            debugPrint("Pulling target:", target.Name(), "with ability:", pullability)
            mq.cmdf("/squelch /alt act %s", pullability)
            mq.delay(300)
            mq.doevents()
        end
    end

    local function handleAggro()
        debugPrint("Adding target to aggroQueue: ", targetID)
        table.insert(aggroQueue, targetID)
        debugPrint("Removing target from pullQueue: ", target.Name())
        table.remove(pullQueue, 1)
        returnToCampIfNeeded()
    end

    if mq.TLO.Target() and mq.TLO.Target.Distance() <= 150 and mq.TLO.Target.LineOfSight() then
        debugPrint("First Check. Target is in line of sight and within range.")
        tryPullAbility()
        debugPrint(mq.TLO.Me.PctAggro())
        if mq.TLO.Target() and mq.TLO.Target.PctAggro() > 0 then
            debugPrint("Target has aggro. Adding to aggroQueue 1.")
            handleAggro()
            debugPrint("Exiting pull routine.1")
            return
        end
    end

    -- Navigation logic if the target is not in line of sight
    if not mq.TLO.Navigation.Active() then
        debugPrint("Navigating to target:", mq.TLO.Target.Name())
        mq.cmdf("/squelch /nav id %d", targetID)
        mq.delay(10, function() return mq.TLO.Navigation.Active() end)
    end

    -- While navigating, continue checks for target in range and line of sight
    while mq.TLO.Navigation.Active() do
        if not gui.botOn or not gui.pullOn then
            debugPrint("Bot is off. Stopping navigation and exiting pull routine.")
            if mq.TLO.Navigation.Active() then
                debugPrint("Stopping navigation.")
                mq.cmd("/squelch /nav stop")
            end
            return
        end

        if mq.TLO.Target() and mq.TLO.Target.Distance() <= 150 and mq.TLO.Target.LineOfSight() then
            debugPrint("Target is in line of sight and within range during navigation.")
            tryPullAbility()
            debugPrint(mq.TLO.Me.PctAggro())
            if mq.TLO.Target() and mq.TLO.Target.PctAggro() > 0 then
                debugPrint("Target has aggro. Adding to aggroQueue 2.")
                handleAggro()
                debugPrint("Exiting pull routine.2")
                return
            end
        end
        mq.delay(10)
    end

    -- Final aggro check after navigation completes
    if mq.TLO.Target() and mq.TLO.Target.Distance() <= 150 and mq.TLO.Target.LineOfSight() then
        debugPrint("Final check: Target is in line of sight and within range.")
        tryPullAbility()
        debugPrint(mq.TLO.Me.PctAggro())
        if mq.TLO.Target() and mq.TLO.Target.PctAggro() > 0 then
            debugPrint("Target has aggro. Adding to aggroQueue 3.")
            handleAggro()
            debugPrint("Exiting pull routine.3")
            return
        end
    end
end

local function isGroupMemberAliveAndSufficientMana(classShortName, manaThreshold)
    for i = 0, 5 do
        local member = mq.TLO.Group.Member(i)
        if member() and member.Class.ShortName() == classShortName then
            local isAlive = member.PctHPs() > 0
            local sufficientMana = member.PctMana() >= manaThreshold
            
            -- Reset flag if status has improved (e.g., they are alive and have sufficient mana)
            if isAlive and sufficientMana and messagePrintedFlags[classShortName] then
                messagePrintedFlags[classShortName] = false
            end
            
            return isAlive and sufficientMana
        end
    end
    return true
end

local function checkGroupMemberStatus()
    if gui.groupWatch then
        if gui.groupWatchCLR and not isGroupMemberAliveAndSufficientMana("CLR", gui.groupWatchCLRMana) then
            if not messagePrintedFlags["CLR"] then
                print("Cleric is either dead or low on mana. Pausing pull.")
                messagePrintedFlags["CLR"] = true
            end
            return false
        end
        if gui.groupWatchDRU and not isGroupMemberAliveAndSufficientMana("DRU", gui.groupWatchDRUMana) then
            if not messagePrintedFlags["DRU"] then
                print("Druid is either dead or low on mana. Pausing pull.")
                messagePrintedFlags["DRU"] = true
            end
            return false
        end
        if gui.groupWatchSHM and not isGroupMemberAliveAndSufficientMana("SHM", gui.groupWatchSHMMana) then
            if not messagePrintedFlags["SHM"] then
                print("Shaman is either dead or low on mana. Pausing pull.")
                messagePrintedFlags["SHM"] = true
            end
            return false
        end
        if gui.groupWatchENC and not isGroupMemberAliveAndSufficientMana("ENC", gui.groupWatchENCMana) then
            if not messagePrintedFlags["ENC"] then
                print("Enchanter is either dead or low on mana. Pausing pull.")
                messagePrintedFlags["ENC"] = true
            end
            return false
        end
    end
    return true
end

local shownMessage = false  -- Flag to track if the message has been shown

-- Main check function to run periodically
local function checkHealthAndBuffAndAssist()
    local hasRezSickness = mq.TLO.Me.Buff("Revival Sickness")()
    local healthPct = mq.TLO.Me.PctHPs()
    local rooted = mq.TLO.Me.Rooted()
    local deadMA = mq.TLO.Spawn(gui.mainAssist).Dead()
    local maID = tostring(mq.TLO.Spawn(gui.mainAssist).ID())

    if healthPct < 70  then
        if not shownMessage then
            print("Cannot pull: Health is below 70%.")
            shownMessage = true
        end
        return false
    elseif hasRezSickness == "Revival Sickness" then
        if not shownMessage then
            print("Cannot pull: Revival Sickness is active.")
            shownMessage = true
        end
        return false
    elseif rooted then
        if not shownMessage then
            print("Cannot pull: Rooted.")
            shownMessage = true
        end
        return false
    elseif deadMA then
        if not shownMessage then
            print("Cannot pull: Main assist is dead.")
            shownMessage = true
        end
        return false
    elseif maID == "0" then
        if not shownMessage then
            print("Cannot pull: Main assist does not exist.")
            shownMessage = true
        end
        return false
    else
        shownMessage = false
        return true
    end
end

local function pullRoutine()
    debugPrint("Running pull routine...")

    if not gui.botOn and gui.pullOn then
        debugPrint("Bot is off. Exiting pull routine.")
        return
    end

    if not checkHealthAndBuffAndAssist() then
        debugPrint("Health, buffs, or main assist status is not OK. Exiting pull routine.")
        return
    end

    if gui.pullPause and os.difftime(os.time(), pullPauseTimer) >= (gui.pullPauseTimer * 60) then
        if utils.isInCamp() then
            print("Pull routine paused for " .. gui.pullPauseDuration .. " minutes.")
            mq.delay(gui.pullPauseDuration * 60 * 1000)  -- Pause timer

            aggroQueue = {}
            updateAggroQueue()

            pullPauseTimer = os.time()  -- Reset the timer
        end
    end

    if not nav.campLocation or not nav.campLocation.zone or nav.campLocation.zone == "nil" then
        debugPrint("nav.campLocation: ", nav.campLocation and nav.campLocation.zone)
        print("Camp location is not set. Aborting pull routine.")
        return
    end

    local zone = mq.TLO.Zone.ShortName()
    if zone ~= nav.campLocation.zone then
        print("Current zone does not match camp zone. Aborting pull routine.")
        return
    end

    campQueue = utils.referenceLocation(gui.campSize) or {}
    campQueueCount = #campQueue
    debugPrint("CampQueue count:", campQueueCount)

    aggroQueue = aggroQueue or {}
    updateAggroQueue()

    -- Add new logic to process mobs in the aggro queue
    while #aggroQueue > 0 do
        debugPrint("Processing aggroQueue. Waiting for mobs to enter camp radius.")
        for i = #aggroQueue, 1, -1 do
            local mobID = aggroQueue[i]
            local mob = mq.TLO.Spawn("id " .. mobID)
            if mob and mob.Distance() <= gui.campSize then
                debugPrint("Mob", mob.Name(), "has entered camp radius. Moving to campQueue.")
                table.insert(campQueue, {Name = mob.Name(), ID = mob.ID()})
                for i, id in ipairs(aggroQueue) do
                    if id == mobID then
                        table.remove(aggroQueue, i)
                        break
                    end
                end
            end
        end

        -- Wait briefly before re-checking aggro queue
        mq.delay(100)
        updateAggroQueue() -- Ensure the aggro queue is updated
    end

    -- Continue the pull routine
    local targetCampAmount = gui.keepMobsInCampAmount or 1

    local pullCondition
    if gui.keepMobsInCamp then
        debugPrint("Pulling until campQueue reaches target amount:", targetCampAmount)
        pullCondition = function() return campQueueCount < targetCampAmount and #aggroQueue == 0 end
    else
        debugPrint("Pulling until campQueue is empty and aggroQueue is empty.")
        pullCondition = function() return campQueueCount == 0 and #aggroQueue == 0 end
    end

    while pullCondition() do
        if not gui.pullOn then
            debugPrint("Pull routine stopped.")
            return
        end

        updatePullQueue()

        local groupStatusOk = checkGroupMemberStatus()
        if not groupStatusOk then
            debugPrint("Group status is not OK. Pausing pull routine.")
            break
        end

        debugPrint("PullQueue count:", #pullQueue)
        if #pullQueue > 0 then
            pullTarget()

            campQueue = utils.referenceLocation(gui.campSize) or {}
            campQueueCount = #campQueue

            updateAggroQueue()
        else
            debugPrint("No targets found in pullQueue.")
            break
        end
    end
end

return {
    pull = pull,
    updatePullQueue = updatePullQueue,
    pullRoutine = pullRoutine,
    pullQueue = pullQueue,
    campQueue = campQueue,
    aggroQueue = aggroQueue,
    campQueueCount = campQueueCount
}