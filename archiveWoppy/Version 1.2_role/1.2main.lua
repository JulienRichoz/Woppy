---------------------------------------------------------------------------------------------------------------
--Titre: 1.2main.lua
--Date: 13.05.2016
--Version 1.2
--Auteur: Richoz Julien
--Description v. 1.2: Gestion des rôles et spécialisations

--Versions antérieures: 
--		v. 1.0: "lancer" l'addon lorsque l'on entre dans le bon raid
--		v. 1.1:	Détection combat contre le boss
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------

----------------------------------------DECLARATION CAPTURE EVENEMENT--------------------------------------------
--capturer zone
local areaFrame = CreateFrame("Frame");
areaFrame:RegisterEvent("PLAYER_ENTERING_WORLD"); --event fire au moment de la conenction dans le jeu
areaFrame:RegisterEvent("ZONE_CHANGED_INDOOR"); --event fire quand le personnage entre dans une instance 


--capturer boss combat. Frame similaire créée au dessus mais celle-ci sera un OnUpdate et nous devrons la cacher après son utilsiation
local inCombatFrame = CreateFrame("Frame");
inCombatFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT");

--Frame pour capturer les sorts que le boss lance
local immerseusFrame = CreateFrame("Frame");
immerseusFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
immerseusFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
immerseusFrame:RegisterEvent("SPELL_CAST_START");
immerseusFrame:RegisterEvent("SPELL_AURA_APPLIED");
immerseusFrame:RegisterEvent("SPELL_CAST_SUCCESS");
-----------------------------------------DECLARATION VARIABLES LOCALES----------------------------------------------
local spec = nil; --contient les informations sur la spécialisation actuelle
local specName = nil; --contient le nom de notre spécialsiation
local specId = nil; --contient l'id de notre spécialsiation
local specRole = nil; --role de notre specialisation


local bonRaid = 0;

--fonction stratégie Boss
local function stratImmerseus()
	local CombatFrame = CreateFrame("Frame")
	print("Le combat contre Immerseus a debute! Bonne chance :)");
	--Verifie si nous sommes en combat ou non. Permet notamment à mesurer la durée du combat
	CombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
	CombatFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
	CombatFrame:SetScript("OnEvent", function(self, event, ...)
		if(event=="PLAYER_REGEN_DISABLED") then 
			print("test");
		end
	end)
end

---------------------------------CODE--------------------------------------
--Lorsque l'on entre dans le bon raid, afficher diverse info
areaFrame:SetScript("OnEvent", function(self, event, ...)
	local raidNom,_,_,_,_,_,_,raidID = GetInstanceInfo(); --name, type, difficultyIndex, difficulty Name, maxPlayers, dynamicDifficulty, isDynamic, mapID
	if(raidID==1136) then	--Si c'est le raide siège d'orgrimmar..
		PlaySoundKitID(11466) --Joue un son vous n'êtes pas pret
		print("Bienvenue dans le Siege d'Orgrimmar!");
		print("Test nom de la zone: "..raidNom);
		print("Id du raid: "..raidID);
		bonRaid=1;
	end
end)

inCombatFrame:SetScript("OnUpdate", function(self, event)
	if (bonRaid==1) then
		if(UnitAffectingCombat("boss1")) then
			--DEFINITION DU ROLE
			inCombatFrame:Hide();
			spec = GetSpecialization() --retourne id, name, description, icon, background, role
			specName = spec and select(2, GetSpecializationInfo(spec)) or "None" --Nom de la spe
			specId = spec and select(1, GetSpecializationInfo(spec)) or "None" --ID de la spe
			specRole = spec and select(6, GetSpecializationInfo(spec)) or "None" --role de la spe, retourne DAMAGER pour dps, HEALER pour heal, et TANK pour tank
			print("Your current spec: "..specName..", ID= "..specId);
			print ("Vous endossez le role de "..specRole);
		end
	end
end)



------------------TEST EN FONCTION DES SPECIALISATIONS

-- --SI la spécialisation correspond au role tank: (recuperation de toutes les spe qui tank)
-- if(specId==250 or specId==104 or specId==268 or specId==66 or specId==73) then --chevalier de la mort sang, druide gardien, moine maitre-brasseur, paladin protection, guerrier protection
	-- role="tank";
-- end
--Role heal
-- if(specId==105 or specId==270 or specId==65 or specId==256  or specId==257 or specId==264) then --Druide restauration, moine tisse-brume, paladin sacré, pretre discipline, pretre sacré, shaman restauration
	-- role="heal";
-- end
-- --Role dps
-- if(specId==251 or specId==252 or specId==102 or specId==103 or specId==253 or specId==254 or specId==255 or specId==62 or specId==63 or specId==64 or specId==269 or specId==70 or specId==259 or specId==260 or specId==261 or specId==262 or specId==263 or specId==265 or specId==266 or specId==267 or specId==71 or specId==72) then
	-- role="dps";
-- end
-- Death Knight 
-- 250 - Blood
-- 251 - Frost
-- 252 - Unholy
-- Druid 
-- 102 - Balance
-- 103 - Feral Combat
-- 104 - Guardian
-- 105 - Restoration
-- Hunter 
-- 253 - Beast Mastery
-- 254 - Marksmanship
-- 255 - Survival
-- Mage 
-- 62 - Arcane
-- 63 - Fire
-- 64 - Frost
-- Monk 
-- 268 - Brewmaster
-- 269 - Windwalker
-- 270 - Mistweaver
-- Paladin 
-- 65 - Holy
-- 66 - Protection
-- 70 - Retribution
-- Priest 
-- 256 Discipline
-- 257 Holy
-- 258 Shadow
-- Rogue 
-- 259 - Assassination
-- 260 - Combat
-- 261 - Subtlety
-- Shaman 
-- 262 - Elemental
-- 263 - Enhancement
-- 264 - Restoration
-- Warlock 
-- 265 - Affliction
-- 266 - Demonology
-- 267 - Destruction
-- Warrior 
-- 71 - Arms
-- 72 - Fury
-- 73 - Protection
