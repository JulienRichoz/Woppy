---------------------------------------------------------------------------------------------------------------
--Titre: 1.4.2main.lua
--Date: 20.05.2016
--Version 1.4.2
--Auteur: Richoz Julien
--Description v. 1.4.2: Gestion plus poussée des sorts
--Améliorations: Fonction pour la phase 2
--Versions antérieures: 
--		v. 1.0: "lancer" l'addon lorsque l'on entre dans le bon raid
--		v. 1.1:	Détection combat contre le boss
--		v. 1.2: Gestion des rôles et spécialisations
--		v. 1.3: Gestion des alertes sonores et visuelles
--		v. 1.4.1: Gestion des sorts 
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------

--J'étais rester bloqué avec le passage phase 2 et l'affichage de caustiques correctes.
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
woppy_spec = nil; --contient les informations sur la spécialisation actuelle
woppy_specName = nil; --contient le nom de notre spécialsiation
woppy_specId = nil; --contient l'id de notre spécialsiation
woppy_specRole = nil; --role de notre specialisation

woppy_flag=0; --definit si une frame a déjà été lancée ou non
woppy_flagVieBoss=0; --evite de spamemr un message d'alerte
woppy_bonRaid = 0;

--Fonction pour retourner vie boss (auteur: Waverian, code récupéré sur http://www.wowinterface.com/forums/showthread.php?t=32350)
--Très difficile de retourner la vie du boss via l'ID du boss. Seul moyen abordable est par le target -> on scan l'ensemble du raid qui l'a en target si jamais nous ne l'avons pas et analysons la vie du boss
local IMMERSEUS = "Immerseus"

local ScanForUnit = function(name)
	if(UnitName("target")== name) then
		return "target"
	elseif (UnitName("focus") == name) then
		return "focus"
	elseif (UnitName("pettarget")== name) then
		return "pettarget"
	else
		for i = 1, GetNumRaidMembers() do
			local unit = ("raid%dtarget"):format(i)
			if (UnitName(unit) == name) then return unit end
		end
	end
end

	
--Fonction Phase 2
local phase2 = function(role)
	if(role=="TANK" or role=="DAMAGER") then
		return RaidNotice_AddMessage(RaidWarningFrame, "DPS GLOBULEs NOIRES, heal vert au besoin", ChatTypeInfo["RAID_WARNING"]);
	elseif(role=="HEALER") then
		return RaidNotice_AddMessage(RaidWarningFrame, "HEAL GLOBULES VERTES, dps noirs au besoin", ChatTypeInfo["RAID_WARNING"]);
	end
end
-----------------------------Fonction Stratégie Immerseus---------------------------------------------------------
local function stratImmerseus()
	--Sorts du boss
	local explosionCaustique = GetSpellInfo(143436);
	local shaSuitant = GetSpellInfo(143286);
	local tourbillon = GetSpellInfo(143309);
	local scission = GetSpellInfo(143020);
	print("Strat Immerseus dedans-debut");
	
	immerseusFrame:SetScript("OnEvent", function(self, event, ...)
		if(event == "COMBAT_LOG_EVENT_UNFILTERED") then 
			--scan des unités ciblants immerseus pour récuperer ses pdv et ses ressources (corruption)
			local unitImmerseus = ScanForUnit(IMMERSEUS);
			local vieBoss = UnitHealth(unitImmerseus)/UnitHealthMax(unitImmerseus)*100;
			local corruptionBoss = UnitPower(unitImmerseus);
			
			local timestamp,event,hideCaster,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2,spellID,spellName= select ( 1 , ... ); --recupère les info par évènement (notamment sorts lancé)

			--Si la vie du boss est inférieure à 3%, message d'alerte pour se disperser car passage en P2
			if(vieBoss<3 and woppy_flagVieBoss==0) then 
				RaidNotice_AddMessage(RaidWarningFrame, "!DISPERSEZ VOUS POUR LA PHASE 2!", ChatTypeInfo["RAID_WARNING"]);
				woppy_flagVieBoss=1; --evite de spammer le message
			end			
			--corruption = /run print(UnitPower("target"))
			
			--Analyse des sorts lancés par immerseus
			if(sourceName=="Immerseus") then
				if(event == "SPELL_CAST_START") then
					print("immerseus casting "..spellName);
					if(spellName == scission) then
						RaidNotice_AddMessage(RaidWarningFrame, "PHASE 2", ChatTypeInfo["RAID_WARNING"]);
						woppy_flagVieBoss=1;
						phase2(role);
					end
					if(spellName == tourbillon) then
						RaidNotice_AddMessage(RaidWarningFrame, "TOURBILLON INC! NE PAS RESTER FACE AU BOSS!", ChatTypeInfo["RAID_WARNING"]);
					elseif(spellName == explosionCaustique) then
						print("Attention de ne pas avoir 2 stack");
						explosionCaustique=nil; --evite de spam le message
					end
				end
				if(spellName==scission and woppy_flagVieBoss==1 or event=="SPELL_CAST_SUCCESS") then
					print("Phase 2");
					RaidNotice_AddMessage(RaidWarningFrame, "PHASE 2", ChatTypeInfo["RAID_WARNING"]);
					woppy_flagVieBoss=0;
					phase2(woppy_specRole);
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
			woppy_flag=1;
			woppy_flagVieBoss=0;
			immerseusFrame:Hide();
		end
	end)
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
		woppy_spec = GetSpecialization() --retourne id, name, description, icon, background, role
		woppy_specName = woppy_spec and select(2, GetSpecializationInfo(woppy_spec)) or "None" --Nom de la spe
		woppy_specId = woppy_spec and select(1, GetSpecializationInfo(woppy_spec)) or "None" --ID de la spe
		woppy_specRole = woppy_spec and select(6, GetSpecializationInfo(woppy_spec)) or "None" --role de la spe, retourne DAMAGER pour dps, HEALER pour heal, et TANK pour tank
		print("Votre specialisation actuelle est: "..woppy_specName..". Vous endossez de ce fait le role de "..woppy_specRole);
		woppy_bonRaid=1;
	end
end)

