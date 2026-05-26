if not DrGBase then return end
ENT.Base = "drgbase_nextbot"
ENT.Type = "nextbot"

ENT.PrintName = "{{PRINT_NAME}}"
ENT.Category = "Custom Nextbots"
ENT.Models = {"models/props_junk/watermelon01.mdl"}
ENT.SpawnHealth = {{HEALTH}}
ENT.HealthRegen = 10
ENT.BloodColor = BLOOD_COLOR_RED
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- AI Stats
ENT.WalkSpeed = 150
ENT.RunSpeed = {{SPEED}}
ENT.Acceleration = {{ACCELERATION}}
ENT.JumpHeight = {{JUMP_POWER}}

-- AI Ranges
ENT.RangeAttackRange = 0
ENT.MeleeAttackRange = 80
ENT.ReachEnemyRange = 60
ENT.AvoidEnemyRange = 0

-- Possession
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_8DIR
ENT.PossessionViews = {
  {
    offset = Vector(0, 0, 20),
    distance = 400
  }
}
ENT.PossessionBinds = {
  [IN_ATTACK] = {{
    coroutine = true,
    onkeydown = function(self)
        self:MeleeATT()
    end
  }},
  [IN_JUMP] = {{
    coroutine = true,
    onkeydown = function(self)
        self:Jump()
    end
  }}
}

