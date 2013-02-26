/*
 * ============================================================================
 *
 *  Original modified Rotoblin module
 *
 *  File:			rotoblin.ItemControl.sp
 *  Type:			Module
 *  Description:	...
 *
 *  Copyright (C) 2012-2013  raziEiL <war4291@mail.ru>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

#define			IC_TAG	"[IteamControl]"

#define GASCAN_MODEL			"models/props_junk/gascan001a.mdl"
#define PROPANE_MODEL		"models/props_junk/propanecanister001a.mdl"
#define OXYGEN_MODEL			"models/props_equipment/oxygentank01.mdl"

#define WEAPINDEX_MOLOTOV		0
#define WEAPINDEX_PIPEBOMB		1
#define WEAPINDEX_PILLS			2

#define MAX_ITEMS					3

#define WEAPINDEX_HUNTINGRIFLE	4
#define WEAPINDEX_PISTOL			5

static const String:g_sSpawnName[MAX_ITEMS][] =
{
	"weapon_molotov_spawn",
	"weapon_pipe_bomb_spawn",
	"weapon_pain_pills_spawn"
};

static const String:g_sName[MAX_ITEMS][] =
{
	"molotov",
	"pipe bomb",
	"pain pills"
};

static	Handle:g_hItemArray[MAX_ITEMS], Handle:g_hItem[MAX_ITEMS], Handle:g_hDensiny[MAX_ITEMS], g_iCvarItem[MAX_ITEMS],
		Handle:g_hRemoveCannisters, Handle:g_hRemoveBarrels, Handle:g_hRemoveHuntingRiffle, Handle:g_hAlterSpawningLogic,
		bool:g_bCvarRemoveCannisters, bool:g_bCvarRemoveBarrels, g_iCvarHuntingRiffle, Handle:g_hRemoveDualPistols,
		bool:g_bCvarRemoveDualPistols, g_iLimit[MAX_ITEMS], g_iPickUp[MAX_ITEMS], bool:g_bAlterSpawningLogic;

_ItemControl_OnPluginStart()
{
	g_hDensiny[WEAPINDEX_MOLOTOV]	= 	FindConVar("director_molotov_density");
	g_hDensiny[WEAPINDEX_PIPEBOMB]	= 	FindConVar("director_pipe_bomb_density");
	g_hDensiny[WEAPINDEX_PILLS]		= 	FindConVar("director_pain_pill_density");

	g_hItem[WEAPINDEX_MOLOTOV] 		=	CreateConVarEx("molotov_limit", 			"0",	"Limits the number of molotov on each map outside of safe rooms. (-1: remove all, 0: director settings, > 0: limit to cvar value)", _, true, -1.0);
	g_hItem[WEAPINDEX_PIPEBOMB] 		=	CreateConVarEx("pipebomb_limit", 			"0",	"Limits the number of pipe-bomb on each map outside of safe rooms. (-1: remove all, 0: director settings, > 0: limit to cvar value)", _, true, -1.0);
	g_hItem[WEAPINDEX_PILLS]			=	CreateConVarEx("pills_limit", 				"0",	"Limits the number of pills on each map outside of safe rooms. (-1: remove all, 0: director settings, > 0: limit to cvar value)", _, true, -1.0);
	g_hRemoveCannisters 				=	CreateConVarEx("remove_cannisters", 		"0",	"Enables or disables cannisters (gascan, propane and oxygen)", _, true, 0.0, true, 1.0);
	g_hRemoveBarrels 					=	CreateConVarEx("remove_explosive_barrels", 	"0", 	"Remove Sacrifice explosive barrels.", _, true, 0.0, true, 1.0);
	g_hRemoveHuntingRiffle			=	CreateConVarEx("remove_huntingrifle", 		"0", 	"Removes all hunting rifles from start saferooms.", _, true, -1.0, true, 1.0);
	g_hRemoveDualPistols				=	CreateConVarEx("remove_pistols", 			"0", 	"Removes all dual pistols.", _, true, 0.0, true, 1.0);
	g_hAlterSpawningLogic				=	CreateConVarEx("spawning_logic", 			"0", 	"Enable alternative spawning logic for items", _, true, 0.0, true, 1.0);

	IC_WipeArray(false);
}

_IC_OnPluginEnabled()
{
	HookEvent("round_start", IC_ev_RoundStart, EventHookMode_PostNoCopy);

	HookConVarChange(g_hItem[WEAPINDEX_MOLOTOV],		IC_OnCvarChange_MolotovLimit);
	HookConVarChange(g_hItem[WEAPINDEX_PIPEBOMB],	IC_OnCvarChange_PipeBombLimit);
	HookConVarChange(g_hItem[WEAPINDEX_PILLS],		IC_OnCvarChange_PainPillsLimit);
	HookConVarChange(g_hRemoveCannisters,				IC_OnCvarChange_RemoveCannisters);
	HookConVarChange(g_hRemoveBarrels,					IC_OnCvarChange_RemoveBarrels);
	HookConVarChange(g_hRemoveHuntingRiffle,			IC_OnCvarChange_RemoveHuntingRiffle);
	HookConVarChange(g_hRemoveDualPistols,			IC_OnCvarChange_RemoveDualPistols);
	HookConVarChange(g_hAlterSpawningLogic,			IC_OnCvarChange_AlterSpawningLogic);
	GetCvars();
}

_IC_OnPluginDisabled()
{
	UnhookEvent("round_start", IC_ev_RoundStart, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hItem[WEAPINDEX_MOLOTOV],		IC_OnCvarChange_MolotovLimit);
	UnhookConVarChange(g_hItem[WEAPINDEX_PIPEBOMB],		IC_OnCvarChange_PipeBombLimit);
	UnhookConVarChange(g_hItem[WEAPINDEX_PILLS],			IC_OnCvarChange_PainPillsLimit);
	UnhookConVarChange(g_hRemoveCannisters,				IC_OnCvarChange_RemoveCannisters);
	UnhookConVarChange(g_hRemoveBarrels,					IC_OnCvarChange_RemoveBarrels);
	UnhookConVarChange(g_hRemoveHuntingRiffle,			IC_OnCvarChange_RemoveHuntingRiffle);
	UnhookConVarChange(g_hRemoveDualPistols,				IC_OnCvarChange_RemoveDualPistols);
	UnhookConVarChange(g_hAlterSpawningLogic,			IC_OnCvarChange_AlterSpawningLogic);

	SetDirectorSettings(g_hDensiny[WEAPINDEX_MOLOTOV],		0);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PIPEBOMB],	0);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PILLS],		0);

	IC_WipeArray(true);
}

_IC_OnMapEnd()
{
	IC_WipeArray(true);
}

IC_WipeArray(bool:bWipe)
{
	for (new INDEX = 0; INDEX < MAX_ITEMS; INDEX++){

		if (bWipe)
			ClearArray(g_hItemArray[INDEX]);
		else
			g_hItemArray[INDEX] = CreateArray(3);

		g_iPickUp[INDEX] = 0;
	}
}

public IC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.6, IC_t_RoundStartDelay);
}

public Action:IC_t_RoundStartDelay(Handle:timer)
{
	DebugLog("%s All exploves props %s removed", IC_TAG, g_bCvarRemoveCannisters ? "were" : "will not be");
	IC_PushAndRandomizeItems();
}

static IC_PushAndRandomizeItems()
{
	decl String:sClass[64], iArraySize[MAX_ITEMS], iWeapIndex, Float:vOrg[3];

	new bool:bFirstRound = FirstRound(), iMaxEnt = GetMaxEntities(), iCount[MAX_ITEMS];

	if (!bFirstRound)
		for (new INDEX = 0; INDEX < MAX_ITEMS; INDEX++)
			iArraySize[INDEX] = GetArraySize(g_hItemArray[INDEX]);

	DebugLog("%s Step 1: %s", IC_TAG, bFirstRound ? "Trying to push items in array" : "Keep item spawns the same on both rounds");

	for (new iEnt = MaxClients; iEnt < iMaxEnt; iEnt++){

		if (!IsValidEntity(iEnt)) continue;

		GetEntityClassname(iEnt, sClass, 64);

		if (StrContains(sClass, "weapon_") != -1 && StrContains(sClass, "_spawn") != -1){

			if (ItemCountFix(iEnt, (iWeapIndex = WeapIDtoIndex(iEnt))) == NULL) continue;

			switch (iWeapIndex){

				case WEAPINDEX_PILLS:{

					if (!IsEntOutSideSafeRoomEx(iEnt)){

						DebugLog("%s  - skipped: pills in safe room", IC_TAG);
						continue;
					}
				}
				case WEAPINDEX_HUNTINGRIFLE:{

					if (IsHuntingRiffle(iEnt)){

						DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
						SafelyRemoveEdict(iEnt);
					}
					continue;
				}
				case WEAPINDEX_PISTOL:{

					if (g_bCvarRemoveDualPistols){

						DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
						SafelyRemoveEdict(iEnt);
					}
					continue;
				}
			}

			if (g_iCvarItem[iWeapIndex] > 0){

				GetEntityOrg(iEnt, vOrg);

				DebugLog("%s class %s, ent = %d, vec = %.1f %.1f %.1f", IC_TAG, sClass, iEnt, vOrg[0], vOrg[1], vOrg[2]);

				if (bFirstRound){

					if (IsVectorNull(vOrg)){

						DebugLog("%s  - skipped: vector is null", IC_TAG);
						continue;
					}

					DebugLog("%s  - successfully pushed!", IC_TAG);
					PushArrayArray(g_hItemArray[iWeapIndex], vOrg);
					iCount[iWeapIndex]++;
				}
				else {

					//if (!iArraySize[iWeapIndex]){

						DebugLog("%s  - removed: because we need", IC_TAG);
						SafelyRemoveEdict(iEnt);
						continue;
					//}

					// GetArrayArray(g_hItemArray[iWeapIndex], 0, vOrg);
					// RemoveFromArray(g_hItemArray[iWeapIndex], 0);
					// iArraySize[iWeapIndex]--;

					// TeleportEntity(iEnt, vOrg, NULL_VECTOR, NULL_VECTOR);

					// DebugLog("%s  - teleported to %.1f %.1f %.1f!", IC_TAG, vOrg[0], vOrg[1], vOrg[2]);
					// DispatchKeyValue(iEnt, "count", "1");
					// iCount[iWeapIndex]++;
				}
			}
			else if (g_iCvarItem[iWeapIndex]){

				DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
				SafelyRemoveEdict(iEnt);
			}
		}
		else if (IsExplovesProps(iEnt, sClass) || IsExplovesBarrel(sClass)){

			DebugLog("%s class %s, ent = %d - killed!", IC_TAG, sClass, iEnt);
			SafelyRemoveEdict(iEnt);
		}
	}

	if (bFirstRound){

		DebugLog("%s Step 2: Radomize items (%d molotov, %d pipe-bomb, %d pills)", IC_TAG, iCount[WEAPINDEX_MOLOTOV], iCount[WEAPINDEX_PIPEBOMB], iCount[WEAPINDEX_PILLS]);

		for (new INDEX = 0; INDEX < MAX_ITEMS; INDEX++)
			IC_RadomizeItems(g_hItemArray[INDEX], g_iCvarItem[INDEX], g_sSpawnName[INDEX], INDEX == WEAPINDEX_PILLS ? true : false);
	}
	else {

		DebugLog("%s Items were restored: %d molotov, %d pipe-bomb, %d pills", IC_TAG, iCount[WEAPINDEX_MOLOTOV], iCount[WEAPINDEX_PIPEBOMB], iCount[WEAPINDEX_PILLS]);
		DebugLog("%s Step 2: Checking if some item missing", IC_TAG);

		for (new INDEX = 0; INDEX < MAX_ITEMS; INDEX++)
			IC_CreateMissingItem(g_hItemArray[INDEX],	 iArraySize[INDEX], g_sSpawnName[INDEX]);

		DebugLog("%s Step 2: Done!", IC_TAG);
	}
}

static WeapIDtoIndex(iEnt)
{
	switch (GetEntProp(iEnt, Prop_Send, "m_weaponID")){

		case WEAPID_MOLOTOV:
			return WEAPINDEX_MOLOTOV;
		case WEAPID_PIPEBOMB:
			return WEAPINDEX_PIPEBOMB;
		case WEAPID_PAINPILLS:
			return WEAPINDEX_PILLS;
		case WEAPID_HUNTINGRIFLE:
			return WEAPINDEX_HUNTINGRIFLE;
		case WEAPID_PISTOL:
			return WEAPINDEX_PISTOL;
	}

	return NULL;
}

static ItemCountFix(iEnt, iWeapIndex)
{
	if (iWeapIndex != NULL && iWeapIndex <= 2)
		DispatchKeyValue(iEnt, "count", "1");

	return iWeapIndex;
}

static IC_RadomizeItems(&Handle:hArray, iCvar, const String:sClassName[], bool:bPills)
{
	if (!iCvar) return;

	decl iArraySize;

	if ((iArraySize = GetArraySize(hArray)) <= 1){

		if (iArraySize == 1)
			DebugLog("%s 1/%d %s saved!", IC_TAG, iCvar, sClassName);
		else
			DebugLog("%s Array is empty", IC_TAG);
		return;
	}

	if (iArraySize < iCvar)
		iCvar = iArraySize;

	decl iVal, Float:vOrg[3];
	new iCount, Handle:hRandomItemArray = CreateArray(3);
	while (iCount != iCvar){

		iVal = GetRandomInt(0, iArraySize - 1);

		GetArrayArray(hArray, iVal, vOrg);
		PushArrayArray(hRandomItemArray, vOrg);
		RemoveFromArray(hArray, iVal);

		iArraySize--;
		iCount++;
	}

	iCount = 0;
	iArraySize = GetArraySize(hRandomItemArray);

	new iEnt = -1, bool:bSaveMe;
	while ((iEnt = FindEntityByClassname(iEnt, sClassName)) != INVALID_ENT_REFERENCE){

		GetEntityOrg(iEnt, vOrg);

		if (bPills && !IsEntOutSideSafeRoom(vOrg)) continue;

		bSaveMe = false;

		if (ComapreVectors(vOrg, iArraySize, hRandomItemArray)){

			bSaveMe = true;
			iCount++;
		}

		DebugLog("%s %s ent = %d, vec = %.1f %.1f %.1f - %s", IC_TAG, sClassName, iEnt, vOrg[0], vOrg[1], vOrg[2], bSaveMe ? "saved" : "killed");

		if (!bSaveMe)
			SafelyRemoveEdict(iEnt);
	}

	ClearArray(hArray);
	hArray = CloneArray(hRandomItemArray);
	CloseHandle(hRandomItemArray);

	DebugLog("%s %d/%d %s saved!", IC_TAG, iCount, iCvar, sClassName);
}

static IC_CreateMissingItem(Handle:hArray, iCount, const String:sClassName[])
{
	if (!iCount) return;

	static Float:vOrg[3], iEnt;

	while (iCount != 0){

		GetArrayArray(hArray, 0, vOrg);
		RemoveFromArray(hArray, 0);

		iEnt = CreateEntityByName(sClassName);
		DispatchKeyValue(iEnt, "spawnflags", "0");
		DispatchKeyValue(iEnt, "solid", "6");
		DispatchKeyValue(iEnt, "disableshadows", "1");
		DispatchKeyValue(iEnt, "count", "1");
		TeleportEntity(iEnt, vOrg, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(iEnt);

		DebugLog("%s Missing item was created! class %s, ent = %d, vec = %.1f %.1f %.1f", IC_TAG, sClassName, iEnt, vOrg[0], vOrg[1], vOrg[2]);
		iCount--;
	}
}

public Action:IC_ev_SpawnerGiveItem(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iItem = GetEventInt(event, "spawner");

	decl iWeapIndex;
	if ((iWeapIndex = WeapIDtoIndex(iItem)) == NULL || iWeapIndex > MAX_ITEMS || (iWeapIndex == WEAPINDEX_PILLS && !IsEntOutSideSafeRoomEx(iItem))) return;

	if (++g_iPickUp[iWeapIndex] == g_iLimit[iWeapIndex]){

		DebugLog("%s %s picked up %d/%d", IC_TAG, g_sSpawnName[iWeapIndex], g_iPickUp[iWeapIndex], g_iLimit[iWeapIndex]);
		PrintToChatAll("%s Survivor team has reached %s limit", MAIN_TAG, g_sName[iWeapIndex]);

		new iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, g_sSpawnName[iWeapIndex])) != INVALID_ENT_REFERENCE)
			if (iWeapIndex < 2 || IsEntOutSideSafeRoomEx(iEnt))
				SafelyRemoveEdict(iEnt);
	}
}

static bool:ComapreVectors(Float:vVectorA[3], iArraySize, Handle:hArray)
{
	static Float:vVectorB[3];

	for (new i = 0; i < iArraySize; i++){

		GetArrayArray(hArray, i, vVectorB);

		if (IsVectorsMatch(vVectorA, vVectorB))
			return true;
	}
	return false;
}

static bool:IsExplovesProps(iEnt, const String:sClass[])
{
	if (g_bCvarRemoveCannisters && StrEqual(sClass, "prop_physics")){

		static String:sModelName[64];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, 64);

		return	strcmp(sModelName, GASCAN_MODEL) == 0 || strcmp(sModelName, PROPANE_MODEL) == 0 ||
				strcmp(sModelName, OXYGEN_MODEL) == 0;
	}

	return false;
}

static bool:IsExplovesBarrel(const String:sClass[])
{
	return g_bCvarRemoveBarrels && StrEqual(sClass, "prop_fuel_barrel");
}

static bool:IsHuntingRiffle(iEnt)
{
	if (!g_iCvarHuntingRiffle) return false;

	if (g_iCvarHuntingRiffle == -1)
		return IsEntInStartSafeRoomEx(iEnt);
	else
		return g_bIsFinalMap && IsEntInStartSafeRoomEx(iEnt);
}

SetDirectorSettings(Handle:hCvar, iVal)
{
	switch (iVal){

		case -1:
			SetConVarInt(hCvar, 0);
		case 0:
			ResetConVar(hCvar);
		default:
			SetConVarInt(hCvar, 10);
	}
}

CheckSpawningLogic(&iVal, iWeapIndex)
{
	if (g_bAlterSpawningLogic && iVal > 0){

		g_iLimit[iWeapIndex] = iVal;

		new x = 6 - iVal;
		if (x > 0)
			iVal += x;
	}
}

public IC_OnCvarChange_MolotovLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarMolotovLimit();
}

public IC_OnCvarChange_PipeBombLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarPipeBombLimit();
}

public IC_OnCvarChange_PainPillsLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarPainPillsbLimit();
}

public IC_OnCvarChange_RemoveCannisters(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarEnableCannisters();
}

public IC_OnCvarChange_RemoveBarrels(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarEnableBarrrels();
}

public IC_OnCvarChange_RemoveHuntingRiffle(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarRemoveHuntingRiffle();
}

public IC_OnCvarChange_RemoveDualPistols(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarRemoveDualPistols();
}

static bool:g_bHook;

public IC_OnCvarChange_AlterSpawningLogic(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarAlterSpawningLogic();

	if (StrEqual(oldValue, newValue)) return;

	if (StringToInt(newValue) && !g_bHook){

		g_bHook = true;
		DebugLog("%s Alternative spawning logic enabled", IC_TAG);
		HookEvent("spawner_give_item", IC_ev_SpawnerGiveItem);
	}
	else if (g_bHook){

		g_bHook = false;
		DebugLog("%s Alternative spawning logic disabled", IC_TAG);
		UnhookEvent("spawner_give_item", IC_ev_SpawnerGiveItem);
	}
}

static GetConVarMolotovLimit()
{
	g_iCvarItem[WEAPINDEX_MOLOTOV] = GetConVarInt(g_hItem[WEAPINDEX_MOLOTOV]);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_MOLOTOV], g_iCvarItem[WEAPINDEX_MOLOTOV]);

	CheckSpawningLogic(g_iCvarItem[WEAPINDEX_MOLOTOV], WEAPINDEX_MOLOTOV);
}

static GetConVarPipeBombLimit()
{
	g_iCvarItem[WEAPINDEX_PIPEBOMB] = GetConVarInt(g_hItem[WEAPINDEX_PIPEBOMB]);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PIPEBOMB], g_iCvarItem[WEAPINDEX_PIPEBOMB]);

	CheckSpawningLogic(g_iCvarItem[WEAPINDEX_PIPEBOMB], WEAPINDEX_PIPEBOMB);
}

static GetConVarPainPillsbLimit()
{
	g_iCvarItem[WEAPINDEX_PILLS] = GetConVarInt(g_hItem[WEAPINDEX_PILLS]);
	SetDirectorSettings(g_hDensiny[WEAPINDEX_PILLS], g_iCvarItem[WEAPINDEX_PILLS]);

	CheckSpawningLogic(g_iCvarItem[WEAPINDEX_PILLS], WEAPINDEX_PILLS);
}

static GetConVarEnableCannisters()
{
	g_bCvarRemoveCannisters = GetConVarBool(g_hRemoveCannisters);
}

static GetConVarEnableBarrrels()
{
	g_bCvarRemoveBarrels = GetConVarBool(g_hRemoveBarrels);
}

static GetConVarRemoveHuntingRiffle()
{
	g_iCvarHuntingRiffle = GetConVarInt(g_hRemoveHuntingRiffle);
}

static GetConVarRemoveDualPistols()
{
	g_bCvarRemoveDualPistols = GetConVarBool(g_hRemoveDualPistols);
}

static GetConVarAlterSpawningLogic()
{
	g_bAlterSpawningLogic = GetConVarBool(g_hAlterSpawningLogic);
}

static GetCvars()
{
	GetConVarMolotovLimit();
	GetConVarPipeBombLimit();
	GetConVarPainPillsbLimit();
	GetConVarEnableCannisters();
	GetConVarEnableBarrrels();
	GetConVarRemoveHuntingRiffle();
	GetConVarRemoveDualPistols();
	GetConVarAlterSpawningLogic();
}