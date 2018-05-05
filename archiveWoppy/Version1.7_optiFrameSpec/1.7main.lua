---------------------------------------------------------------------------------------------------------------
--Titre: 1.7main.lua
--Date: 26.05.2016
--Version 1.7
--Auteur: Richoz Julien
--Description v. 1.7: meilleure gestion des frames
--Améliorations: frames appelées le plus possible dans la fonction, meilleure optimisation en cas de changement de spécialsiation

--Versions antérieures: 
--		v. 1.0: "lancer" l'addon lorsque l'on entre dans le bon raid
--		v. 1.1:	Détection combat contre le boss
--		v. 1.2: Gestion des rôles et spécialisations
--		v. 1.3: Gestion des alertes sonores et visuelles
--		v. 1.4.1: Gestion des sorts 
--		v. 1.4.2: Gestion des sorts plus poussées
--		v. 1.5: Gestion des lancement de sorts d'Immerseus
--		v. 1.6: Gestion des stacks
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------

----------------------------------------DECLARATION CAPTURE EVENEMENT--------------------------------------------
--capturer zone
local areaFrame = CreateFrame("Frame");
areaFrame:RegisterEvent("PLAYER_ENTERING_WORLD"); --event fire au moment de la conenction dans le jeu
areaFrame:RegisterEvent("ZONE_CHANGED_INDOOR"); --event fire quand le personnage entre dans une instance 
	
local specFrame = CreateFrame("Frame");
specFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
-----------------------------------------DECLARATION VARIABLES----------------------------------------------------
woppy_spec = nil; --contient les informations sur la spécialisation actuelle
woppy_specName = nil; --contient le nom de notre spécialsiation
woppy_specId = nil; --contient l'id de notre spécialsiation
woppy_specRole = nil; --role de notre specialisation

woppy_flag=0; --definit si une frame a déjà été lancée ou non
woppy_flagVieBoss=0; --evite de spamemr un message d'alerte
woppy_flagStack=0;
woppy_phase = 1; --evite le calcul de la vie du boss quand il est "mort" et cause erreurs
woppy_test = 1;
woppy_startTime=nil;
woppy_unitImmerseus=nil;
woppy_vieBoss=nil;
woppy_corruptionBoss=nil;

--3.1 Fonction pour retourner vie boss (auteur: Waverian, code récupéré et modifié sur http://www.wowinterface.com/forums/showthread.php?t=32350)
--Très difficile de retourner la vie du boss via l'ID du boss. Seul moyen abordable est par le target -> on scan l'ensemble du raid qui l'a en target si jamais nous ne l'avons pas et analysons la vie du boss
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

--3.2 Fonction pour récuprer debuff stack explosion caustique
local ScanForDebuff = function(idDebuff)
	local nbJoueur=GetNumGroupMembers();
	local playerUnit=UnitName("player");
	--Si groupe de raid
	if(nbJoueur>1) then
		for i = 1, nbJoueur do
			local unit = ("raid%d"):format(i);
			--On parcours l'ensemble des debuff du joueurs (pouvant aller jusqu'a 40 mais sur ce boss 3 max, donc 5 pour être sur)
			for i=1,5 do 
				local name, rank, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate, spellID= UnitDebuff(unit ,i); --on stock les info du debuff
				if(spellID==idDebuff) then 
					if(unit~=playerUnit) then --Si ce n'est pas lui qui possède le debuff (il ne peut pas reprendre l'aggro du boss s'il l'a déjà)
						return RaidNotice_AddMessage(RaidWarningFrame, "Reprenez l'aggro du boss!", ChatTypeInfo["RAID_WARNING"]);
					end
				end
			end
		end
	end
	--Si nous faisons le raid seul
	if(nbJoueur==0) then
		return;
	end
end
	
-----3.3 Fonction stratégie phase 2
local phase2 = function(role)
	if(role=="TANK" or role=="DAMAGER") then
		return RaidNotice_AddMessage(RaidWarningFrame, "DPS GLOBULES NOIRES", ChatTypeInfo["RAID_WARNING"]);
	elseif(role=="HEALER") then
		return RaidNotice_AddMessage(RaidWarningFrame, "HEAL GLOBULES VERTES", ChatTypeInfo["RAID_WARNING"]);
	end
end


---3.4 Fonction convertir seconde en minute (timer)
local calculTime = function(duree) --duree en seconde
	local minute=math.floor(duree/60) --normalement rajouter après le/60 un %60 mais le math.floor fait l'affaire
	local seconde = duree % 60; 
	if(minute<1) then
		return print("Le combat a dure "..duree.." secondes");
		else
		return print("Le combat a dure "..minute.." min. et "..seconde.." sec.");
	end
