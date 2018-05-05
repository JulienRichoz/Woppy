---------------------------------------------------------------------------------------------------------------
--Titre: 1.6main.lua
--Date: 25.05.2016
--Version 1.6
--Auteur: Richoz Julien
--Description v. 1.6: Gestion des stacks
--Am�liorations: revue des passages de phase, gestion des stacks, fonctions pour r�cuperer debuff, cr�ation timer

--Versions ant�rieures: 
--		v. 1.0: "lancer" l'addon lorsque l'on entre dans le bon raid
--		v. 1.1:	D�tection combat contre le boss
--		v. 1.2: Gestion des r�les et sp�cialisations
--		v. 1.3: Gestion des alertes sonores et visuelles
--		v. 1.4.1: Gestion des sorts 
--		v. 1.4.2: Gestion des sorts plus pouss�es
--		v. 1.5: Gestion des lancement de sorts d'Immerseus
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------

----------------------------------------DECLARATION CAPTURE EVENEMENT--------------------------------------------
--capturer zone
local areaFrame = CreateFrame("Frame");
areaFrame:RegisterEvent("PLAYER_ENTERING_WORLD"); --event fire au moment de la conenction dans le jeu
areaFrame:RegisterEvent("ZONE_CHANGED_INDOOR"); --event fire quand le personnage entre dans une instance 

--capturer boss combat. Frame similaire cr��e au dessus mais celle-ci sera un OnUpdate et nous devrons la cacher apr�s son utilsiation
local inCombatFrame = CreateFrame("Frame");
inCombatFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT");

--Frame pour capturer les sorts que le boss lance
local immerseusFrame = CreateFrame("Frame");
immerseusFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
immerseusFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
immerseusFrame:RegisterEvent("SPELL_CAST_START");
immerseusFrame:RegisterEvent("SPELL_AURA_APPLIED");
immerseusFrame:RegisterEvent("SPELL_CAST_SUCCESS");
immerseusFrame:RegisterEvent("SPELL_AURA");
immerseusFrame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE");

-----------------------------------------DECLARATION VARIABLES LOCALES----------------------------------------------
woppy_spec = nil; --contient les informations sur la sp�cialisation actuelle
woppy_specName = nil; --contient le nom de notre sp�cialsiation
woppy_specId = nil; --contient l'id de notre sp�cialsiation
woppy_specRole = nil; --role de notre specialisation

woppy_flag=0; --definit si une frame a d�j� �t� lanc�e ou non
woppy_flagVieBoss=0; --evite de spamemr un message d'alerte
woppy_flagStack=0;
woppy_phase = 1; --evite le calcul de la vie du boss quand il est "mort" et cause erreurs
woppy_test = 1;

woppy_unitImmerseus=nil;
woppy_vieBoss=nil;
woppy_corruptionBoss=nil;

