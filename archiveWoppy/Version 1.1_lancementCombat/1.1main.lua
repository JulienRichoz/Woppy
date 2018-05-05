--------------------------------------------------------------------------------------------
--Titre: 1.1main.lua
--Date: 12.05.2016
--Version 1.1
--Auteur: Richoz Julien
--Description v. 1.1: Détecter le lancement de combat contre Immerseus afin d'exécuter le code

--Versions antérieures: 
--		v1.0:"lancer" l'addon lorsque l'on entre dans le bon raid
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------

------TEST INUTILES...--------------
--for i = 1, 10, 1 do
--	print("Le boss numero "..i.." est-il en combat?");
--	print(UnitAffectingCombat("boss"..i));
--end

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

--fonction détecter bonne zone
local function maZone()  
	local raidNom,_,_,_,_,_,_,raidID = GetInstanceInfo(); --name, type, difficultyIndex, difficulty Name, maxPlayers, dynamicDifficulty, isDynamic, mapID
	
	--Test si l'on se situe bien dans le bon raid
	if(raidID==1136) then print("Bienvenue dans le Siege d'Orgrimmar!");
		print("Test nom de la zone: "..raidNom);
		print("Id du raid: "..raidID);
		
		--Strat Imemrseus
		if(UnitAffectingCombat("boss1")) then --vérifie si le boss1, à savoir Immerseus est en combat. Si oui on lance la strat
			stratImmerseus();
		end
	end
end

--Frame enregistrer changement de zone
local AreaFrame = CreateFrame("Frame");
AreaFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
AreaFrame:RegisterEvent("ZONE_CHANGED_INDOORS");

--Test changemetn de zone
AreaFrame:SetScript("OnEvent", function(self, event, ...)
	if(event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_INDOORS") then
		maZone();
	end
end)
