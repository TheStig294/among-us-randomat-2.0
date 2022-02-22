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
local amongUsMap = game.GetMap() == "ttt_amongusskeld"

-- Plays the impostor kill 'squlech' sound on demand
net.Receive("AmongUsSqulech", function()
    surface.PlaySound("amongus/squlech.mp3")
end)

-- A pop-up message reminder to players that still have emergency meetings left
net.Receive("AmongUsEmergencyMeetingBind", function()
    local ply = LocalPlayer()

    if emergencyMeetingsLeft > 0 and not amongUsMap and ply:Alive() and not ply:IsSpec() then
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
            if amongUsMap and firstPress then
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
    foundweps = 0

    surface.CreateFont("HealthAmmo", {
        font = "Trebuchet24",
        size = 24,
        weight = 750
    })

    -- Adds the taskbar after the among us intro popups are done
    timer.Simple(11, function()
        if amongUsMap then
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

            local text

            -- If on ttt_amongusskeld, say "Tasks done" rather than "Guns to win" to reflect on this map there are actual tasks to do 
            if amongUsMap then
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
    votingList.OnRowSelected = function(_, index, pnl)
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
    shhPopup:SetTitle("")
    shhPopup:MakePopup()
    shhPopup.Paint = function(self, w, h) end
    local image = vgui.Create("DImage", shhPopup)
    image:SetImage("materials/vgui/ttt/amongus/shhhhhhh.png")
    image:SetPos(0, 0)
    image:SetSize(xSize, ySize)

    timer.Simple(4, function()
        surface.PlaySound("amongus/roundbegin.mp3")

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
    surface.PlaySound("amongus/victimkill.mp3")
    victimPopup = vgui.Create("DFrame")
    local xSize = ScrW()
    local ySize = ScrH()
    local pos1 = (ScrW() - xSize) / 2
    local pos2 = (ScrH() - ySize) / 2
    victimPopup:SetPos(pos1, pos2)
    victimPopup:SetSize(xSize, ySize)
    victimPopup:ShowCloseButton(false)
    victimPopup:SetTitle("")
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
    RunConsoleCommand("stopsound")

    timer.Simple(0.1, function()
        surface.PlaySound("amongus/bodyreported.mp3")
    end)

    bodyReportedPopup = vgui.Create("DFrame")
    local xSize = ScrW()
    local ySize = ScrH()
    local pos1 = (ScrW() - xSize) / 2
    local pos2 = (ScrH() - ySize) / 2
    bodyReportedPopup:SetPos(pos1, pos2)
    bodyReportedPopup:SetSize(xSize, ySize)
    bodyReportedPopup:ShowCloseButton(false)
    bodyReportedPopup:SetTitle("")
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
    RunConsoleCommand("stopsound")

    timer.Simple(0.1, function()
        surface.PlaySound("amongus/emergencymeeting.mp3")
    end)

    emergencyMeetingPopup = vgui.Create("DFrame")
    local xSize = ScrW()
    local ySize = ScrH()
    local pos1 = (ScrW() - xSize) / 2
    local pos2 = (ScrH() - ySize) / 2
    emergencyMeetingPopup:SetPos(pos1, pos2)
    emergencyMeetingPopup:SetSize(xSize, ySize)
    emergencyMeetingPopup:ShowCloseButton(false)
    emergencyMeetingPopup:SetTitle("")
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

-- Forces a sound to be the only sound that plays, overriding things like map music, or the 'Ending Flair' randomat from pack 1
net.Receive("AmongUsForceSound", function()
    local sound = net.ReadString()
    if string.StartWith(sound, "amongus/dripmusic") and GetGlobalBool("randomat_amongus_music") == false then return end

    timer.Simple(0.1, function()
        RunConsoleCommand("stopsound")
    end)

    timer.Simple(0.2, function()
        surface.PlaySound(sound)
    end)
end)

-- Adds a sprite around interactable sabotage-ending objects, when a sabotage is activated on ttt_amongusskeld to help players find where they need to go
net.Receive("AmongUsDrawSprite", function()
    local entity = net.ReadString()
    local spriteMaterial = Material("VGUI/ttt/amongus/sabotage")
    local color = Color(0, 0, 0, 150)
    local reactorButtonPosNorth = Vector(-1942.242554, -252.031250, 34.031250)
    local reactorButtonPosSouth = Vector(-1941.859131, -967.968750, 34.031250)
    local o2ButtonPosO2 = Vector(134.000000, -770.500000, 89.000000)
    local o2ButtonPosAdmin = Vector(113.000000, -493.500000, 80.000000)
    local commsButtonPos = Vector(-39.000000, -1548.000000, 78.500000)
    local lightsButtonPos = Vector(-1062.500000, -1041.500000, 95.000000)

    if entity == "reactor" then
        hook.Add("HUDPaint", "AmongUsSpriteReactor", function()
            cam.Start3D()
            render.SetMaterial(spriteMaterial)
            render.DrawSprite(reactorButtonPosNorth, 16, 16, color)
            render.DrawSprite(reactorButtonPosSouth, 16, 16, color)
            cam.End3D()
        end)
    elseif entity == "o2" then
        hook.Add("HUDPaint", "AmongUsSpriteO2", function()
            cam.Start3D()
            render.SetMaterial(spriteMaterial)
            render.DrawSprite(o2ButtonPosO2, 16, 16, color)
            render.DrawSprite(o2ButtonPosAdmin, 16, 16, color)
            cam.End3D()
        end)
    elseif entity == "comms" then
        hook.Add("HUDPaint", "AmongUsSpriteComms", function()
            cam.Start3D()
            render.SetMaterial(spriteMaterial)
            render.DrawSprite(commsButtonPos, 16, 16, color)
            cam.End3D()
        end)
    elseif entity == "lights" then
        hook.Add("HUDPaint", "AmongUsSpriteLights", function()
            cam.Start3D()
            render.SetMaterial(spriteMaterial)
            render.DrawSprite(lightsButtonPos, 16, 16, color)
            cam.End3D()
        end)
    end
end)

net.Receive("AmongUsStopSprite", function()
    local entity = net.ReadString()

    if entity == "reactor" then
        hook.Remove("HUDPaint", "AmongUsSpriteReactor")
    elseif entity == "o2" then
        hook.Remove("HUDPaint", "AmongUsSpriteO2")
    elseif entity == "comms" then
        hook.Remove("HUDPaint", "AmongUsSpriteComms")
    elseif entity == "lights" then
        hook.Remove("HUDPaint", "AmongUsSpriteLights")
    end
end)

-- Removing all hooks are resetting all variables needed to reset at the end of the round
net.Receive("AmongUsEventRoundEnd", function()
    hook.Remove("PlayerBindPress", "AmongUsRandomatBuyMenuDisable")
    hook.Remove("SetupWorldFog", "AmongUsWorldFog")
    hook.Remove("SetupSkyboxFog", "AmongUsSkyboxFog")
    hook.Remove("DrawOverlay", "AmongUsTaskUI")
    hook.Remove("TTTPlayerSpeedModifier", "AmongUsPlayerSpeed")
    hook.Remove("HUDPaint", "AmongUsSpriteReactor")
    hook.Remove("HUDPaint", "AmongUsSpriteO2")
    hook.Remove("HUDPaint", "AmongUsSpriteComms")
    hook.Remove("HUDPaint", "AmongUsSpriteLights")
    emergencyMeetingCalled = false
    firstEmergencyMeetingBindMessage = true
    foundweps = 0
    livefoundweps = 0
    -- Resetting startup popup duration to default
    RunConsoleCommand("ttt_startpopup_duration", tostring(amongUsStartPopupDuration))
end)