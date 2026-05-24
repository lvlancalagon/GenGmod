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

-- Stats
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
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
        self:SetRenderBounds(Vector(-128, -128, 0), Vector(128, 128, 128))

        -- Sound initialization
        self.ChaseSounds = {{CHASE_SOUND}} or {}
        self.KillSounds = {{KILL_SOUND}} or {}
        self.NextSoundTime = 0
        self.LoseTargetDist = {{LOSE_TARGET_DIST}}
        self.SearchRadius = {{SEARCH_RADIUS}}
        self.NextContactDamageTime = 0

        -- Transparency setup
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 255, 255, 0))
    end

    function ENT:OnMeleeAttack(enemy)
        -- Facing check for aggressive behavior
        if self:GetForward():Dot((enemy:GetPos() - self:GetPos()):GetNormalized()) > math.cos(math.rad(30)) then
            self:MeleeATT()
        end
    end

    function ENT:MeleeATT()
        -- Aggressive attack logic with delayed damage and effects
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

    -- Persistent Think (Works without AI)
    function ENT:CustomThink()
        -- 1. Sound Logic
        if CurTime() > self.NextSoundTime then
            local enemy = self:GetEnemy()
            if IsValid(enemy) and enemy:Alive() and self:GetRangeTo(enemy:GetPos()) < self.LoseTargetDist then
                if #self.ChaseSounds > 0 then
                    self:EmitSound(self.ChaseSounds[math.random(#self.ChaseSounds)], 100, 100)
                    self.NextSoundTime = CurTime() + 5
                end
            else
                if #self.ChaseSounds > 0 then
                    self:EmitSound(self.ChaseSounds[math.random(#self.ChaseSounds)], 100, 100)
                    self.NextSoundTime = CurTime() + math.random(10, 20)
                end
            end
        end

        -- 2. Destruction & Door Interaction
        for _, ent in pairs(ents.FindInSphere(self:LocalToWorld(Vector(0,0,75)), 60)) do
            if IsValid(ent) then
                -- Open doors
                if ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door_rotating" or ent:GetClass() == "func_door" then
                    ent:Fire("open")
                end
                -- Smash breakables
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
        -- Custom 2D Ragdoll System
        local ragdoll = ents.Create("prop_physics")
        ragdoll:SetAngles(self:GetAngles())
        ragdoll:SetModel(self:GetModel())
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
    local MAT_PATHS = {{MATERIAL_PATHS}} or {}

    function ENT:CustomInitialize()
        self:SetRenderBounds(Vector(-128, -128, 0), Vector(128, 128, 128))
        self.Mats = {}
        for _, path in ipairs(MAT_PATHS) do
            local mat = Material(path, "noclamp smooth")
            if mat and not mat:IsError() then
                self.Mats[#self.Mats + 1] = mat
            end
        end
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

-- DO NOT TOUCH --
AddCSLuaFile()
DrGBase.AddNextbot(ENT)