end
----------------------------3) FONCTION STRAT IMMERSEUS---------------------------------------------------------
local function StratImmerseus()
	--Frame pour capturer les sorts que le boss lance
	local immerseusFrame = CreateFrame("Frame");
	immerseusFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED"); --Event déclenché à chaque action de combat, autant pour les alliés que les ennemis
	immerseusFrame:RegisterEvent("PLAYER_REGEN_ENABLED"); 	--Event déclenché lorsque nous sortons de combat et pouvons nous régénérer à nouveau
	immerseusFrame:RegisterEvent("SPELL_CAST_START");	--Event déclenché dès que quelqu'un commence à lancer un sort
	immerseusFrame:RegisterEvent("SPELL_AURA_APPLIED"); --Event déclenché lorsque nous reçevons un nouveau buff/debuff
	immerseusFrame:RegisterEvent("SPELL_CAST_SUCCESS");	--Event déclénché si le sort casté s'est lancé avec succès
	immerseusFrame:RegisterEvent("SPELL_AURA");	--Event déclenché si nous gagnons ou perdons des buffs/debuffs
	
	--Sorts du boss à faire attention
	local explosionCaustique = GetSpellInfo(143436); --sort qui peut s'accumuler. Les tanks doivent le prendre
	local tourbillon = GetSpellInfo(143309); --tourbillon à éviter (ne pas se mettre face au boss et éviter les petits tourbillons)
	local projectionSha = GetSpellInfo(143298); --zone à effet de dommage au sol auquel il faut en sortir le plus rapidement possible
	local lastCorruptionBoss=100;
	local resetTime=1;
	
	
	print("Debut du combat contre Immerseus! Bonne chance :-)");
	immerseusFrame:SetScript("OnEvent", function(self, event, ...)
		if(event=="COMBAT_LOG_EVENT_UNFILTERED") then 
			local timestamp,event,hideCaster,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2,spellID,spellName= select ( 1 , ... ); --recupère les info de l'event COMBAT_LOG_EVENT_UNFILTERED.
			if(resetTime==1) then 
				resetTime=0;
				woppy_startTime = time();
			end
			--scan des unités ciblants immerseus pour récuperer ses pdv et ses ressources (corruption)	
			woppy_unitImmerseus = ScanForUnit(IMMERSEUS);
			woppy_vieBoss = UnitHealth(woppy_unitImmerseus)/UnitHealthMax(woppy_unitImmerseus)*100;
			woppy_corruptionBoss = UnitPower(woppy_unitImmerseus);
			
			--fin du combat
			if(woppy_corruptionBoss<1) then 
				print("Immerseus vaincu! Felicitations");
			end

			--Si la vie du boss est inférieure à 3%, message d'alerte pour se disperser car passage en P2
			if(woppy_vieBoss<7 and woppy_flagVieBoss==0) then 
				woppy_flagVieBoss=1; --evite de spammer le message
				RaidNotice_AddMessage(RaidWarningFrame, "!PREPAREZ VOUS A VOUS DISPERSEZ VOUS POUR LA P2!", ChatTypeInfo["RAID_WARNING"]);
			end	
			--Passage en P2
			if(woppy_vieBoss<=1.5 and woppy_flagVieBoss==1) then
				woppy_flagVieBoss=2 --evite de spammer message
				print("Phase 2");
				woppy_phase=2;
				phase2(woppy_specRole);
			end
			--Passage en P1
			if(woppy_vieBoss>1.5 and woppy_flagVieBoss==2) then
				woppy_phase=1;
				woppy_flagVieBoss=0;
				RaidNotice_AddMessage(RaidWarningFrame, "PHASE 1", ChatTypeInfo["RAID_WARNING"]);
				print("Phase 1");
			end
			
			--Analyse des sorts lancés par immerseus
			if(sourceName=="Immerseus") then
				if(event == "SPELL_CAST_START") then
					print("immerseus casting "..spellName);
					if(spellName == tourbillon) then
						PlaySoundKitID(11466) --Joue un son vous n'êtes pas pret
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
					PlaySoundKitID(11466) --Joue un son vous n'êtes pas pret
					RaidNotice_AddMessage(RaidWarningFrame, "!SORS DE L'AOE!", ChatTypeInfo["RAID_WARNING"]);
				end
				--Gestion du stack explosion caustique
				if(spellName == explosionCaustique) then
					print("Arrghhh explosion caustique!!!");
					--On verifie si l'on possède le debuff (car un membre du raid peut aussi l'avoir)
					for i=1,5 do 
						local name, rank, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate, spellID= UnitDebuff("player",i); --tous les paramètres que retourne la fonction unitdebuff
						if(spellID==143436) then --explosion caustique	
							woppy_flagStack=0; --eviter de spammer un message situer dans la boucle for après cette fonction
							print("Vous avez "..count.." stack de "..name);					
							--Si l'on est un soigner ou un dps on doit perdre la menace car le boss met le stack à celui qui l'a aggro
							if(woppy_specRole=="HEALER" or woppy_specRole=="DAMAGER") then 
								RaidNotice_AddMessage(RaidWarningFrame, "PERDEZ LA MENACE", ChatTypeInfo["RAID_WARNING"]);
							end
						end
						--si on ne possède pas le stack et que nous sommes tanks on vérifie qui du raid possède le debuff (reprise aggro)
						if(woppy_specRole == "TANK" and spellName == nil) then 
							ScanForDebuff(143436); --explosion caustique
						end
					end
				end
			end--fin "EVENT_AURA_APPLIED"
			
			--tracker pour voir si stack d'explosion caustique > 1 (car pas déclenchée par l'event aura_spell_applied)
			for i=1, 5 do
				local debuff, _, _, stack = UnitDebuff("player", i);
				if(debuff==explosionCaustique) then 
					if(stack~=nil and stack>1 and woppy_flagStack==0) then --verifie que l'on possède une stack pour ne pas générer erreur avec nil 
						woppy_flagStack=1; --evite de spam message
						PlaySoundKitID(11466) --Joue un son vous n'êtes pas pret
						RaidNotice_AddMessage(RaidWarningFrame, "DANGER! TROP DE STACKS!", ChatTypeInfo["RAID_WARNING"]);
					end
				end
			end
		end --fin de l'event "COMBAT_LOG_EVENT_UNFILTERED"

		--Lorsque l'on sort du combat (soit nous sommes morts, soit avons tué le boss, soit nous nous sommes camouflés)
		if(event == "PLAYER_REGEN_ENABLED") then 
			--reinitialisation des variables en dehors de la fonction
			print("Fin du combat");
			local endTime=time();
			local dureeCombat = endTime - woppy_startTime;
			calculTime(dureeCombat); 
			resetTime=1;
			woppy_flag=1;
			woppy_flagVieBoss=0;
			woppy_flagStack=0;
			woppy_phase=1;
			woppy_unitImmerseus=nil;
			woppy_vieBoss=nil;
			woppy_corruptionBoss=nil;
		end
	end) --fin de la frame Immerseus "OnEvent"
