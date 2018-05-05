--Titre: main.lua
--Date: 12.05.2016
--Version 1.1
--Auteur: Richoz Julien
--Fonction: v1.0:"lancer" l'addon lorsque l'on entre dans le bon raid
--v1.1: Détecter le lancement de combat contre Immerseus afin d'exécuter le code

local function stratImmerseus()
	local CombatFrame = CreateFrame("Frame");
	CombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
	CombatFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
	if(UnitAffectingCombat("boss1")) then 
		print("Le combat contre Immerseus a debute! Bonne chance :)");
	end
	--Verifie si nous sommes en combat ou non. Permet notamment à mesurer la durée du combat
	CombatFrame:SetScript("OnEvent", function(self, event, ...)
		if(event=="PLAYER_REGEN_DISABLED") then 
			print("Le combat commence regen1");
		else print("Le combat est termine");
		end
	end)
end


local function maZone()  
	local raidNom,_,_,_,_,_,_,raidID = GetInstanceInfo(); --name, type, difficultyIndex, difficulty Name, maxPlayers, dynamicDifficulty, isDynamic, mapID
	
	--Test si l'on se situe bien dans le bon raid
	if(raidID==1136) then 
		local bossEngageFrame = CreateFrame("Frame");
		bossEngageFrame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT");
		
		print("Bienvenue dans le Siege d'Orgrimmar!");
		print("Test nom de la zone: "..raidNom);
		print("Id du raid: "..raidID);	
		
		--Si le boss Imemrseus est engagé, on lance la strat
		bossEngageFrame:SetScript("OnEvent", function(self)
		
			stratImmerseus();
			--if(UnitAffectingCombat("boss1")) then --vérifie si le boss1, à savoir Immerseus est en combat. Si oui on lance la strat
			--	print("unit affecting combat");
			--	stratImmerseus();
			--else print("fail immerseus unit affecting combat");
			--end
		end)
		
	end
end


local AreaFrame = CreateFrame("Frame");
AreaFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
AreaFrame:RegisterEvent("ZONE_CHANGED_INDOORS");

AreaFrame:SetScript("OnEvent", function(self, event, ...)
	if(event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_INDOORS") then
		maZone();
	end
end)
