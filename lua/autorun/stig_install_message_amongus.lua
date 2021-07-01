if engine.ActiveGamemode() == "terrortown" then
    if SERVER and (not file.Exists("autorun/au_playermodel.lua", "lsv")) then
        util.AddNetworkString("StigAmongUsInstallNet")
        local roundCount = 0

        hook.Add("TTTBeginRound", "StigAmongUsInstallMessage", function()
            roundCount = roundCount + 1

            if (roundCount == 1) or (roundCount == 2) then
                timer.Simple(4, function()
                    PrintMessage(HUD_PRINTTALK, "[TTT Among Us Randomat 2.0!]\nServer doesn't have the addon this mod needs to work!\nPRESS 'Y', TYPE /amongus AND SUBSCRIBE TO THE ADDON \nor see this mod's workshop page to install it.")
                end)
            end
        end)

        hook.Add("PlayerSay", "StigAmongUsInstallCommand", function(ply, text)
            if string.lower(text) == "/amongus" then
                net.Start("StigAmongUsInstallNet")
                net.Send(ply)

                return ""
            end
        end)
    elseif CLIENT then
        net.Receive("StigAmongUsInstallNet", function()
            steamworks.ViewFile("2313802230")
        end)
    end
end