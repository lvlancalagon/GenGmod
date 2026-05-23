if not DrGBase then return end
ENT.Base = "drgbase_nextbot"
ENT.Type = "nextbot"

ENT.PrintName = "{{PRINT_NAME}}"
ENT.Category = "Custom Nextbots"
ENT.Models = {"models/props_junk/watermelon01.mdl"}
ENT.SpawnHealth = {{HEALTH}}
ENT.BloodColor = BLOOD_COLOR_RED
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Stats
ENT.WalkSpeed = 150
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
        self:SetRenderBounds(Vector(-128, -128, 0), Vector(128, 128, 128))

        -- Sound initialization
        self.ChaseSounds = {{CHASE_SOUND}} or {}
        self.KillSounds = {{KILL_SOUND}} or {}
        self.NextSoundTime = 0
        self.LoseTargetDist = {{LOSE_TARGET_DIST}}
        self.SearchRadius = {{SEARCH_RADIUS}}
        self.NextContactDamageTime = 0

        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 255, 255, 0))
    end

    function ENT:OnMeleeAttack(enemy)
        self:Attack({
            damage = {{DAMAGE}},
            type = DMG_SLASH,
            viewpunch = Angle(20, 0, 0)
        })

        if #self.KillSounds > 0 then
            self:EmitSound(self.KillSounds[math.random(#self.KillSounds)], 100, 100)
        end
    end

    function ENT:OnReachedPatrol()
        self:Wait(math.random(3, 7))
    end

    function ENT:CustomThink()
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

        local trace = util.TraceLine({
            start = self:GetPos() + Vector(0,0,36),
            endpos = self:GetPos() + self:GetForward() * 40 + Vector(0,0,36),
            filter = self
        })

        if IsValid(trace.Entity) then
            if trace.Entity:GetClass() == "prop_physics" or trace.Entity:GetClass() == "func_breakable" then
                trace.Entity:TakeDamage( 500, self, self )
                local effectData = EffectData()
                effectData:SetOrigin( trace.Entity:GetPos() )
                util.Effect( "Explosion", effectData )
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
        render.SetMaterial(currentMat)
        render.DrawSprite(pos, 128, 128, Color(255, 255, 255, 255))
    end
end

-- DO NOT TOUCH --
AddCSLuaFile()
DrGBase.AddNextbot(ENT)
