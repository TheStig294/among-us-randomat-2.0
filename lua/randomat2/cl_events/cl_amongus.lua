-- Setting variables we'll need at some point
local votingFrame
local votingList
local shhPopup
local victimPopup
local bodyReportedPopup
local emergencyMeetingPopup
local voteFrameDrawn = false
local emergencyMeetingCalled = false
local contextBinding = input.LookupBinding("+menu_context", true)
local useBinding = input.LookupBinding("+use", true)
local firstEmergencyMeetingBindMessage = true
local meeting = false
local foundweps = 0
local livefoundweps = 0
local emergencyMeetingsLeft = 0

-- Plays the impostor kill 'squlech' sound on demand
net.Receive("AmongUsSqulech", function()
    LocalPlayer():EmitSound(Sound("amongus/squlech.mp3"))
end)

-- A pop-up message reminder to players that still have emergency meetings left
net.Receive("AmongUsEmergencyMeetingBind", function()
    local ply = LocalPlayer()

    if emergencyMeetingsLeft > 0 and game.GetMap() ~= "ttt_amongusskeld" and ply:Alive() and not ply:IsSpec() then
        LocalPlayer():ChatPrint("Press '" .. string.upper(contextBinding) .. "' to call an emergency meeting")

        if not firstEmergencyMeetingBindMessage then
            LocalPlayer():PrintMessage(HUD_PRINTCENTER, "Press '" .. string.upper(contextBinding) .. "' to call an emergency meeting")
        end

        firstEmergencyMeetingBindMessage = false
    end
end)

-- An analogue to the sever-side meeting variable, used to prevent an emergency being called during a meeting
net.Receive("AmongUsMeetingCheck", function()
    meeting = true
end)

-- Updates the taskbar when a weapon is found/task complete, different variables to handle when tasks are set to only update when a meeting starts
net.Receive("AmongUsTaskBarUpdate", function()
    if GetGlobalBool("randomat_amongus_taskbar_update") then
        livefoundweps = net.ReadInt(16)
    else
        foundweps = net.ReadInt(16)
    end
end)

