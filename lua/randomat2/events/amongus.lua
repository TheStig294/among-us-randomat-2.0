local EVENT = {}
--Not giving randomat a title as it would otherwise interrupt the intro screen
EVENT.Title = ""
EVENT.id = "amongus"
--Giving an AltTitle to be identifiable in the ULX menu
EVENT.AltTitle = "Among Us"
--Preventing this randomat from running at the same time as another that involves voting, and preventing any future randomats that involve voting from triggering
EVENT.Type = EVENT_TYPE_VOTING
--A lot of stuff goes between the client and server in this randomat...
util.AddNetworkString("AmongUsEventBegin")
util.AddNetworkString("AmongUsEventEnd")
util.AddNetworkString("AmongUsPlayerVoted")
util.AddNetworkString("AmongUsInitialHooks")
util.AddNetworkString("AmongUsEventRoundEnd")
util.AddNetworkString("AmongUsEmergencyMeeting")
util.AddNetworkString("AmongUsEmergencyMeetingCall")
util.AddNetworkString("AmongUsSqulech")
util.AddNetworkString("AmongUsShhhhhhhPopup")
util.AddNetworkString("AmongUsVictimPopup")
util.AddNetworkString("AmongUsBodyReportedPopup")
util.AddNetworkString("AmongUsEmergencyMeetingPopup")
util.AddNetworkString("AmongUsEmergencyMeetingBind")
util.AddNetworkString("AmongUsMeetingCheck")
util.AddNetworkString("AmongUsTaskBarUpdate")
util.AddNetworkString("AmongUsForceSound")
util.AddNetworkString("AmongUsDrawHalo")
util.AddNetworkString("AmongUsStopHalo")

