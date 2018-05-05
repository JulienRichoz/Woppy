---------------------------------------------------------------------------------------------------
--Titre: main.lua
--Date: 12.05.2016
--Version 1.0
--Auteur: Richoz Julien
--Fonction: "lancer" l'addon lorsque l'on entre dans le bon raid
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------


local function maZone()  
	local raidNom,_,_,_,_,_,_,raidID = GetInstanceInfo(); --name, type, difficultyIndex, difficulty Name, maxPlayers, dynamicDifficulty, isDynamic, mapID
	
	--Test si l'on se situe bien dans le bon raid
	if(raidID==1136) then print("Bienvenue dans le Siege d'Orgrimmar!");
		print("Test nom de la zone: "..raidNom);
		print("Id du raid: "..raidID);
		--effectuer le reste du code
	endeffectuer
end


local AreaFrame = CreateFrame("Frame")
AreaFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
AreaFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
AreaFrame:SetScript("OnEvent", function(self, event, ...)
		maZone();
end)