-- All functions called when this randomat starts
net.Receive("AmongUsEventBegin", function()
    -- Stopping the TTT role hint box from covering the among us intro images
    amongUsStartPopupDuration = GetConVar("ttt_startpopup_duration"):GetInt()
    RunConsoleCommand("ttt_startpopup_duration", "0")
    emergencyMeetingsLeft = GetGlobalInt("randomat_amongus_emergency_meetings")
    local firstPress = true

    -- Displays a message if the sprint key is pressed while sprinting is disabled 
    -- Handles a player pressing the emergency meeting button 
    hook.Add("PlayerBindPress", "AmongUsRandomatBuyMenuDisable", function(ply, bind, pressed)
        if (string.find(bind, "+menu_context")) then
            if game.GetMap() == "ttt_amongusskeld" and firstPress then
                ply:PrintMessage(HUD_PRINTTALK, "To call an emergency meeting, find the emergency meeting button")
            elseif ply:Alive() == false and firstPress then
                ply:PrintMessage(HUD_PRINTTALK, "Dead people can't call emergency meetings")
            elseif meeting and firstPress then
                ply:PrintMessage(HUD_PRINTTALK, "A meeting is already in progress")
            elseif emergencyMeetingCalled and firstPress then
                ply:PrintMessage(HUD_PRINTTALK, "An emergency meeting has already been called!")
            elseif emergencyMeetingsLeft <= 0 and firstPress then
                ply:PrintMessage(HUD_PRINTTALK, "You are out of emergency meetings")
            elseif emergencyMeetingsLeft > 0 and firstPress then
                emergencyMeetingsLeft = emergencyMeetingsLeft - 1
                ply:PrintMessage(HUD_PRINTCENTER, "Calling an emergency meeting in " .. GetGlobalInt("randomat_amongus_emergency_delay") .. " seconds!")
                ply:PrintMessage(HUD_PRINTTALK, "Calling an emergency meeting in " .. GetGlobalInt("randomat_amongus_emergency_delay") .. " seconds! \nYou have " .. emergencyMeetingsLeft .. " emergency meeting(s) left.")
                net.Start("AmongUsEmergencyMeeting")
                net.SendToServer()
            end

            -- Preventing any print messages from appearing twice when calling for an emergency meeting
            if firstPress then
                firstPress = false
            else
                firstPress = true
            end

            return true
        elseif string.find(bind, "+speed") and GetGlobalBool("randomat_amongus_sprinting") == false then
            ply:PrintMessage(HUD_PRINTCENTER, "Sprinting is disabled")

            return true
        end
    end)

    -- Disabling Sprinting if the convar is enabled
    if GetGlobalBool("randomat_amongus_sprinting") == false then
        hook.Remove("Think", "TTTSprintThink")
        hook.Remove("Think", "TTTSprint4Think")
    end

    -- Limits the player's view distance like in among us, traitors and innocents can have differing view distances (in among us, impostors typically can see further than crewmates)
    hook.Add("SetupWorldFog", "AmongUsWorldFog", function()
        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogColor(0, 0, 0)
        render.FogMaxDensity(1)

        if LocalPlayer():GetRole() == ROLE_INNOCENT then
            render.FogStart(300 * GetGlobalFloat("randomat_amongus_innocent_vision"))
            render.FogEnd(600 * GetGlobalFloat("randomat_amongus_innocent_vision"))
        else
            render.FogStart(300 * GetGlobalFloat("randomat_amongus_traitor_vision"))
            render.FogEnd(600 * GetGlobalFloat("randomat_amongus_traitor_vision"))
        end

        return true
    end)

    -- If a map has a 3D skybox, apply a fog effect to that too
    hook.Add("SetupSkyboxFog", "AmongUsSkyboxFog", function(scale)
        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogColor(0, 0, 0)
        render.FogMaxDensity(1)

        if LocalPlayer():GetRole() == ROLE_INNOCENT then
            render.FogStart(300 * GetGlobalFloat("randomat_amongus_innocent_vision") * scale)
            render.FogEnd(600 * GetGlobalFloat("randomat_amongus_innocent_vision") * scale)
        else
            render.FogStart(300 * GetGlobalFloat("randomat_amongus_traitor_vision") * scale)
            render.FogEnd(600 * GetGlobalFloat("randomat_amongus_traitor_vision") * scale)
        end

        return true
    end)

    -- This net message is also used for updating the taskbar
    local totalwepcount = net.ReadInt(16)

    surface.CreateFont("HealthAmmo", {
        font = "Trebuchet24",
        size = 24,
        weight = 750
    })

    -- Adds the taskbar after the among us intro popups are done
    timer.Simple(11, function()
        if GetGlobalBool("AmongUsTaskDisable") then
            timer.Simple(2, function()
                -- Adds an on-screen message to players telling them how to complete tasks on the special among us map: ttt_amongusskeld
                LocalPlayer():PrintMessage(HUD_PRINTCENTER, "Press '" .. string.upper(useBinding) .. "' on the orange lights to complete tasks!")
                LocalPlayer():ChatPrint("Press '" .. string.upper(useBinding) .. "' on the orange lights to complete tasks!")
            end)
        end

        -- Drawing the taskbar
        hook.Add("DrawOverlay", "AmongUsTaskUI", function()
            if GetGlobalBool("randomat_amongus_taskbar_update") and meeting then
                foundweps = livefoundweps
            end

            local pl = LocalPlayer()
            local text

            -- If on ttt_amongusskeld, say "Tasks done" rather than "Guns to win" to reflect on this map there are actual tasks to do 
            if GetGlobalBool("AmongUsTaskDisable") then
                text = string.format("%i / %02i", foundweps, totalwepcount) .. " Tasks Done"
            else
                text = string.format("%i / %02i", foundweps, totalwepcount) .. " Guns To Win"
            end

            local y = ScrH() - 59

            -- Prevents the taskbar appearing while dead, paused or when tasks are removed
            if LocalPlayer():Alive() and not LocalPlayer():IsSpec() and GetGlobalBool("AmongUsGunWinRemove") == false and gui.IsGameUIVisible() == false then
                local texttable = {}
                texttable.font = "HealthAmmo"
                texttable.color = COLOR_WHITE

                texttable.pos = {135, y + 25}

                texttable.text = text
                texttable.xalign = TEXT_ALIGN_CENTER
                texttable.yalign = TEXT_ALIGN_BOTTOM
                draw.RoundedBox(5, 19.6, y, 233, 28, Color(46, 65, 43, 255))
                draw.RoundedBox(5, 19.6, y, (foundweps / totalwepcount) * 233, 28, Color(67, 216, 68, 255))
                draw.TextShadow(texttable, 2)
            end
        end)
    end)
end)