--3.1 Fonction pour retourner vie boss (auteur: Waverian, code r�cup�r� et modifi� sur http://www.wowinterface.com/forums/showthread.php?t=32350)
--Tr�s difficile de retourner la vie du boss via l'ID du boss. Seul moyen abordable est par le target -> on scan l'ensemble du raid qui l'a en target si jamais nous ne l'avons pas et analysons la vie du boss
local IMMERSEUS="Immerseus";
local ScanForUnit = function(name)
	local nbJoueur=GetNumGroupMembers();
	if(nbJoueur>1) then 
		if(UnitName("target")== name) then
			return "target";
		elseif (UnitName("focus") == name) then
			return "focus";
		elseif (UnitName("pettarget")== name) then
			return "pettarget";
		else
			for i = 1, nbJoueur do
				local unit = ("raid%dtarget"):format(i);
				if (UnitName(unit) == name) then 
					return unit ;
				end
			end
		end
	end
	--Si on est seul
	if(nbJoueur==0) then 
		if(UnitName("target")==name) then
			return "target";
		end		
	end
end

--3.2 Fonction pour r�cuprer debuff stack explosion caustique
local ScanForDebuff = function(idDebuff)
	local nbJoueur=GetNumGroupMembers();
	local playerUnit=UnitName("player");
	--Si groupe de raid
	if(nbJoueur>1) then
		for i = 1, nbJoueur do
			local unit = ("raid%d"):format(i);
			for i=1,5 do 
				local name, rank, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate, spellID= UnitDebuff(unit ,i);
				if(spellID==idDebuff) then 
					if(unit~=playerUnit) then
						return RaidNotice_AddMessage(RaidWarningFrame, "Reprenez l'aggro du boss!", ChatTypeInfo["RAID_WARNING"]);
					end
				end
			end
		end
	end
	--Si seul
	if(nbJoueur==0) then
		return;
	end
end
	
-----3.3 Fonction strat�gie phase 2
local phase2 = function(role)
	if(role=="TANK" or role=="DAMAGER") then
		return RaidNotice_AddMessage(RaidWarningFrame, "DPS GLOBULES NOIRES", ChatTypeInfo["RAID_WARNING"]);
	elseif(role=="HEALER") then
		return RaidNotice_AddMessage(RaidWarningFrame, "HEAL GLOBULES VERTES", ChatTypeInfo["RAID_WARNING"]);
	end
end
----------------------------3) FONCTION STRAT IMMERSEUS---------------------------------------------------------
local function StratImmerseus()
	--Sorts du boss
	local explosionCaustique = GetSpellInfo(143436);
	local shaSuitant = GetSpellInfo(143286);
	local tourbillon = GetSpellInfo(143309);
	local scission = GetSpellInfo(143020);
	local projectionSha = GetSpellInfo(143298);
	print("Strat Immerseus dedans-debut");
	
	immerseusFrame:SetScript("OnEvent", function(self, event, ...)
		if(event=="COMBAT_LOG_EVENT_UNFILTERED") then 
			local timestamp,event,hideCaster,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2,spellID,spellName= select ( 1 , ... ); --recup�re diverses infos � chaque event �v�nement (notamment sorts lanc�)
			--scan des unit�s ciblants immerseus pour r�cuperer ses pdv et ses ressources (corruption)	
		--	if(woppy_phase==1) then --seulement en phase car g�n�re erreur en P2
				woppy_unitImmerseus = ScanForUnit(IMMERSEUS);
				woppy_vieBoss = UnitHealth(woppy_unitImmerseus)/UnitHealthMax(woppy_unitImmerseus)*100;
				woppy_corruptionBoss = UnitPower(woppy_unitImmerseus);
		--	end
			--Si la vie du boss est inf�rieure � 3%, message d'alerte pour se disperser car passage en P2
			if(woppy_vieBoss<7 and woppy_flagVieBoss==0) then 
				woppy_flagVieBoss=1; --evite de spammer le message
				RaidNotice_AddMessage(RaidWarningFrame, "!PREPAREZ VOUS A VOUS DISPERSEZ VOUS POUR LA P2!", ChatTypeInfo["RAID_WARNING"]);
				--woppy_phase=2;
				--phase2(woppy_specRole);
			end	
			--Passage en P2
			if(woppy_vieBoss<=1.5 and woppy_flagVieBoss==1) then
				woppy_flagVieBoss=2 --evite de spammer message
				print("phase2");
				woppy_phase=2;
				phase2(woppy_specRole);
			end
			--Passage en P1
			if(woppy_vieBoss>1 and woppy_flagVieBoss==2) then
				woppy_phase=1;
				woppy_flagVieBoss=0;
				RaidNotice_AddMessage(RaidWarningFrame, "PHASE 1", ChatTypeInfo["RAID_WARNING"]);
				print("Phase 1");
			end
			--corruption = /run print(UnitPower("target"))
			
			--Analyse des sorts lanc�s par immerseus
			if(sourceName=="Immerseus") then
				if(event == "SPELL_CAST_START") then
					print("immerseus casting "..spellName);
					if(spellName == tourbillon) then
						RaidNotice_AddMessage(RaidWarningFrame, "TOURBILLON INC! NE PAS RESTER FACE AU BOSS!", ChatTypeInfo["RAID_WARNING"]);
						RaidNotice_AddMessage(RaidWarningFrame, "EVITER LES TOURBILLONS", ChatTypeInfo["RAID_WARNING"]);
					end
					if(spellName == explosionCaustique) then
						print("Attention de ne pas avoir 2 stack");
					end
				end
			end
			
			--Gestion des debuffs
			if (event == "SPELL_AURA_APPLIED") then
				--Gestion de l'AOE (Area Of Effect (damage))
				if(spellName == projectionSha) then 
					RaidNotice_AddMessage(RaidWarningFrame, "{star}!SORS DE L'AOE!", ChatTypeInfo["RAID_WARNING"]);
				end
				--Gestion du stack explosion caustique
				if(spellName == explosionCaustique) then
					print("Arrghhh explosion caustique!!!");
					--On verifie si l'on poss�de le debuff (car un membre du raid peut aussi l'avoir)
					for i=1,5 do 
						local name, rank, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate, spellID= UnitDebuff("player",i); --tous les param�tres que retourne la fonction unitdebuff
						if(spellID==143436) then --explosion caustique	
							woppy_flagStack=0; --eviter de spammer un message situer dans la boucle for apr�s cette fonction
							print("Vous avez "..count.." stack de "..name);
							
							----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
							------!Ne fonctionne pas car aura_applied se d�clenche seulement si c'est un nouveau debuff. Or pour passer � 2 on poss�de d�j� le debuff (Aura_applied_refresh ne fonctionne pas egalement, ne sait pas pourquoi)->solution boucle for apr�s
							-- if(count>1) then
								-- RaidNotice_AddMessage(RaidWarningFrame, "DANGER! TROP DE STACKS!", ChatTypeInfo["RAID_WARNING"]);
							-- end
							-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
							
							--Si l'on est un soigner ou un dps on doit perdre la menace car le boss met le stack � celui qui l'a aggro
							if(woppy_specRole=="HEALER" or woppy_specRole=="DAMAGER") then 
								RaidNotice_AddMessage(RaidWarningFrame, "PERDEZ LA MENACE", ChatTypeInfo["RAID_WARNING"]);
							end
						end
						
						--si on ne poss�de pas le stack et que nous sommes tanks on v�rifie qui du raid poss�de le debuff (reprise aggro)
						if(woppy_specRole == "TANK" and spellName == nil) then 
							ScanForDebuff(143436); --explosion caustique
						end
					end
				end
			end--fin "EVENT_AURA_APPLIED"
			
			--tracker pour voir si stack d'explosion caustique > 1 (car pas d�clench�e par l'event aura_spell_applied)
			for i=1, 5 do
				local debuff, _, _, stack = UnitDebuff("player", i);
				if(debuff==explosionCaustique) then 
					if(stack~=nil and stack>1 and woppy_flagStack==0) then --verifie que l'on poss�de une stack pour ne pas g�n�rer erreur avec nil 
						woppy_flagStack=1; --evite de spam message
						RaidNotice_AddMessage(RaidWarningFrame, "DANGER! TROP DE STACKS!", ChatTypeInfo["RAID_WARNING"]);
					end
				end
			end
		end --fin de l'event "COMBAT_LOG_EVENT_UNFILTERED"

		--Lorsque l'on sort du combat (soit nous sommes morts, soit avons tu� le boss, soit nous nous sommes camoufl�s)
		if(event == "PLAYER_REGEN_ENABLED") then 
			--reinitialisation des variables en dehors de la fonction
			print("Fin du combat");
			woppy_flag=1;
			woppy_flagVieBoss=0;
			woppy_flagStack=0;
			woppy_phase=1;
			woppy_unitImmerseus=nil;
			woppy_vieBoss=nil;
			woppy_corruptionBoss=nil;
			immerseusFrame:Hide();
		end
	end) --fin de la frame Immerseus "OnEvent"
