if not DrGBase then return end
ENT.Base = "drgbase_nextbot"
ENT.Type = "nextbot"

ENT.PrintName = "{{PRINT_NAME}}"
ENT.Category = "Nextbot Generator (DrGBase)"
ENT.Models = {"models/props_junk/watermelon01.mdl"}
ENT.SpawnHealth = {{HEALTH}}
ENT.BloodColor = BLOOD_COLOR_RED

-- Sounds
ENT.OnIdleSounds = {{CHASE_SOUND}}
ENT.IdleSoundDelay = 5
ENT.OnDeathSounds = {{KILL_SOUND}}

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
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 255, 255, 0))
    end

    function ENT:OnMeleeAttack(enemy)
        self:Attack({
            damage = {{DAMAGE}},
            type = DMG_SLASH,
            viewpunch = Angle(20, 0, 0)
        })
    end

    function ENT:OnReachedPatrol()
        self:Wait(math.random(3, 7))
    end

    function ENT:OnIdle()
        self:AddPatrolPos(self:RandomPos(1500))
    end

    function ENT:OnContact(ent)
        if ent:IsPlayer() and ent:Alive() then
            self:OnMeleeAttack(ent)
        end
    end
end

if CLIENT then
    function ENT:CustomDraw()
        local pos = self:GetPos() + Vector(0, 0, 60)

        -- Billboarding: Make the sprite face the player
        local ang = EyeAngles()
        ang:RotateAroundAxis(ang:Up(), -90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        if not self.SpriteMat then
            self.SpriteMat = Material("{{MATERIAL_PATH}}", "noclamp smooth")
        end

        cam.Start3D2D(pos, ang, 0.5)
            surface.SetMaterial(self.SpriteMat)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(-128, -128, 256, 256)
        cam.End3D2D()
    end
end

-- DO NOT TOUCH --
AddCSLuaFile()
DrGBase.AddNextbot(ENT)