--Most of the usual Among Us options, plus more! (change these in the console or via the randomat ULX mod)
CreateConVar("randomat_amongus_voting_timer", 30, {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "Length of voting time in seconds", 0, 300)

CreateConVar("randomat_amongus_discussion_timer", 15, {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "Length of vote discussion time in seconds", 0, 120)

CreateConVar("randomat_amongus_votepct", 0, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Vote percentage required to eject", 0, 100)

CreateConVar("randomat_amongus_freeze", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Freeze players in place while voting", 0, 1)

CreateConVar("randomat_amongus_knife_cooldown", 20, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Traitor knife kill cooldown in seconds", 10, 60)

CreateConVar("randomat_amongus_emergency_delay", 15, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Emergency meeting delay in seconds", 0, 60)

CreateConVar("randomat_amongus_confirm_ejects", 0, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Notify everyone of a player's role when voted out", 0, 1)

CreateConVar("randomat_amongus_emergency_meetings", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "No. of emergency meetings per player", 0, 9)

CreateConVar("randomat_amongus_anonymous_voting", 0, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Anonymous voting", 0, 1)

CreateConVar("randomat_amongus_player_speed", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Player speed multiplier", 0.5, 3)

CreateConVar("randomat_amongus_innocent_vision", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Innocent vision multiplier", 0.2, 5)

CreateConVar("randomat_amongus_traitor_vision", 1.5, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Traitor vision multiplier", 0.2, 5)

CreateConVar("randomat_amongus_taskbar_update", 0, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Only update taskbar at meetings", 0, 1)

CreateConVar("randomat_amongus_auto_trigger", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Trigger every round on special map: ttt_amongusskeld", 0, 1)

CreateConVar("randomat_amongus_task_threshhold", 60, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Seconds until tasks/guns aren't found too quickly", 0, 120)

CreateConVar("randomat_amongus_sprinting", 0, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable sprinting during the randomat", 0, 1)

--Initial tables and variables needed at some point
local playerModels = {}
local playerColors = {}
local remainingColors = {}
local amongusPlayersVoted = {}
local aliveplys = {}
local corpses = {}
local numvoted = 0
local wepspawns = 0
local amongUsFoundWeaponCount = 0
local amongUsMeeting = false
local amongUsRoundOver = true
local amongUsRemoveHurt = false
local emergencyButtonTriggerCount = 0
local playervotes
local votableplayers
local repeater
local repeaterDiscussion
local numaliveplayers
local amongUsMeetingTimeLeft
local AmongUsVotingtimer
local AmongUsDiscussiontimer
local amongUsEmergencyMeeting

--The RGB values for each Among Us player colour as per the Among Us Wiki
local auColors = {
    Red = Color(197, 17, 17),
    Blue = Color(19, 46, 209),
    Green = Color(17, 127, 45),
    Pink = Color(237, 84, 186),
    Orange = Color(239, 125, 14),
    Yellow = Color(246, 246, 88),
    Black = Color(63, 71, 78),
    White = Color(214, 224, 240),
    Purple = Color(107, 49, 188),
    Brown = Color(113, 73, 30),
    Cyan = Color(56, 254, 219),
    Lime = Color(80, 239, 57)
}

function AmongUsVote(findername)
    --Clear anything from a previous vote so current vote has a clean slate
    playervotes = {}
    votableplayers = {}
    table.Empty(aliveplys)
    table.Empty(amongusPlayersVoted)
    repeater = 0
    repeaterDiscussion = 0
    numaliveplayers = 0
    amongUsMeetingTimeLeft = GetGlobalFloat("ttt_round_end") - CurTime()
    amongUsMeeting = true
    net.Start("AmongUsMeetingCheck")
    net.Broadcast()

    --Pause any timers including knife cooldowns of traitors, if currently running
    if timer.Exists("AmongUsRandomatKnifeTimer") then
        timer.Pause("AmongUsRandomatKnifeTimer")
    end

    if timer.Exists("AmongUsRandomatKnifeTimer2") then
        timer.Pause("AmongUsRandomatKnifeTimer2")
    end

    if timer.Exists("AmongUsRandomatKnifeTimer3") then
        timer.Pause("AmongUsRandomatKnifeTimer3")
    end

    if timer.Exists("AmongUsEmergencyMeetingTimer") then
        timer.Pause("AmongUsEmergencyMeetingTimer")
    end

    if timer.Exists("AmongUsTotalWeaponDecrease") then
        timer.Pause("AmongUsTotalWeaponDecrease")
    end

    if timer.Exists("AmongUsPlayTimer") then
        timer.Pause("AmongUsPlayTimer")
    end

    --Updating everyone's taskbar if only update during meetings is enabled
    if GetConVar("randomat_amongus_taskbar_update"):GetBool() then
        net.Start("AmongUsTaskBarUpdate")
        net.WriteInt(amongUsFoundWeaponCount, 16)
        net.Broadcast()
    end

    --Clear any previously tallied votes
    for k, v in pairs(player.GetAll()) do
        if not (v:Alive() and v:IsSpec()) then
            votableplayers[k] = v
            playervotes[v] = 0
        end
    end

    playervotes["[Skip Vote]"] = 0

    --Count the number of players alive, so the vote instantly finishes if everyone has voted
    for k, v in pairs(EVENT:GetAlivePlayers()) do
        PrintMessage(HUD_PRINTTALK, string.upper(v:GetNWString("AmongUsColor", "Unknown")) .. ": " .. v:Nick())
        numaliveplayers = numaliveplayers + 1
    end

    --Get the set voting and discussion time
    AmongUsVotingtimer = GetConVar("randomat_amongus_voting_timer"):GetInt()
    AmongUsDiscussiontimer = GetConVar("randomat_amongus_discussion_timer"):GetInt()

    --Freeze the map and all players in place (if the convar is enabled)
    if GetConVar("randomat_amongus_freeze"):GetBool() then
        for i, ply in pairs(EVENT:GetAlivePlayers(true)) do
            ply:Freeze(true)
            ply:SetMoveType(MOVETYPE_NOCLIP)
            ply:GodEnable()
            ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0, 200), 1, 2)

            timer.Simple(2, function()
                ply:ScreenFade(SCREENFADE.STAYOUT, Color(0, 0, 0, 200), 1, AmongUsVotingtimer + AmongUsDiscussiontimer - 2)
            end)
        end

        RunConsoleCommand("phys_timescale", "0")
        RunConsoleCommand("ragdoll_sleepaftertime", "0")
        amongUsRemoveHurt = true
    end

    --Display body report/emergency meeting popup and sound to all players
    if amongUsEmergencyMeeting == false then
        net.Start("AmongUsBodyReportedPopup")
        net.Broadcast()

        timer.Simple(2, function()
            EVENT:SmallNotify(findername .. " has reported a body. Discuss!")
        end)
    else
        amongUsEmergencyMeeting = false
        net.Start("AmongUsEmergencyMeetingPopup")
        net.Broadcast()

        timer.Simple(2, function()
            EVENT:SmallNotify(findername .. " has called an emergency meeting!")
        end)
    end

    --Delay voting time until discussion time is over
    timer.Create("AmongUsDiscussionTimer", 1, AmongUsDiscussiontimer, function()
        if AmongUsDiscussiontimer ~= 0 then
            repeaterDiscussion = repeaterDiscussion + 1
            PrintMessage(HUD_PRINTCENTER, "Voting starts in " .. AmongUsDiscussiontimer - repeaterDiscussion .. " second(s)")
        end

        --Once discussion time is over, start the vote
        if timer.RepsLeft("AmongUsDiscussionTimer") == 0 then
            --If there is no discussion time, skip the voting has started notification
            if AmongUsDiscussiontimer ~= 0 then
                EVENT:SmallNotify("Voting has begun, hold tab to vote.")
            end

            --Let client know vote has started so vote window can be drawn
            net.Start("AmongUsEventBegin")
            net.Broadcast()

            --Start the timer to end the vote
            timer.Create("votekilltimerAmongUs", 1, 0, function()
                repeater = repeater + 1
                PrintMessage(HUD_PRINTCENTER, AmongUsVotingtimer - repeater .. " second(s) left to vote")

                if AmongUsVotingtimer - repeater == AmongUsVotingtimer / 2 then
                    EVENT:SmallNotify(AmongUsVotingtimer / 2 .. " seconds left on voting!")
                elseif AmongUsVotingtimer - repeater == AmongUsVotingtimer / 4 then
                    EVENT:SmallNotify(AmongUsVotingtimer / 4 .. " seconds left on voting!")
                elseif repeater == AmongUsVotingtimer then
                    AmongUsVoteEnd()
                end
            end)
        end
    end)
end

function AmongUsVoteEnd()
    --Play the Among Us text sound, with a 1 second delay so it doesn't play over the randomat alert sound
    timer.Simple(1, function()
        if not amongUsRoundOver then
            for k, v in pairs(player.GetAll()) do
                v:EmitSound(Sound("amongus/votetext.mp3"))
            end

            net.Start("AmongUsForceSound")
            net.WriteString("votetext")
            net.Broadcast()
        end
    end)

    --Resetting variables from the last vote
    repeater = 0
    repeaterDiscussion = 0
    local votenumber = 0
    emergencyButtonTriggerCount = 0

    --Tally up votes and the players who are alive and can therefore vote
    for k, v in pairs(playervotes) do
        votenumber = votenumber + v
    end

    for k, v in pairs(EVENT:GetAlivePlayers(true)) do
        table.insert(aliveplys, v)
    end

    --If the threshold of votes has been reached...
    if votenumber >= #aliveplys * (GetConVar("randomat_amongus_votepct"):GetInt() / 100) and votenumber ~= 0 then
        --Selects whoever got the most votes to be ejected
        local slainply = table.GetWinningKey(playervotes)
        local winingvotes = playervotes[slainply]
        --Check if there are multiple people with the most votes
        local winingplys = table.KeysFromValue(playervotes, winingvotes)

        --If there is a tie, kill no-one
        if #winingplys > 1 then
            EVENT:SmallNotify("No one was ejected. (Tie)")
            --If there are enough votes to skip
        elseif slainply == "[Skip Vote]" then
            EVENT:SmallNotify("No one was ejected. (Skipped)")
        else
            --If a player was voted for
            slainply:Kill()
            traitorCount = 0

            for i, ply in pairs(EVENT:GetAlivePlayers(true)) do
                if ply:GetRole() == ROLE_TRAITOR then
                    traitorCount = traitorCount + 1
                end
            end

            if GetConVar("randomat_amongus_confirm_ejects"):GetBool() then
                if slainply:GetRole() == ROLE_INNOCENT then
                    if traitorCount ~= 1 then
                        EVENT:SmallNotify(slainply:Nick() .. " was not a Traitor. " .. traitorCount .. " Traitors remain.")
                    else
                        EVENT:SmallNotify(slainply:Nick() .. " was not a Traitor. 1 Traitor remains.")
                    end
                else
                    if traitorCount ~= 1 then
                        EVENT:SmallNotify(slainply:Nick() .. " was a Traitor. " .. traitorCount .. " Traitors remain.")
                    else
                        EVENT:SmallNotify(slainply:Nick() .. " was a Traitor. 1 Traitor remains.")
                    end
                end
            else
                EVENT:SmallNotify(slainply:Nick() .. " was ejected.")
            end
        end
        -- If nobody votes
    elseif votenumber == 0 then
        EVENT:SmallNotify("No one voted. (Skipped)")
    else -- If not enough people vote to pass the configured vote threshold
        EVENT:SmallNotify("Not enough people voted. (Skipped)")
    end

    --Removing all bodies after a vote
    timer.Simple(0.1, function()
        for i = 1, #corpses do
            corpses[i]:Remove()
        end

        table.Empty(corpses)
    end)

    --Cleaning up voting tables and variables for the next vote
    numvoted = 0
    amongUsMeeting = false
    table.Empty(amongusPlayersVoted)
    table.Empty(aliveplys)
    timer.Stop("votekilltimerAmongUs")

    for k, v in pairs(playervotes) do
        playervotes[k] = 0
    end

    --Close the vote window on clients
    net.Start("AmongUsEventEnd")
    net.Broadcast()

    --Resume any timers, e.g. if knives were on cooldown when the vote started
    if timer.Exists("AmongUsRandomatKnifeTimer") then
        timer.UnPause("AmongUsRandomatKnifeTimer")
    end

    if timer.Exists("AmongUsRandomatKnifeTimer2") then
        timer.UnPause("AmongUsRandomatKnifeTimer2")
    end

    if timer.Exists("AmongUsRandomatKnifeTimer3") then
        timer.UnPause("AmongUsRandomatKnifeTimer3")
    end

    if timer.Exists("AmongUsEmergencyMeetingTimer") then
        timer.UnPause("AmongUsEmergencyMeetingTimer")
    end

    if timer.Exists("AmongUsTotalWeaponDecrease") then
        timer.UnPause("AmongUsTotalWeaponDecrease")
    end

    if timer.Exists("AmongUsPlayTimer") then
        timer.UnPause("AmongUsPlayTimer")
    end

    --Unfreeze all players, if convar enabled
    if GetConVar("randomat_amongus_freeze"):GetBool() then
        for i, ply in pairs(EVENT:GetAlivePlayers(true)) do
            ply:Freeze(false)
            ply:SetMoveType(MOVETYPE_WALK)
            ply:GodDisable()
            ply:ScreenFade(SCREENFADE.PURGE, Color(0, 0, 0, 200), 0, 0)
        end

        amongUsRemoveHurt = false
    end

    RunConsoleCommand("phys_timescale", "1")
    RunConsoleCommand("ragdoll_sleepaftertime", "1")

    --Remind players of the emergency meeting keybind in chat after the vote is over
    for k, v in pairs(EVENT:GetAlivePlayers(true)) do
        net.Start("AmongUsEmergencyMeetingBind")
        net.Send(v)
    end
end

-- Convars don't exist on the client... So global variables are used instead
local function AmongUsConVarResync()
    SetGlobalInt("randomat_amongus_voting_timer", GetConVar("randomat_amongus_voting_timer"):GetInt())
    SetGlobalInt("randomat_amongus_discussion_timer", GetConVar("randomat_amongus_discussion_timer"):GetInt())
    SetGlobalInt("randomat_amongus_votepct", GetConVar("randomat_amongus_votepct"):GetInt())
    SetGlobalBool("randomat_amongus_freeze", GetConVar("randomat_amongus_freeze"):GetBool())
    SetGlobalInt("randomat_amongus_knife_cooldown", GetConVar("randomat_amongus_knife_cooldown"):GetInt())
    SetGlobalInt("randomat_amongus_emergency_delay", GetConVar("randomat_amongus_emergency_delay"):GetInt())
    SetGlobalBool("randomat_amongus_confirm_ejects", GetConVar("randomat_amongus_confirm_ejects"):GetBool())
    SetGlobalInt("randomat_amongus_emergency_meetings", GetConVar("randomat_amongus_emergency_meetings"):GetInt())
    SetGlobalBool("randomat_amongus_anonymous_voting", GetConVar("randomat_amongus_anonymous_voting"):GetBool())
    SetGlobalFloat("randomat_amongus_player_speed", GetConVar("randomat_amongus_player_speed"):GetFloat())
    SetGlobalFloat("randomat_amongus_innocent_vision", GetConVar("randomat_amongus_innocent_vision"):GetFloat())
    SetGlobalFloat("randomat_amongus_traitor_vision", GetConVar("randomat_amongus_traitor_vision"):GetFloat())
    SetGlobalBool("randomat_amongus_taskbar_update", GetConVar("randomat_amongus_taskbar_update"):GetBool())
    SetGlobalBool("randomat_amongus_auto_trigger", GetConVar("randomat_amongus_auto_trigger"):GetBool())
    SetGlobalInt("randomat_amongus_task_threshhold", GetConVar("randomat_amongus_task_threshhold"):GetInt())
    SetGlobalBool("randomat_amongus_sprinting", GetConVar("randomat_amongus_sprinting"):GetBool())
end

function EVENT:Begin()
    --Workaround to prevent the end function from being triggered before the begin function, letting know that the randomat has indeed been activated and the randomat end function is now allowed to be run
    amongusRandomat = true
    amongUsRoundOver = false
    local traitorCount = 0
    local traitorCap = 0
    amongUsFoundWeaponCount = 0
    local amongUsPlayTimeCount = 0
    SetGlobalBool("AmongUsGunWinRemove", false)
    SetGlobalBool("AmongUsTasksTooFast", false)
    wepspawns = 0
    emergencyButtonTriggerCount = 0
    AmongUsConVarResync()

    timer.Create("AmongUsPlayTimer", 1, 0, function()
        amongUsPlayTimeCount = amongUsPlayTimeCount + 1
    end)

    --Creating a timer to strip players of any weapons they pick up
    timer.Simple(2, function()
        timer.Create("AmongUsInnocentTask", 0.1, 0, function()
            for _, ply in pairs(self.GetAlivePlayers()) do
                for _, wep in pairs(ply:GetWeapons()) do
                    local class_name = WEPS.GetClass(wep)

                    if class_name ~= "weapon_ttt_impostor_knife_randomat" then
                        ply:StripWeapon(class_name)
                        --Reset FOV to unscope
                        ply:SetFOV(0, 0.2)
                    end
                end
            end
        end)
    end)

    --If on the among us map, the tasks are sprites instead of guns and there are always 14 of them
    if GetGlobalBool("AmongUsTaskDisable") then
        wepspawns = 14
    else
        --Counting the number of weapons on the map for the innocent 'task': pick up all weapons on the map to win
        for _, v in pairs(ents.GetAll()) do
            if (v.Kind == WEAPON_HEAVY or v.Kind == WEAPON_PISTOL or v.Kind == WEAPON_NADE) and v.AutoSpawnable then
                wepspawns = wepspawns + 1
            end
        end

        --Taking away an arbitrary amount of guns to find so players don't have to find ALL of them
        wepspawns = wepspawns - 12
    end

    --Disables sprinting and displays a notification that it's disabled
    --Disables opening the buy menu, which instead triggers an emergency meeting if the player is alive
    --Adds fog to lower the distance players can see
    --Adds the innocent 'task' progress bar
    timer.Simple(2, function()
        net.Start("AmongUsInitialHooks")
        net.WriteInt(wepspawns, 16)
        net.Broadcast()
    end)

    --Kill any players trying to exploit the skip vote button to avoid any weird behaviour
    for k, v in pairs(self:GetAlivePlayers(true)) do
        if v:Nick() == "[Skip Vote]" then
            v:Kill()
            v:ChatPrint("Your Steam nickname is incompatible with this randomat.")
        end
    end

    --Thanks Desmos + Among Us wiki, this number of traitors ensures games do not instantly end with a double kill
    traitorCap = math.floor((player.GetCount() / 2) - 1.5)

    if traitorCap <= 0 then
        traitorCap = 1
    end

    --Setting everyone to either a traitor or innocent, traitors get their 'traitor kill knife'
    for i, ply in pairs(player.GetAll()) do
        if Randomat:IsTraitorTeam(ply) and (traitorCount < traitorCap) then
            Randomat:SetRole(ply, ROLE_TRAITOR)
            traitorCount = traitorCount + 1

            timer.Simple(5, function()
                ply:Give("weapon_ttt_impostor_knife_randomat")
                ply:SelectWeapon("weapon_ttt_impostor_knife_randomat")
                ply:ChatPrint("No-one can see you holding the knife")
            end)
        else
            Randomat:SetRole(ply, ROLE_INNOCENT)
        end
    end

    SendFullStateUpdate()

    --Fades out the screen, freezes players and shows the among us intro pop-ups
    for i, ply in pairs(player.GetAll()) do
        ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0, 255), 1, 2)
        ply:Freeze(true)

        timer.Simple(9, function()
            ply:Freeze(false)
            net.Start("AmongUsEmergencyMeetingBind")
            net.Send(ply)
        end)
    end

    timer.Simple(1.5, function()
        net.Start("AmongUsShhhhhhhPopup")
        net.WriteUInt(traitorCount, 8)
        net.Broadcast()
    end)

    --Adding the colour table to a different table so if more than 12 people are playing, the choosable colours are able to be reset
    remainingColors = {}
    table.Add(remainingColors, auColors)

    -- Gets all players...
    for i, ply in pairs(player.GetAll()) do
        -- if they're alive and not in spectator mode
        if ply:Alive() and not ply:IsSpec() then
            -- and not a bot (bots do not have the following command, so it's unnecessary)
            if (not ply:IsBot()) then
                -- We need to disable cl_playermodel_selector_force, because it messes with SetModel, we'll reset it when the event ends
                ply:ConCommand("cl_playermodel_selector_force 0")
            end

            -- we need to wait a second for cl_playermodel_selector_force to take effect (and THEN change model to the Among Us model)
            timer.Simple(3, function()
                -- Set player number i (in the table) to their respective model, to be restored at the end of the round
                playerModels[i] = ply:GetModel()
                playerColors[i] = ply:GetPlayerColor()
                -- Sets their model to the Among Us model
                ply:SetModel("models/amongus/player/player.mdl")

                -- Resets the choosable colours for everyone's Among Us playermodel if none are left (happens when there are more than 12 players, as there are 12 colours to choose from)
                if remainingColors == {} then
                    table.Add(remainingColors, auColors)
                end

                --Chooses a random colour, prevents it from being chosen by anyone else, and sets the player to that colour
                local randomColor = table.Random(remainingColors)
                table.RemoveByValue(remainingColors, randomColor)
                ply:SetPlayerColor(randomColor:ToVector())
                ply:SetNWString("AmongUsColor", table.KeyFromValue(auColors, randomColor))
                --Makes players able to walk through each other
                ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
                --Sets a bool to check if a player has pressed the emergency meeting button
                ply:SetNWBool("AmongUsPressedEmergencyButton", false)

                --Sets everyone's view height to be lower as the among us playermodel is shorter than a standard playermodel
                timer.Simple(1, function()
                    ply:SetViewOffset(Vector(0, 0, 48))
                    ply:SetViewOffsetDucked(Vector(0, 0, 28))
                end)
            end)
        end
    end

    --If someone kills someone else as a traitor, they receive another knife after a cooldown (as set by the cooldown length convar)
    self:AddHook("PostEntityTakeDamage", function(ent, dmginfo, took)
        local attacker = dmginfo:GetAttacker()

        --First check entity taking damage is a player that took damage...
        if took and attacker ~= nil and ent:IsPlayer() then
            -- ...then check they were killed with a knife attack, as a traitor, where that traitor is alive and the round isn't over
            if (dmginfo:GetInflictor():GetClass() == "weapon_ttt_impostor_knife_randomat") and (attacker:GetRole() == ROLE_TRAITOR) and (attacker:Alive()) and (amongUsRoundOver == false) and (attacker:IsSpec() == false) then
                local cooldown = GetConVar("randomat_amongus_knife_cooldown"):GetInt()
                --Message on screen and in chat on killing someone and playing the kill squlelch sound
                attacker:PrintMessage(HUD_PRINTCENTER, "Knife is on cooldown for " .. cooldown .. " second(s).")
                attacker:ChatPrint("Knife is on cooldown for " .. cooldown .. " second(s).")
                net.Start("AmongUsSqulech")
                net.Send(attacker)

                if ent:IsPlayer() then
                    net.Start("AmongUsVictimPopup")
                    net.Send(ent)
                end

                --Create second timer if other traitor has also made a kill
                if timer.Exists("AmongUsRandomatKnifeTimer") then
                    timer.Create("AmongUsRandomatKnifeTimer2", 1, cooldown, function()
                        --Live onscreen knife cooldown
                        if attacker:Alive() and amongUsRoundOver == false then
                            attacker:PrintMessage(HUD_PRINTCENTER, "Knife is on cooldown for " .. timer.RepsLeft("AmongUsRandomatKnifeTimer2") .. " second(s).")
                        end

                        --Message in chat and giving the knife after the cooldown has completely passed and the traitor is still alive
                        if timer.RepsLeft("AmongUsRandomatKnifeTimer2") == 0 and attacker:Alive() and amongUsRoundOver == false then
                            attacker:Give("weapon_ttt_impostor_knife_randomat")
                            attacker:SelectWeapon("weapon_ttt_impostor_knife_randomat")
                            attacker:PrintMessage(HUD_PRINTCENTER, "No-one can see you holding the knife")
                            attacker:ChatPrint("No-one can see you holding the knife")
                        end
                    end)
                elseif timer.Exists("AmongUsRandomatKnifeTimer3") then
                    timer.Create("AmongUsRandomatKnifeTimer", 1, cooldown, function()
                        --Live onscreen knife cooldown
                        if attacker:Alive() and amongUsRoundOver == false then
                            attacker:PrintMessage(HUD_PRINTCENTER, "Knife is on cooldown for " .. timer.RepsLeft("AmongUsRandomatKnifeTimer") .. " second(s).")
                        end

                        --Message in chat and giving the knife after the cooldown has completely passed and the traitor is still alive
                        if timer.RepsLeft("AmongUsRandomatKnifeTimer") == 0 and attacker:Alive() and amongUsRoundOver == false then
                            attacker:Give("weapon_ttt_impostor_knife_randomat")
                            attacker:SelectWeapon("weapon_ttt_impostor_knife_randomat")
                            attacker:PrintMessage(HUD_PRINTCENTER, "No-one can see you holding the knife")
                            attacker:ChatPrint("No-one can see you holding the knife")
                        end
                    end)
                else
                    timer.Create("AmongUsRandomatKnifeTimer3", 1, cooldown, function()
                        --Live onscreen knife cooldown
                        if attacker:Alive() and amongUsRoundOver == false then
                            attacker:PrintMessage(HUD_PRINTCENTER, "Knife is on cooldown for " .. timer.RepsLeft("AmongUsRandomatKnifeTimer3") .. " second(s).")
                        end

                        --Message in chat and giving the knife after the cooldown has completely passed and the traitor is still alive
                        if timer.RepsLeft("AmongUsRandomatKnifeTimer3") == 0 and attacker:Alive() and amongUsRoundOver == false then
                            attacker:Give("weapon_ttt_impostor_knife_randomat")
                            attacker:SelectWeapon("weapon_ttt_impostor_knife_randomat")
                            attacker:PrintMessage(HUD_PRINTCENTER, "No-one can see you holding the knife")
                            attacker:ChatPrint("No-one can see you holding the knife")
                        end
                    end)
                end
            end
        end
    end)

    --Traitors cannot kill eachother, gives back the knife immediately if attempted
    self:AddHook("EntityTakeDamage", function(ent, dmginfo)
        local attacker = dmginfo:GetAttacker()

        if IsValid(ent) and ent:IsPlayer() and dmginfo:GetInflictor():GetClass() == "weapon_ttt_impostor_knife_randomat" then
            if ent:GetRole() == ROLE_TRAITOR then
                timer.Simple(0.1, function()
                    attacker:Give("weapon_ttt_impostor_knife_randomat")
                    attacker:SelectWeapon("weapon_ttt_impostor_knife_randomat")
                end)

                return true
            end
        end
    end)

    --Replaces the usual ragdoll corpse with an actual crewmate corpse
    --Adds corpse to a table so as to be removed after the next vote is finished
    self:AddHook("TTTOnCorpseCreated", function(corpse)
        corpse:SetModel("models/amongus/player/corpse.mdl")
        table.insert(corpses, corpse)
    end)

    --Turning off blood so traitors are not so easily incriminated
    for i, ply in pairs(player.GetAll()) do
        ply:SetBloodColor(DONT_BLEED)
    end

    --Various think functions
    self:AddHook("Think", function()
        --Stopping corpses from bleeding
        for i, corpse in pairs(corpses) do
            util.StopBleeding(corpse)
        end

        --Freezing the round timer as the innocent task now serves this purpose (freeze to 4:20 cause Ynaut)
        if GetGlobalBool("AmongUsGunWinRemove") == false then
            SetGlobalFloat("ttt_round_end", CurTime() + 261)
            SetGlobalFloat("ttt_haste_end", CurTime() + 261)
        end

        --Stopping the TTT round timer during a meeting
        if amongUsMeeting then
            SetGlobalFloat("ttt_round_end", CurTime() + amongUsMeetingTimeLeft)
            SetGlobalFloat("ttt_haste_end", CurTime() + amongUsMeetingTimeLeft)
        end

        --Remove any trigger_hurt map entities which could kill a player while frozen mid-vote
        if amongUsRemoveHurt then
            for k, v in ipairs(ents.FindByClass("trigger_hurt")) do
                v:Remove()
            end
        end
    end)

    --Adding 2 custom win conditions
    self:AddHook("TTTCheckForWin", function()
        --Counting the number of alive traitors and innocents
        local numAlivePlayers = #self:GetAlivePlayers()
        local numAliveTraitors = 0

        for i, ply in pairs(self:GetAlivePlayers()) do
            if ply:GetRole() == ROLE_TRAITOR then
                numAliveTraitors = numAliveTraitors + 1
            end
        end

        local numAliveInnocents = numAlivePlayers - numAliveTraitors

        --If all weapons on the map are picked up, innocents win. This win condition is disabled if guns were found in under a minute and the round timer is un-frozen
        if amongUsFoundWeaponCount >= wepspawns and amongUsPlayTimeCount >= 5 and GetGlobalBool("AmongUsGunWinRemove") == false and GetGlobalBool("AmongUsTaskDisable") == false then
            if amongUsPlayTimeCount <= GetConVar("randomat_amongus_task_threshhold"):GetInt() then
                SetGlobalBool("AmongUsGunWinRemove", true)
                PrintMessage(HUD_PRINTCENTER, "Guns found too easily!")
                PrintMessage(HUD_PRINTTALK, "Guns were found too easily, win by voting out all traitors!")
                timer.Remove("AmongUsTotalWeaponDecrease")
            else
                return WIN_INNOCENT
            end
            --If on Among Us map, win when all tasks are complete, comms aren't down and tasks weren't completed too quickly
        elseif game.GetMap() == "ttt_amongusskeld" and amongUsFoundWeaponCount >= wepspawns and GetGlobalBool("AmongUsGunWinRemove") == false and GetGlobalBool("AmongUsTasksTooFast") == false then
            if amongUsPlayTimeCount <= GetConVar("randomat_amongus_task_threshhold"):GetInt() then
                SetGlobalBool("AmongUsTasksTooFast", true)
                PrintMessage(HUD_PRINTCENTER, "Tasks finished too easily!")
                PrintMessage(HUD_PRINTTALK, "Tasks were finished too easily, win by voting out all traitors!")
            else
                return WIN_INNOCENT
            end
        elseif numAliveInnocents <= numAliveTraitors then
            --If there are as many traitors as innocents, traitors win
            return WIN_TRAITOR
        elseif numAliveTraitors == 0 then
            return WIN_INNOCENT
        elseif game.GetMap() == "ttt_amongusskeld" then
            return WIN_NONE
        end
    end)

    --Play the Among Us victory music at the end of the round
    self:AddHook("TTTEndRound", function(result)
        if result == WIN_TRAITOR then
            for k, v in pairs(player.GetAll()) do
                v:EmitSound(Sound("amongus/impostorwin.mp3"))
            end

            net.Start("AmongUsForceSound")
            net.WriteString("traitorwin")
            net.Broadcast()
        else
            for k, v in pairs(player.GetAll()) do
                v:EmitSound(Sound("amongus/crewmatewin.mp3"))
            end

            net.Start("AmongUsForceSound")
            net.WriteString("innocentwin")
            net.Broadcast()
        end
    end)

    --Initiates a vote when a body is inspected
    hook.Add("TTTBodyFound", "AmongUsEventBegin", function(finder, deadply, rag)
        amongUsEmergencyMeeting = false
        AmongUsVote(finder:Nick())
    end)

    --Special behaviour if playing on an Among Us map with tasks
    if GetGlobalBool("AmongUsTaskDisable") then
        for k, v in pairs(ents.GetAll()) do
            if v.AutoSpawnable and (v.Kind == WEAPON_HEAVY or v.Kind == WEAPON_PISTOL or v.Kind == WEAPON_NADE) then
                v:Remove()
            end
        end
    else
        --Else add our own task
        --Artificially adding +1 to the guns found counter if a gun hasn't been found in the last 30 seconds to prevent guns that are out of bounds preventing a win to ensure the game is on a timer
        timer.Create("AmongUsTotalWeaponDecrease", 20, 0, function()
            amongUsFoundWeaponCount = amongUsFoundWeaponCount + 1
            net.Start("AmongUsTaskBarUpdate")
            net.WriteInt(amongUsFoundWeaponCount, 16)
            net.Broadcast()
        end)

        --Let the player pick up weapons and nades and count them toward the number found, if all are found innocents win (replacement for Among Us tasks)
        self:AddHook("WeaponEquip", function(wep, ply)
            if wep.Kind == WEAPON_HEAVY or wep.Kind == WEAPON_PISTOL or wep.Kind == WEAPON_NADE or wep.Kind == WEAPON_NONE then
                amongUsFoundWeaponCount = amongUsFoundWeaponCount + 1
                net.Start("AmongUsTaskBarUpdate")
                net.WriteInt(amongUsFoundWeaponCount, 16)
                net.Broadcast()
                timer.Start("AmongUsTotalWeaponDecrease")
            end
        end)
    end

    local soundSpamCount = 0

    --Handling sound and special map interaction
    self:AddHook("EntityEmitSound", function(sounddata)
        --Not muting among us sounds, traitor button sound or a sound from ttt_amongusskeld
        if not (string.StartWith(sounddata.SoundName, "amongus") or sounddata.SoundName == "buttons/button14.wav") then
            --Altering ttt_amongusskeld map's sounds and interactions
            if game.GetMap() == "ttt_amongusskeld" then
                if sounddata.SoundName == "ambient/alarms/alarm_citizen_loop1.wav" then
                    sounddata.SoundName = "amongus/alarmloop.wav"
                    sounddata.Volume = 1
                    --Updating the taskbar on completing an in-map task

                    return true
                elseif sounddata.SoundName == "plats/elevbell1.wav" then
                    soundSpamCount = soundSpamCount + 1

                    if soundSpamCount == 3 then
                        amongUsFoundWeaponCount = amongUsFoundWeaponCount + 1
                        soundSpamCount = 0
                    end

                    net.Start("AmongUsTaskBarUpdate")
                    net.WriteInt(amongUsFoundWeaponCount, 16)
                    net.Broadcast()

                    if GetGlobalBool("AmongUsGunWinRemove") then
                        return false
                    else
                        sounddata.SoundName = "amongus/taskcomplete.mp3"

                        return true
                    end
                elseif sounddata.SoundName == "npc/overwatch/cityvoice/fcitadel_45sectosingularity.wav" then
                    --Adding more on-screen alerts for sabotages and a halo around the object to interact with to disable
                    PrintMessage(HUD_PRINTCENTER, "Stand at the two buttons in Reactor to fix it!")
                    PrintMessage(HUD_PRINTTALK, "The reactor is melting down in 45 seconds! \nStand at the two buttons in Reactor to fix it!")

                    return false
                elseif sounddata.SoundName == "npc/overwatch/cityvoice/fprison_nonstandardexogen.wav" then
                    PrintMessage(HUD_PRINTCENTER, "Press keypads in O2 and Admin to fix it!")
                    PrintMessage(HUD_PRINTTALK, "O2 will be depleted in 30 seconds! \nPress keypads in O2 and Admin to fix it!")
                    net.Start("AmongUsDrawHalo")
                    net.WriteString("o2")
                    net.Broadcast()
                    amongUsO2Press558 = false
                    amongUsO2Press559 = false

                    return false
                elseif sounddata.SoundName == "npc/overwatch/cityvoice/fprison_detectionsystemsout.wav" then
                    PrintMessage(HUD_PRINTCENTER, "Head to Communications to fix hidden tasks!")
                    PrintMessage(HUD_PRINTTALK, "Tasks are hidden! \nHead to Communications to fix it!")
                    SetGlobalBool("AmongUsGunWinRemove", true)
                    net.Start("AmongUsDrawHalo")
                    net.WriteString("comms")
                    net.Broadcast()

                    return false
                elseif sounddata.SoundName == "ambient/machines/thumper_shutdown1.wav" then
                    PrintMessage(HUD_PRINTCENTER, "Head to electrical to fix the lights!")
                    PrintMessage(HUD_PRINTTALK, "Lights are out! \nHead to electrical to fix them!")
                    net.Start("AmongUsDrawHalo")
                    net.WriteString("lights")
                    net.Broadcast()
                elseif sounddata.SoundName == "ambient/machines/thumper_startup1.wav" then
                    net.Start("AmongUsStopHalo")
                    net.WriteString("lights")
                    net.Broadcast()
                elseif sounddata.SoundName == "ambient/alarms/klaxon1.wav" and amongUsRoundOver == false then
                    --Making the emergency meeting button functional
                    return false
                end
            end
            --Muting all other server-side sounds, on any map
        else
            return false
        end
    end)

    --Modifying ttt_amongusskeld interactions through the player interacting with entities
    if game.GetMap() == "ttt_amongusskeld" then
        amongUsO2Press558 = false
        amongUsO2Press559 = false

        self:AddHook("FindUseEntity", function(ply, defaultEnt)
            if defaultEnt == Entity(175) and ply:GetNWBool("AmongUsPressedEmergencyButton", true) == false then
                emergencyButtonTriggerCount = emergencyButtonTriggerCount + 1

                if emergencyButtonTriggerCount == 1 then
                    ply:SetNWBool("AmongUsPressedEmergencyButton", true)
                    net.Start("AmongUsForceSound")
                    net.WriteString("emergency")
                    net.Broadcast()
                    amongUsEmergencyMeeting = true
                    AmongUsVote(ply:Nick())
                end
            elseif defaultEnt == Entity(558) then
                amongUsO2Press558 = true

                if amongUsO2Press559 == true then
                    net.Start("AmongUsStopHalo")
                    net.WriteString("o2")
                    net.Broadcast()
                end
            elseif defaultEnt == Entity(559) then
                amongUsO2Press559 = true

                if amongUsO2Press558 == true then
                    net.Start("AmongUsStopHalo")
                    net.WriteString("o2")
                    net.Broadcast()
                end
            elseif defaultEnt == Entity(566) then
                SetGlobalBool("AmongUsGunWinRemove", false)
                net.Start("AmongUsStopHalo")
                net.WriteString("comms")
                net.Broadcast()
            elseif defaultEnt == Entity(175) and ply:GetNWBool("AmongUsPressedEmergencyButton", true) then
                ply:ChatPrint("You have used your emergency meeting")
            end
        end)
    end

    --Walk speed can be changed like in among us
    -- Scales the player speed on the client
    net.Start("RdmtSetSpeedMultiplier")
    net.WriteFloat(GetConVar("randomat_amongus_player_speed"):GetFloat())
    net.WriteString("RdmtAmongUsSpeed")
    net.Broadcast()

    -- Scales the player speed on the server
    self:AddHook("TTTSpeedMultiplier", function(ply, mults)
        if not ply:Alive() or ply:IsSpec() then return end
        table.insert(mults, GetConVar("randomat_amongus_player_speed"):GetFloat())
    end)
end

--Emergency meeting starts after the configured delay if someone pressed the emergency meeting keybind
net.Receive("AmongUsEmergencyMeeting", function(ln, ply)
    --Preventing players from calling multiple emergency meetings at once
    net.Start("AmongUsEmergencyMeetingCall")
    net.Broadcast()

    timer.Create("AmongUsEmergencyMeetingTimer", 1, GetConVar("randomat_amongus_emergency_delay"):GetInt(), function()
        if timer.RepsLeft("AmongUsEmergencyMeetingTimer") == 0 then
            --If the player has died since the emergency meeting was called, a meeting is already ongoing, or the round is over, no emergency meeting happens
            if ply:Alive() and amongUsMeeting == false and amongUsRoundOver == false then
                amongUsEmergencyMeeting = true
                AmongUsVote(ply:Nick())
            elseif not ply:Alive() then
                ply:PrintMessage(HUD_PRINTCENTER, "You are dead, your emergency meeting was not called.")
                ply:PrintMessage(HUD_PRINTTALK, "You are dead, your emergency meeting was not called.")
            end
        end
    end)
end)

--Handle player voting
net.Receive("AmongUsPlayerVoted", function(ln, ply)
    local voterepeatblock = 0
    local votee = net.ReadString()
    local num = 0

    --Stop a player from voting again
    for k, v in pairs(amongusPlayersVoted) do
        if k == ply then
            voterepeatblock = 1
        end

        ply:PrintMessage(HUD_PRINTTALK, "You have already voted.")
    end

    --Play the vote sound to all players, if they are not trying to vote multiple times
    if voterepeatblock == 0 then
        for k, v in pairs(player.GetAll()) do
            v:EmitSound(Sound("amongus/vote.mp3"))
        end

        net.Start("AmongUsForceSound")
        net.WriteString("vote")
        net.Broadcast()
    end

    --Searching for the player that was voted for
    for k, v in pairs(votableplayers) do
        --find which player was voted for
        if v:Nick() == votee and voterepeatblock == 0 then
            amongusPlayersVoted[ply] = v --insert player and target into table

            --Tell everyone who they voted for in chat, if enabled
            if not GetConVar("randomat_amongus_anonymous_voting"):GetBool() then
                for ka, va in pairs(player.GetAll()) do
                    va:PrintMessage(HUD_PRINTTALK, ply:Nick() .. " has voted to eject " .. votee)
                end
            end

            --Inserting their vote into the playervotes table to be used in AmongUsVoteEnd()
            playervotes[v] = playervotes[v] + 1
            --Saving the total number of votes a player has to be sent to the client (below)
            num = playervotes[v]
        end
    end

    --If they voted to skip vote
    if votee == "[Skip Vote]" and voterepeatblock == 0 then
        amongusPlayersVoted[ply] = "[Skip Vote]" --insert player and target into table

        --Tell everyone they voted to skip
        for ka, va in pairs(player.GetAll()) do
            va:PrintMessage(HUD_PRINTTALK, ply:Nick() .. " has voted to skip")
        end

        --Add a vote to the '[Skip Vote]' tally
        playervotes["[Skip Vote]"] = playervotes["[Skip Vote]"] + 1
        num = playervotes["[Skip Vote]"]
    end

    --Updating the total number of votes on the client-side vote window
    net.Start("AmongUsPlayerVoted")
    net.WriteString(votee)
    net.WriteInt(num, 32)
    net.Broadcast()

    --Counting the number of players voted so far, to check if voting can end early
    if voterepeatblock == 0 then
        numvoted = numvoted + 1
    end

    --If everyone has voted, end the vote now
    if voterepeatblock == 0 and numaliveplayers == numvoted then
        AmongUsVoteEnd()
    end
end)

function EVENT:End()
    --Workaround to prevent the end function from being triggered before the begin function
    if amongusRandomat then
        --Resetting variables
        table.Empty(amongusPlayersVoted)
        table.Empty(aliveplys)
        table.Empty(corpses)
        numvoted = 0
        wepspawns = 0
        amongUsRoundOver = true
        amongUsRemoveHurt = false

        --Turning blood back on
        for i, ply in pairs(player.GetAll()) do
            ply:SetBloodColor(BLOOD_COLOR_RED)
        end

        -- loop through all players
        for i, ply in pairs(player.GetAll()) do
            -- if the index k in the table playermodels has a model, then...
            if (playerModels[i] ~= nil) then
                -- we set the player v to the playermodel with index i in the table
                -- this should invoke the viewheight script from the models and fix viewoffsets (e.g. Zoey's model) 
                -- this does however first reset their viewmodel in the preparing phase (when they respawn)
                -- might be glitchy with pointshop items that allow you to get a viewoffset
                ply:SetModel(playerModels[i])
                ply:SetPlayerColor(playerColors[i])
            end

            -- we reset the cl_playermodel_selector_force to 1, otherwise TTT will reset their playermodels on a new round start (to default models!)
            ply:ConCommand("cl_playermodel_selector_force 1")
            ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            -- clear the model table to avoid setting wrong models (e.g. disconnected players)
            table.Empty(playerModels)
        end

        --Removing all the fancy functions we used now that the randomat is over
        hook.Remove("TTTBodyFound", "AmongUsEventBegin")
        timer.Remove("votekilltimerAmongUs")
        timer.Remove("AmongUsRandomatKnifeTimer")
        timer.Remove("AmongUsInnocentTask")
        timer.Remove("AmongUsTotalWeaponDecrease")
        timer.Remove("AmongUsPlayTimer")
        --Letting each player's client know the randomat is over
        net.Start("AmongUsEventEnd")
        net.Broadcast()
        net.Start("AmongUsEventRoundEnd")
        net.Broadcast()
        --Disallowing the randomat end function from being run again until the randomat is activated again
        amongusRandomat = false
    end
end

--Populating this randomat's ULX menu if the randomat ULX menu mod is installed
function EVENT:GetConVars()
    local sliders = {}

    for _, v in pairs({"voting_timer", "discussion_timer", "votepct", "knife_cooldown", "emergency_delay", "emergency_meetings", "task_threshhold"}) do
        local name = "randomat_" .. self.id .. "_" .. v

        if ConVarExists(name) then
            local convar = GetConVar(name)

            table.insert(sliders, {
                cmd = v,
                dsc = convar:GetHelpText(),
                min = convar:GetMin(),
                max = convar:GetMax(),
                dcm = 0
            })
        end
    end

    for _, v in pairs({"player_speed", "innocent_vision", "traitor_vision"}) do
        local name = "randomat_" .. self.id .. "_" .. v

        if ConVarExists(name) then
            local convar = GetConVar(name)

            table.insert(sliders, {
                cmd = v,
                dsc = convar:GetHelpText(),
                min = convar:GetMin(),
                max = convar:GetMax(),
                dcm = 1
            })
        end
    end

    local checks = {}

    for _, v in pairs({"freeze", "confirm_ejects", "anonymous_voting", "taskbar_update", "auto_trigger", "sprinting"}) do
        local name = "randomat_" .. self.id .. "_" .. v

        if ConVarExists(name) then
            local convar = GetConVar(name)

            table.insert(checks, {
                cmd = v,
                dsc = convar:GetHelpText()
            })
        end
    end

    return sliders, checks
end

Randomat:register(EVENT)