if SERVER then
    function ENT:CustomInitialize()
        self:SetCollisionBounds(Vector(-30, -30, 0), Vector(30, 30, 110))
        self:SetRenderBounds(Vector(-128, -128, 0), Vector(128, 128, 128))

        -- Sound initialization
        self.ChaseSounds = {{CHASE_SOUNDS}}
        self.KillSounds = {{KILL_SOUNDS}}
        self.NextSoundTime = 0
        self.LoseTargetDist = {{LOSE_TARGET_DIST}}
        self.SearchRadius = {{SEARCH_RADIUS}}
        self.NextContactDamageTime = 0

        -- Transparency setup
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 255, 255, 0))
    end

    function ENT:OnMeleeAttack(enemy)
        if self:GetForward():Dot((enemy:GetPos() - self:GetPos()):GetNormalized()) > math.cos(math.rad(30)) then
            self:MeleeATT()
        end
    end

    function ENT:MeleeATT()
        timer.Simple(0.4, function()
            if IsValid(self) then
                self:Attack({
                    damage = {{DAMAGE}},
                    type = DMG_SLASH,
                    range = 90,
                    push = false,
                    force = Vector(400, 0, 10)
                }, function(self, hit)
                    if #hit > 0 then
                        for _, ent in ipairs(hit) do
                            ent:TakeDamage({{DAMAGE}}, self, self)
                            ent:SetVelocity(self:GetForward() * 400 + self:GetUp() * 50)
                        end
                        if #self.KillSounds > 0 then
                            self:EmitSound(self.KillSounds[math.random(#self.KillSounds)], 100, 100)
                        end
                    else
                        self:EmitSound("npc/zombie/claw_miss" .. math.random(1, 2) .. ".wav", 100, 100)
                    end
                end)
            end
        end)
    end

    function ENT:OnReachedPatrol()
        self:Wait(math.random(3, 7))
    end

    function ENT:CustomThink()
        -- 1. Looping Sound Logic (AI Independent)
        if CurTime() > self.NextSoundTime then
            local enemy = self:GetEnemy()
            local sound_to_play = nil

            if IsValid(enemy) and enemy:Alive() and self:GetRangeTo(enemy:GetPos()) < self.LoseTargetDist then
                -- Chase state
                if #self.ChaseSounds > 0 then
                    sound_to_play = self.ChaseSounds[math.random(#self.ChaseSounds)]
                    self.NextSoundTime = CurTime() + 5 -- Check again in 5s
                end
            else
                -- Idle state
                if #self.ChaseSounds > 0 then
                    sound_to_play = self.ChaseSounds[math.random(#self.ChaseSounds)]
                    self.NextSoundTime = CurTime() + math.random(10, 20)
                end
            end

            if sound_to_play then
                -- Standard EmitSound for simplicity and broad compatibility
                self:EmitSound(sound_to_play, 100, 100)

                -- Force a more immediate loop if the file is long (Estimation)
                -- In GMod server, we don't have SoundDuration easily, so we use logic hooks.
            end
        end

        -- 2. Environmental Interaction
        for _, ent in pairs(ents.FindInSphere(self:LocalToWorld(Vector(0,0,75)), 60)) do
            if IsValid(ent) then
                if ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door_rotating" or ent:GetClass() == "func_door" then
                    ent:Fire("open")
                end
                if ent:GetClass() == "prop_physics" or ent:GetClass() == "func_breakable" then
                    ent:TakeDamage(500, self, self)
                    local effectData = EffectData()
                    effectData:SetOrigin(ent:GetPos())
                    util.Effect("Explosion", effectData)
                end
            end
        end
    end

    function ENT:OnContact(ent)
        if ent:IsPlayer() and ent:Alive() and CurTime() > self.NextContactDamageTime then
            local dmgInfo = DamageInfo()
            dmgInfo:SetAttacker(self)
            dmgInfo:SetInflictor(self)
            dmgInfo:SetDamage(20)
            dmgInfo:SetDamageType(DMG_SLASH)
            ent:TakeDamageInfo(dmgInfo)
            self.NextContactDamageTime = CurTime() + 0.5
            self:MeleeATT()
        end
    end

    function ENT:OnDeath(dmg, hitgroup)
        -- Custom 2D Ragdoll
        local ragdoll = ents.Create("prop_physics")
        ragdoll:SetAngles(self:GetAngles())
        ragdoll:SetModel("models/props_junk/watermelon01.mdl")
        ragdoll:SetPos(self:GetPos())
        ragdoll:SetNW2String("2D_RAGDOLLMAT", "{{MATERIAL_PATH}}")
        ragdoll:DrawShadow(false)
        ragdoll:SetMaterial("models/effects/vol_light001")
        ragdoll:Spawn()

        local phys = ragdoll:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetVelocity(self:GetForward() * -1000 + self:GetUp() * 440)
        end

        if GetConVarNumber("drgbase_remove_ragdolls") != -1 then
            SafeRemoveEntityDelayed(ragdoll, GetConVarNumber("drgbase_remove_ragdolls") or 10)
        end

        if IsValid(self:GetCreator()) then
            self:GetCreator():DrG_AddUndo(ragdoll, "NPC", "Undone " .. self.PrintName)
        end

        if #self.KillSounds > 0 then
            self:EmitSound(self.KillSounds[math.random(#self.KillSounds)], 100, 100)
        end
    end
end

if CLIENT then
    local MAT_PATHS = {{MATERIAL_PATHS}}

    function ENT:CustomInitialize()
        self:SetRenderBounds(Vector(-128, -128, 0), Vector(128, 128, 128))
        self.Mats = {}
        for _, path in ipairs(MAT_PATHS) do
            local mat = Material(path, "noclamp smooth nocull")
            if mat and not mat:IsError() then
                self.Mats[#self.Mats + 1] = mat
            else
                print("[Nextbot] Failed to load material: " .. path)
            end
        end
        -- Hide base model on client
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 255, 255, 0))
    end

    function ENT:Draw()
        if not self.Mats or #self.Mats == 0 then return end

        local frameIndex = 1
        if #self.Mats > 1 then
            frameIndex = math.floor(CurTime() / 1.5) % #self.Mats + 1
        end

        local currentMat = self.Mats[frameIndex]
        if not currentMat then return end

        local pos = self:GetPos() + Vector(0, 0, 60)

        -- High quality 3D2D billboarding
        local ang = EyeAngles()
        ang:RotateAroundAxis(ang:Up(), -90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        cam.Start3D2D(pos, ang, 0.5)
            surface.SetMaterial(currentMat)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(-128, -128, 256, 256)
        cam.End3D2D()
    end
end

-- Client-side rendering for the death Ragdoll
if CLIENT then
    local RagdollMats = {}
    hook.Add("PostDrawOpaqueRenderables", "NextbotRagdollRenderer", function()
        for _, ent in ipairs(ents.FindByClass("prop_physics")) do
            local mat_path = ent:GetNW2String("2D_RAGDOLLMAT", "")
            if mat_path != "" then
                if not RagdollMats[mat_path] then
                    RagdollMats[mat_path] = Material(mat_path, "noclamp smooth nocull")
                end
                local mat = RagdollMats[mat_path]
                if mat and not mat:IsError() then
                    render.SetMaterial(mat)
                    render.DrawSprite(ent:GetPos() + Vector(0,0,60), 128, 128, Color(255,255,255))
                end
            end
        end
    end)
end

-- Registration
AddCSLuaFile()
DrGBase.AddNextbot(ENT)
