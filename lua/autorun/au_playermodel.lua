player_manager.AddValidModel("Among Us Crewmate", "models/amongus/player/player.mdl")
list.Set("PlayerOptionsModel", "Among Us Crewmate", "models/amongus/player/player.mdl")
player_manager.AddValidModel("Among Us Corpse", "models/amongus/player/corpse.mdl")
list.Set("PlayerOptionsModel", "Among Us Corpse", "models/amongus/player/corpse.mdl")

hook.Add("PlayerSpawn", "AmongUsPlayermodelViewHeight", function(ply)
    timer.Simple(0.1, function()
        if IsValid(ply) and (ply:GetModel() == "models/amongus/player/player.mdl" or ply:GetModel() == "models/amongus/player/corpse.mdl") then
            ply:SetViewOffset(Vector(0, 0, 48))
            ply:SetViewOffsetDucked(Vector(0, 0, 30))
        end
    end)
end)