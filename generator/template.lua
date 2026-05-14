AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"

ENT.PrintName = "{{PRINT_NAME}}"
ENT.Category = "Nextbot Generator"
ENT.Author = "Nextbot Generator"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end
    local SpawnPos = tr.HitPos + tr.HitNormal * 16
    local ent = ents.Create(ClassName)
    ent:SetPos(SpawnPos)
    ent:Spawn()
    ent:Activate()
    return ent
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_junk/watermelon01.mdl")
        self:SetHealth({{HEALTH}})
        self.LoseTargetDist = {{LOSE_TARGET_DIST}}
        self.SearchRadius = {{SEARCH_RADIUS}}
        self.ChaseSounds = {{CHASE_SOUND}}
        self.KillSounds = {{KILL_SOUND}}
        self.NextSoundTime = 0

        self:loco:SetJumpHeight({{JUMP_POWER}})
        self.AttackDamage = {{DAMAGE}}

        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
        self:SetCollisionGroup(COLLISION_GROUP_NPC)
    end

    function ENT:SetEnemy(ent) self.Enemy = ent end
    function ENT:GetEnemy() return self.Enemy end

    function ENT:HaveEnemy()
        if self:GetEnemy() and IsValid(self:GetEnemy()) then
            if self:GetRangeTo(self:GetEnemy():GetPos()) > self.LoseTargetDist then
                return self:FindEnemy()
            elseif self:GetEnemy():IsPlayer() and !self:GetEnemy():Alive() then
                return self:FindEnemy()
            end
            return true
        else
            return self:FindEnemy()
        end
    end

    function ENT:FindEnemy()
        local _ents = ents.FindInSphere(self:GetPos(), self.SearchRadius)
        for k, v in ipairs(_ents) do
            if v:IsPlayer() and v:Alive() then
                self:SetEnemy(v)
                return true
            end
        end
        self:SetEnemy(nil)
        return false
    end

    function ENT:RunBehaviour()
        while (true) do
            if self:HaveEnemy() then
                local enemy = self:GetEnemy()
                if IsValid(enemy) and enemy:Alive() then
                    self:loco:FaceTowards(enemy:GetPos())
                    self:StartActivity(ACT_WALK)
                    self:loco:SetDesiredSpeed({{SPEED}})
                    self:loco:SetAcceleration({{ACCELERATION}})
                    self:MoveToPos(enemy:GetPos())
                    self:StartActivity(ACT_IDLE)
                else
                    self:SetEnemy(nil)
                end
            else
                self:StartActivity(ACT_IDLE)
                self:FindEnemy()
            end
            coroutine.wait(0.1)
        end
    end

    function ENT:OnContact(ent)
        if ent:IsPlayer() and ent:Alive() then
            local dmgInfo = DamageInfo()
            dmgInfo:SetAttacker(self)
            dmgInfo:SetInflictor(self)
            dmgInfo:SetDamage(self.AttackDamage)
            dmgInfo:SetDamageType(DMG_SLASH)
            ent:TakeDamageInfo(dmgInfo)

            if #self.KillSounds > 0 then
                local snd = self.KillSounds[math.random(#self.KillSounds)]
                self:EmitSound(snd, 100, 100)
            end
        end
    end

    function ENT:Think()
        if #self.ChaseSounds > 0 and CurTime() > self.NextSoundTime then
            local snd = self.ChaseSounds[math.random(#self.ChaseSounds)]
            self:EmitSound(snd, 100, 100)
            self.NextSoundTime = CurTime() + 5
        end
    end

    function ENT:OnStuck()
        self:loco:Jump()
        self:loco:ClearStuck()
    end
end

if CLIENT then
    local MAT = Material("{{MATERIAL_PATH}}", "noclamp smooth")
    function ENT:Draw()
        local pos = self:GetPos() + Vector(0, 0, 60)

        -- Billboarding: Make the sprite face the player
        local ang = EyeAngles()
        ang:RotateAroundAxis(ang:Up(), -90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        cam.Start3D2D(pos, ang, 0.5)
            surface.SetMaterial(MAT)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(-128, -128, 256, 256)
        cam.End3D2D()
    end
end
