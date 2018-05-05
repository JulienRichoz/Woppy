---------------------------------------------------------------------------------------------------------------
--Titre: 1.3main.lua
--Date: 18.05.2016
--Version 1.3
--Auteur: Richoz Julien
--Description v. 1.3: Gestion des alertes sonores et visuelles

--Versions antérieures: 
--		v. 1.0: "lancer" l'addon lorsque l'on entre dans le bon raid
--		v. 1.1:	Détection combat contre le boss
--		v. 1.2: Gestion des rôles et spécialisations
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------

----------------------------------------DECLARATION CAPTURE EVENEMENT--------------------------------------------
--capturer zone
local areaFrame = CreateFrame("Frame");
areaFrame:RegisterEvent("PLAYER_ENTERING_WORLD"); --event fire au moment de la conenction dans le jeu
areaFrame:RegisterEvent("ZONE_CHANGED_INDOOR"); --event fire quand le personnage entre dans une instance 

--capturer en combat ou non
-- local playerCombatFrame = CreateFrame("Frame");
-- playerCombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED"); --personnage ne combat pas
-- playerCombatFrame:RegisterEvent("PLAYER_REGEN_DISABLED"); --personnage en combat
-- playerCombatFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT"); --un boss de l'instance ou raid en combat

--capturer boss combat. Frame similaire créée au dessus mais celle-ci sera un OnUpdate et nous devrons la cacher après son utilsiation
local inCombatFrame = CreateFrame("Frame");
inCombatFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT");

--Frame pour capturer les sorts que le boss lance
local immerseusFrame = CreateFrame("Frame");
immerseusFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");

-----------------------------------------DECLARATION VARIABLES LOCALES----------------------------------------------
local spec = nil; --contient les informations sur la spécialisation actuelle
local specName = nil; --contient le nom de notre spécialsiation
local specId = nil; --contient l'id de notre spécialsiation
local specRole = nil; --role de notre specialisation

local flag=0; --definit si une frame a déjà été lancée ou non
local flagVieBoss=0; --evite de spamemr un message d'alerte
local bonRaid = 0;

--Fonction pour retourner vie boss (auteur: Waverian, code récupéré sur http://www.wowinterface.com/forums/showthread.php?t=32350)
--Très difficile de retourner la vie du boss via l'ID du boss. Seul moyen abordable est par le target -> on scan l'ensemble du raid qui l'a en target si jamais nous ne l'avons pas et analysons la vie du boss
local IMMERSEUS = "Immerseus"


end
-----------------------------Fonction Stratégie Immerseus---------------------------------------------------------
local function stratImmerseus()
	--Sorts du boss
	local explosionCaustique = GetSpellInfo(143436);
	local shaSuitant = GetSpellInfo(143286);
	local tourbillon = GetSpellInfo(143309);
	print("Strat Immerseus dedans-debut");
	
	immerseusFrame:SetScript("OnEvent", function(self, event, ...)
		if(event == "COMBAT_LOG_EVENT_UNFILTERED") then 
			local unitImmerseus = ScanForUnit(IMMERSEUS);
			local vieBoss = UnitHealth(unitImmerseus)/UnitHealthMax(unitImmerseus)*100;
			local corruptionBoss = UnitPower(unitImmerseus);
			local timestamp,event,hideCaster,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2,spellID,spellName= select ( 1 , ... ); --recupère les info par évènement (notamment sorts lancé)
			--Si la vie du boss est inférieure à 3%, message d'alerte pour se disperser car passage en P2
			if(vieBoss<3 and flagVieBoss==0) then 
				RaidNotice_AddMessage(RaidWarningFrame, "!DISPERSEZ VOUS POUR LA PHASE 2!", ChatTypeInfo["RAID_WARNING"]);
				flagVieBoss=1; --evite de spammer le message
			end			
			
			if(vieBoss<=0 and corruptionBoss>0) then
				RaidNotice_AddMessage(RaidWarningFrame, "PHASE 2", ChatTypeInfo["RAID_WARNING"]);
			end
			--corruption = /run print(UnitPower("target"))
			
			--Analyse des sorts lancés par immerseus
			if(sourceName=="Immerseus") then
				if(event == "SPELL_CAST_START") then
					print("immerseus casting "..spellName);
					if(spellName == tourbillon) then
						RaidNotice_AddMessage(RaidWarningFrame, "TOURBILLON INC! NE PAS RESTER FACE AU BOSS!", ChatTypeInfo["RAID_WARNING"]);
					end
					else if(spellName == explosionCaustique) then
						print("Attention de ne pas avoir 2 stack");
					end
				end
				if(event == "SPELL_CAST_SUCCESS" and spellName== explosionCaustique) then
					print("aie aie reste au cac du boss");
				end
				-- if(event=="SPELL_AURA_APPLIED") then 
					-- print("immerseus a lance "..spellName);
				-- end
				-- if(event=="SPELL_CAST_SUCCESS") then 	
					-- print("Spell cast success: "..spellName);
				-- end
			end
			
		end

		if(event == "PLAYER_REGEN_ENABLED") then 
			print("Fin du combat");
			flag=1;
			immerseusFrame:Hide();
		end
	end)

	print("Strat Immerseus dedans-fin");
end	

RaidNotice_AddMessage(RaidWarningFrame,"Bienvenue Boolkin",ChatTypeInfo["RAID_WARNING"]); --Fonction pour afficher message
--A FAIRE: QUAND ON SORT DESACTIVER ADDON
--REFLECHIR SUR LES FRAMES POUR RESOUDRE PROBLEME, PLACER FRAME PLAYER ENTERING WORLD UN PEU APRTOUT?
--AJOUTER UN REGEN DISABLED ET VERIFIER LA DESSUS EGALEMENT

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
			stratImmerseus();
		end
	end
end)


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