-- Prevents emergency meetings from being called from multiple players at once, this net message is sent to all clients once someone presses the emergency meeting button
net.Receive("AmongUsEmergencyMeetingCall", function()
    emergencyMeetingCalled = true
end)

-- Handling player voting, most notably, drawing the voting window
net.Receive("AmongUsVoteBegin", function()
    voteFrameDrawn = true
    -- Frame Setup
    votingFrame = vgui.Create("DFrame")
    votingFrame:SetPos(10, ScrH() - 800)
    votingFrame:SetSize(200, 300)
    votingFrame:SetTitle("Hold [Tab] to vote")
    votingFrame:SetDraggable(false)
    votingFrame:ShowCloseButton(false)
    votingFrame:SetVisible(true)
    votingFrame:SetDeleteOnClose(true)
    -- Player List
    votingList = vgui.Create("DListView", votingFrame)
    votingList:Dock(FILL)
    votingList:SetMultiSelect(false)
    votingList:AddColumn("Players")
    votingList:AddColumn("Votes")

    for _, ply in pairs(player.GetAll()) do
        if (ply:Alive() and not ply:IsSpec()) then
            votingList:AddLine(ply:Nick(), 0)
        end
    end

    -- Adding a skip vote option
    votingList:AddLine("[Skip Vote]", 0)

    -- When a player clicks to vote for someone
    votingList.OnRowSelected = function(votingList, index, pnl)
        if LocalPlayer():Alive() and not LocalPlayer():IsSpec() then
            net.Start("AmongUsPlayerVoted")
            net.WriteString(pnl:GetColumnText(1))
            net.SendToServer()
        else
            LocalPlayer():PrintMessage(HUD_PRINTTALK, "Dead people can't vote")
        end
    end

    -- Updating the number of votes for a player when someone votes
    net.Receive("AmongUsPlayerVoted", function()
        local votee = net.ReadString()
        local num = net.ReadInt(32)

        if IsValid(votingList) and num ~= 0 then
            for _, ply in pairs(votingList:GetLines()) do
                if ply:GetColumnText(1) == votee then
                    ply:SetColumnText(2, num)
                end
            end
        end
    end)
end)

-- Removing the voting window when a vote is over and letting everyone's client know an emergency meeting can be called again
net.Receive("AmongUsVoteEnd", function()
    if voteFrameDrawn then
        votingFrame:Close()
        voteFrameDrawn = false
    end

    meeting = false
    emergencyMeetingCalled = false
end)