end	 --fin de la fonction Immerseus



-----------------------2) CHECK SI LE BON BOSS COMBAT POUR LANCER LA STRAT--------------------
	local function CheckCombat()
	--capturer boss combat. Frame similaire créée au dessus mais celle-ci sera un OnUpdate et nous devrons la cacher après son utilsiation
	local inCombatFrame = CreateFrame("Frame");
	inCombatFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT");
	inCombatFrame:SetScript("OnUpdate", function(self, event)
			if(UnitAffectingCombat("boss1")) then
				inCombatFrame:Hide();
				StratImmerseus();
			end
		--end
	end)
	end

------------------------1) VERIFICATION DE LA BONNE ZONE-----------------------------------------
--Lorsque l'on entre dans le bon raid, afficher diverses infos...
areaFrame:SetScript("OnEvent", function(self, event, ...)
	local raidNom,_,_,_,_,_,_,raidID = GetInstanceInfo(); --name, type, difficultyIndex, difficulty Name, maxPlayers, dynamicDifficulty, isDynamic, mapID
	if(raidID==1136) then	--Si 	c'est le raide siège d'orgrimmar..
		RaidNotice_AddMessage(RaidWarningFrame,"Bienvenue Boolkin",ChatTypeInfo["RAID_WARNING"]); --Fonction pour afficher message
		PlaySoundKitID(1177) --Joue un son 
		--Murloc: 11802
		--Dramatic: 11706
		--1176-1180: Pig sound
		--11466: vous netes pas pret (Illidan)
		--SSON FLAQUE /script PlaySoundFile("Sound\\Doodad\\ArcaneCrystalOpen.ogg")

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

--Si l'on change de role dans le raid, reattribution correcte	
specFrame:SetScript("Onevent", function(self, event, ...)
	woppy_spec = GetSpecialization(); --Si jamais changement de spécialisation entre le moment ou le personnage entre dans le raid et avant de lancer le combat
	woppy_specRole = woppy_spec and select(6, GetSpecializationInfo(woppy_spec)) or "None";--role de la spe, retourne DAMAGER pour dps, HEALER pour heal, et TANK pour tank
	print("Vous avez change de specialisation et endossez desormais le role de "..woppy_specRole);
end)