end	 --fin de la fonction Immerseus



-----------------------2) CHECK SI LE BON BOSS COMBAT POUR LANCER LA STRAT--------------------
	local function CheckCombat()
	inCombatFrame:SetScript("OnUpdate", function(self, event)
			if(UnitAffectingCombat("boss1")) then
				--DEFINITION DU ROLE
				inCombatFrame:Hide();
				woppy_spec = GetSpecialization(); --Si jamais changement de sp�cialisation entre le moment ou le personnage entre dans le raid et avant de lancer le combat
				woppy_specRole = woppy_spec and select(6, GetSpecializationInfo(woppy_spec)) or "None";--role de la spe, retourne DAMAGER pour dps, HEALER pour heal, et TANK pour tank
				print("Strategie charg�e pour "..woppy_specRole);
				StratImmerseus();
			end
		--end
	end)
	end

----------------------1) VERIFICATION DE LA BONNE ZONE-----------------------------------------
--Lorsque l'on entre dans le bon raid, afficher diverses infos...
areaFrame:SetScript("OnEvent", function(self, event, ...)
	local raidNom,_,_,_,_,_,_,raidID = GetInstanceInfo(); --name, type, difficultyIndex, difficulty Name, maxPlayers, dynamicDifficulty, isDynamic, mapID
	if(raidID==1136) then	--Si c'est le raide si�ge d'orgrimmar..
		RaidNotice_AddMessage(RaidWarningFrame,"Bienvenue Boolkin",ChatTypeInfo["RAID_WARNING"]); --Fonction pour afficher message
		PlaySoundKitID(11466) --Joue un son vous n'�tes pas pret
		print("Bienvenue dans le Siege d'Orgrimmar!");
		print("Test nom de la zone: "..raidNom);
		print("Id du raid: "..raidID);
		woppy_spec = GetSpecialization() --retourne id, name, description, icon, background, role
		woppy_specName = woppy_spec and select(2, GetSpecializationInfo(woppy_spec)) or "None" --Nom de la spe
		woppy_specId = woppy_spec and select(1, GetSpecializationInfo(woppy_spec)) or "None" --ID de la spe
		woppy_specRole = woppy_spec and select(6, GetSpecializationInfo(woppy_spec)) or "None" --role de la spe, retourne DAMAGER pour dps, HEALER pour heal, et TANK pour tank
		print("Votre specialisation actuelle est: "..woppy_specName..". Vous endossez le role de "..woppy_specRole);
		CheckCombat();
	end
end)


--Tests
		-- --SI la sp�cialisation correspond au role tank: (recuperation de toutes les spe qui tank)
		-- if(woppy_specId==250 or woppy_specId==104 or woppy_specId==268 or woppy_specId==66 or woppy_specId==73) then --chevalier de la mort sang, druide gardien, moine maitre-brasseur, paladin protection, guerrier protection
			-- role="tank";
		-- end
		-- --Role heal
		-- if(woppy_specId==105 or woppy_specId==270 or woppy_specId==65 or woppy_specId==256  or woppy_specId==257 or woppy_specId==264) then --Druide restauration, moine tisse-brume, paladin sacr�, pretre discipline, pretre sacr�, shaman restauration
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
