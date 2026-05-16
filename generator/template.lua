if not DrGBase then return end
ENT.Base = "drgbase_nextbot"
ENT.Type = "nextbot"

ENT.PrintName = "{{PRINT_NAME}}"
ENT.Category = "Nextbot Generator (DrGBase)"
ENT.Models = {"models/props_junk/watermelon01.mdl"}
ENT.SpawnHealth = {{HEALTH}}
ENT.BloodColor = BLOOD_COLOR_RED

-- Stats
ENT.WalkSpeed = {{SPEED}}
ENT.RunSpeed = {{SPEED}}
ENT.Acceleration = {{ACCELERATION}}
ENT.JumpHeight = {{JUMP_POWER}}

-- AI
ENT.RangeAttackRange = 0
ENT.MeleeAttackRange = 50
ENT.ReachEnemyRange = 50

if SERVER then
    function ENT:CustomInitialize()
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))

        -- Set render bounds to prevent culling
        self:SetRenderBounds(Vector(-128, -128, 0), Vector(128, 128, 128))

        -- Sound initialization
        self.ChaseSounds = {{CHASE_SOUND}}
        self.KillSounds = {{KILL_SOUND}}
        self.NextChaseSoundTime = 0
    end

    function ENT:OnMeleeAttack(enemy)
        self:Attack({
            damage = {{DAMAGE}},
            type = DMG_SLASH,
            viewpunch = Angle(20, 0, 0)
        })

        -- Play kill sound
        if #self.KillSounds > 0 then
            self:EmitSound(self.KillSounds[math.random(#self.KillSounds)], 100, 100)
        end
    end

    function ENT:OnReachedPatrol()
        self:Wait(math.random(3, 7))
    end

    function ENT:OnIdle()
        -- Play random idle/chase sound if not chasing
        if not self:HasEnemy() and #self.ChaseSounds > 0 and CurTime() > self.NextChaseSoundTime then
            local snd = self.ChaseSounds[math.random(#self.ChaseSounds)]
            self:EmitSound(snd, 100, 100)
            self.NextChaseSoundTime = CurTime() + math.random(5, 10)
        end
        self:AddPatrolPos(self:RandomPos(1500))
    end

    function ENT:OnChaseEnemy(enemy)
        -- Manual chase sound loop
        if #self.ChaseSounds > 0 and CurTime() > self.NextChaseSoundTime then
            local snd = self.ChaseSounds[math.random(#self.ChaseSounds)]
            self:EmitSound(snd, 100, 100)

            -- Wait for the duration of the sound plus a bit of delay
            local duration = 5 -- Default fallback
            -- We use a rough estimation since SoundDuration might not work on server without precaching
            self.NextChaseSoundTime = CurTime() + duration
        end
    end

    function ENT:OnContact(ent)
        if ent:IsPlayer() and ent:Alive() then
            self:OnMeleeAttack(ent)
        end
    end

    function ENT:OnDeath(dmg, hitgroup)
        if #self.KillSounds > 0 then
            self:EmitSound(self.KillSounds[math.random(#self.KillSounds)], 100, 100)
        end
    end
end

if CLIENT then
    local MAT = Material("{{MATERIAL_PATH}}", "noclamp smooth")

    function ENT:CustomInitialize()
        self:SetRenderBounds(Vector(-128, -128, 0), Vector(128, 128, 128))
    end

    function ENT:Draw()
        -- Do not call self:DrawModel() to keep the watermelon hidden

        local pos = self:GetPos() + Vector(0, 0, 60)
        render.SetMaterial(MAT)
        render.DrawSprite(pos, 128, 128, Color(255, 255, 255, 255))
    end
end

-- DO NOT TOUCH --
AddCSLuaFile()
DrGBase.AddNextbot(ENT)
