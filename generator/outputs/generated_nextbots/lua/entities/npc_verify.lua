AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Type = "nextbot"

ENT.PrintName = "Verify"
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
        self:SetHealth(100)
        self.LoseTargetDist = 3000
        self.SearchRadius = 2000
        self.ChaseSounds = {}
        self.KillSounds = {}
        self.NextSoundTime = 0

        self:loco:SetJumpHeight(58)
        self.AttackDamage = 100

        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
        self:SetCollisionGroup(COLLISION_GROUP_NPC)

        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:SetColor(Color(255, 255, 255, 0))
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
                    self:loco:SetDesiredSpeed(450)
                    self:loco:SetAcceleration(900)
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
    function ENT:Draw()
        local pos = self:GetPos() + Vector(0, 0, 60)

        -- Billboarding: Make the sprite face the player
        local ang = EyeAngles()
        ang:RotateAroundAxis(ang:Up(), -90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        if not self.SpriteMat then
            self.SpriteMat = Material("nextbot/verify.png", "noclamp smooth")
        end

        cam.Start3D2D(pos, ang, 0.5)
            surface.SetMaterial(self.SpriteMat)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(-128, -128, 256, 256)
        cam.End3D2D()
    end
end

list.Set("NPC", "npc_verify", {
    Name = "Verify",
    Class = "npc_verify",
    Category = "Nextbot Generator",
    Spawnable = true,
    AdminSpawnable = true
})