-- The intro popups shown when the randomat is started, dynamically changes with the number of traitors in the game
net.Receive("AmongUsShhPopup", function()
    local traitorCount = net.ReadUInt(8)
    shhPopup = vgui.Create("DFrame")
    local xSize = ScrW()
    local ySize = ScrH()
    local pos1 = (ScrW() - xSize) / 2
    local pos2 = (ScrH() - ySize) / 2
    shhPopup:SetPos(pos1, pos2)
    shhPopup:SetSize(xSize, ySize)
    shhPopup:ShowCloseButton(false)
    shhPopup:MakePopup()
    shhPopup.Paint = function(self, w, h) end
    local image = vgui.Create("DImage", shhPopup)
    image:SetImage("materials/vgui/ttt/amongus/shhhhhhh.png")
    image:SetPos(0, 0)
    image:SetSize(xSize, ySize)

    timer.Simple(4, function()
        LocalPlayer():EmitSound(Sound("amongus/roundbegin.mp3"))

        -- If there are more than 3 traitors, a generic intro popup is shown (where the number of traitors among us isn't mentioned)
        if traitorCount < 4 then
            if LocalPlayer():GetRole() == ROLE_INNOCENT then
                image:SetImage("materials/vgui/ttt/amongus/crewmate" .. traitorCount .. ".png")
            else
                image:SetImage("materials/vgui/ttt/amongus/impostor" .. traitorCount .. ".png")
            end
        else
            if LocalPlayer():GetRole() == ROLE_INNOCENT then
                image:SetImage("materials/vgui/ttt/amongus/crewmate.png")
            else
                image:SetImage("materials/vgui/ttt/amongus/impostor1.png")
            end
        end

        timer.Simple(5, function()
            shhPopup:Close()
            LocalPlayer():ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 0)
        end)
    end)
end)

-- The popup that is shown when a player is killed by an impostor
net.Receive("AmongUsVictimPopup", function()
    LocalPlayer():EmitSound(Sound("amongus/victimkill.mp3"))
    victimPopup = vgui.Create("DFrame")
    local xSize = ScrW()
    local ySize = ScrH()
    local pos1 = (ScrW() - xSize) / 2
    local pos2 = (ScrH() - ySize) / 2
    victimPopup:SetPos(pos1, pos2)
    victimPopup:SetSize(xSize, ySize)
    victimPopup:ShowCloseButton(false)
    victimPopup:MakePopup()
    victimPopup.Paint = function(self, w, h) end
    local image = vgui.Create("DImage", victimPopup)
    image:SetImage("materials/vgui/ttt/amongus/victimpopup.png")
    image:SetPos(0, 0)
    image:SetSize(xSize, ySize)

    timer.Simple(2, function()
        victimPopup:Close()
    end)
end)

-- The "Body Reported!" popup
net.Receive("AmongUsBodyReportedPopup", function()
    LocalPlayer():EmitSound(Sound("amongus/bodyreported.mp3"))
    bodyReportedPopup = vgui.Create("DFrame")
    local xSize = ScrW()
    local ySize = ScrH()
    local pos1 = (ScrW() - xSize) / 2
    local pos2 = (ScrH() - ySize) / 2
    bodyReportedPopup:SetPos(pos1, pos2)
    bodyReportedPopup:SetSize(xSize, ySize)
    bodyReportedPopup:ShowCloseButton(false)
    bodyReportedPopup:MakePopup()
    bodyReportedPopup.Paint = function(self, w, h) end
    local image = vgui.Create("DImage", bodyReportedPopup)
    image:SetImage("materials/vgui/ttt/amongus/bodyreported.png")
    image:SetPos(0, 0)
    image:SetSize(xSize, ySize)

    timer.Simple(2, function()
        bodyReportedPopup:Close()
    end)
end)