inCombatFrame:SetScript("OnUpdate", function(self, event)
	if (woppy_bonRaid==1) then
		if(UnitAffectingCombat("boss1")) then
			--DEFINITION DU ROLE
			inCombatFrame:Hide();
			woppy_spec = GetSpecialization(); --Si jamais changement de spécialisation entre le moment ou le personnage entre dans le raid et avant de lancer le combat
			woppy_specRole = woppy_spec and select(6, GetSpecializationInfo(woppy_spec)) or "None";--role de la spe, retourne DAMAGER pour dps, HEALER pour heal, et TANK pour tank
			print("Votre specialisation actuelle est: "..woppy_specName..". Vous endossez de ce fait le role de "..woppy_specRole);
			stratImmerseus();
		end
	end
end)














--Tests
		-- --SI la spécialisation correspond au role tank: (recuperation de toutes les spe qui tank)
		-- if(woppy_specId==250 or woppy_specId==104 or woppy_specId==268 or woppy_specId==66 or woppy_specId==73) then --chevalier de la mort sang, druide gardien, moine maitre-brasseur, paladin protection, guerrier protection
			-- role="tank";
		-- end
		-- --Role heal
		-- if(woppy_specId==105 or woppy_specId==270 or woppy_specId==65 or woppy_specId==256  or woppy_specId==257 or woppy_specId==264) then --Druide restauration, moine tisse-brume, paladin sacré, pretre discipline, pretre sacré, shaman restauration
			-- role="heal";
		-- end
		-- --Role dps
		-- if(woppy_specId==251 or woppy_specId==252 or woppy_specId==102 or woppy_specId==103 or woppy_specId==253 or woppy_specId==254 or woppy_specId==255 or woppy_specId==62 or woppy_specId==63 or woppy_specId==64 or woppy_specId==269 or woppy_specId==70 or woppy_specId==259 or woppy_specId==260 or woppy_specId==261 or woppy_specId==262 or woppy_specId==263 or woppy_specId==265 or woppy_specId==266 or woppy_specId==267 or woppy_specId==71 or woppy_specId==72) then
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
