if not DrGBase then return end
ENT.Base = "drgbase_nextbot_sprite"
ENT.Type = "nextbot"

ENT.PrintName = "{{PRINT_NAME}}"
ENT.Category = "Custom Nextbots"
ENT.SpawnHealth = {{HEALTH}}
ENT.HealthRegen = 10
ENT.BloodColor = BLOOD_COLOR_RED
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Animations (DrGBase Sprite Base)
ENT.SpriteFolder = "{{SPRITE_FOLDER}}"
ENT.FramesPerSecond = 1 -- Approximately 1 second per frame as requested
ENT.WalkAnimation = "idle"
ENT.RunAnimation = "idle"
ENT.IdleAnimation = "idle"
ENT.JumpAnimation = "idle"

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
        self:SetCollisionBounds(Vector(-30, -30, 0), Vector(30, 30, 110))

        -- Sound initialization
        self.ChaseSounds = {{CHASE_SOUND}} or {}
        self.KillSounds = {{KILL_SOUND}} or {}
        self.NextSoundTime = 0
        self.LoseTargetDist = {{LOSE_TARGET_DIST}}
        self.SearchRadius = {{SEARCH_RADIUS}}
        self.NextContactDamageTime = 0
    end

    function ENT:OnMeleeAttack(enemy)
        if self:GetForward():Dot((enemy:GetPos() - self:GetPos()):GetNormalized()) > math.cos(math.rad(30)) then
            self:MeleeATT()
        end
    end

    function ENT:MeleeATT()
        -- Play Attack Animation if available
        self:PlaySpriteAnim("Attack")

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
        -- 1. Sound Logic (Works without AI)
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

        -- 2. Environmental Interaction (Doors and Smash)
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
        ragdoll:SetModel("models/props_junk/watermelon01.mdl") -- Base model
        ragdoll:SetPos(self:GetPos())
        ragdoll:SetNW2String("2D_RAGDOLLMAT", "{{RAGDOLL_MAT}}")
        ragdoll:DrawShadow(false)
        ragdoll:SetMaterial("models/effects/vol_light001") -- Hidden model
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

-- Client-side rendering for the Ragdoll
if CLIENT then
    local RagdollMats = {} -- Cache for efficiency
    hook.Add("PostDrawOpaqueRenderables", "NextbotRagdollRenderer", function()
        for _, ent in ipairs(ents.FindByClass("prop_physics")) do
            local mat_path = ent:GetNW2String("2D_RAGDOLLMAT", "")
            if mat_path != "" then
                if not RagdollMats[mat_path] then
                    RagdollMats[mat_path] = Material(mat_path, "noclamp smooth")
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