-- The emergency meeting popup
net.Receive("AmongUsEmergencyMeetingPopup", function()
    LocalPlayer():EmitSound(Sound("amongus/emergencymeeting.mp3"))
    emergencyMeetingPopup = vgui.Create("DFrame")
    local xSize = ScrW()
    local ySize = ScrH()
    local pos1 = (ScrW() - xSize) / 2
    local pos2 = (ScrH() - ySize) / 2
    emergencyMeetingPopup:SetPos(pos1, pos2)
    emergencyMeetingPopup:SetSize(xSize, ySize)
    emergencyMeetingPopup:ShowCloseButton(false)
    emergencyMeetingPopup:MakePopup()
    emergencyMeetingPopup.Paint = function(self, w, h) end
    local image = vgui.Create("DImage", emergencyMeetingPopup)
    image:SetImage("materials/vgui/ttt/amongus/emergencymeeting.png")
    image:SetPos(0, 0)
    image:SetSize(xSize, ySize)

    timer.Simple(2, function()
        emergencyMeetingPopup:Close()
    end)
end)

-- Fail-safe to play randomat sounds client-side in case they are muted by the server-side sound mute function
net.Receive("AmongUsForceSound", function()
    local sound = net.ReadString()

    if sound == "emergency" then
        LocalPlayer():EmitSound(Sound("amongus/emergencymeeting.mp3"))
    elseif sound == "traitorwin" then
        LocalPlayer():EmitSound(Sound("amongus/impostorwin.mp3"))
    elseif sound == "innocentwin" then
        LocalPlayer():EmitSound(Sound("amongus/crewmatewin.mp3"))
    elseif sound == "vote" then
        LocalPlayer():EmitSound(Sound("amongus/vote.mp3"))
    elseif sound == "votetext" then
        LocalPlayer():EmitSound(Sound("amongus/votetext.mp3"))
    end
end)

-- Adds a halo around interactable sabotage-ending objects, when a sabotage is activated on ttt_amongusskeld to help players find where they need to go
net.Receive("AmongUsDrawHalo", function()
    local entity = net.ReadString()

    if entity == "o2" then
        hook.Add("PreDrawHalos", "AmongUsHaloO2", function()
            halo.Add({Entity(558), Entity(559)}, Color(0, 255, 0), 0, 0, 1, true, true)
        end)
    elseif entity == "comms" then
        hook.Add("PreDrawHalos", "AmongUsHaloComms", function()
            halo.Add({Entity(566)}, Color(0, 255, 0), 0, 0, 1, true, true)
        end)
    elseif entity == "lights" then
        hook.Add("PreDrawHalos", "AmongUsHaloLights", function()
            halo.Add({Entity(346)}, Color(0, 255, 0), 0, 0, 1, true, true)
        end)
    end
end)

net.Receive("AmongUsStopHalo", function()
    local entity = net.ReadString()

    if entity == "o2" then
        hook.Remove("PreDrawHalos", "AmongUsHaloO2")
    elseif entity == "comms" then
        hook.Remove("PreDrawHalos", "AmongUsHaloComms")
    elseif entity == "lights" then
        hook.Remove("PreDrawHalos", "AmongUsHaloLights")
    end
end)

-- Removing all hooks are resetting all variables needed to reset at the end of the round
net.Receive("AmongUsEventRoundEnd", function()
    hook.Remove("PlayerBindPress", "AmongUsRandomatBuyMenuDisable")
    hook.Remove("SetupWorldFog", "AmongUsWorldFog")
    hook.Remove("SetupSkyboxFog", "AmongUsSkyboxFog")
    hook.Remove("DrawOverlay", "AmongUsTaskUI")
    hook.Remove("TTTPlayerSpeedModifier", "AmongUsPlayerSpeed")
    hook.Remove("PreDrawHalos", "AmongUsHaloReactor")
    hook.Remove("PreDrawHalos", "AmongUsHaloO2")
    hook.Remove("PreDrawHalos", "AmongUsHaloComms")
    hook.Remove("PreDrawHalos", "AmongUsHaloLights")
    emergencyMeetingCalled = false
    firstEmergencyMeetingBindMessage = true
    foundweps = 0
    livefoundweps = 0
    -- Resetting startup popup duration to default
    RunConsoleCommand("ttt_startpopup_duration", tostring(amongUsStartPopupDuration))
end)