local autoRandomatOn = false

if GetConVar("randomat_amongus_auto_trigger"):GetBool() and game.GetMap() == "ttt_amongusskeld" then
    SetGlobalBool("AmongUsTaskDisable", true)

    if GetConVar("ttt_randomat_auto"):GetBool() then
        autoRandomatOn = true
    end

    hook.Add("TTTPrepareRound", "AmongUsAutoRandomatOff", function()
        if autoRandomatOn then
            RunConsoleCommand("ttt_randomat_auto", "0")
        end
    end)

    hook.Add("TTTBeginRound", "AmongUsTriggeredStart", function()
        Randomat:SilentTriggerEvent("amongus", player.GetAll()[1])
    end)

    hook.Add("TTTEndRound", "AmongUsAutoRandomatReset", function()
        if autoRandomatOn then
            RunConsoleCommand("ttt_randomat_auto", "1")
        end
    end)
else
    SetGlobalBool("AmongUsTaskDisable", false)
end