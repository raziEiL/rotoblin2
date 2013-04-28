/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			l4d_lib.inc
 *  Type:			Stocks
 *  Description:	My useful stock for l4d/l4d2 engine.
 *
 *  Copyright (C) 2012-2013 raziEiL <war4291@mail.ru>
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

#if defined _l4d_lib_
  #endinput
#endif
#define _l4d_lib_

static const	TANK_INDEX_L4D	= 5,
				TANK_INDEX_L4D2	= 8;

stock bool:IsClientAndInGame(index)
{
	return IsClient(index) && IsClientInGame(index);
}

stock bool:IsClient(index)
{
	return index > 0 && index <= MaxClients;
}

stock bool:IsInfected(index)
{
	return IsClientInGame(index) && GetClientTeam(index) == 3;
}

stock bool:IsSurvivor(index)
{
	return IsClientInGame(index) && GetClientTeam(index) == 2;
}

stock bool:IsSpectator(index)
{
	return IsClientInGame(index) && GetClientTeam(index) == 1;
}

stock bool:IsOnLadder(entity)
{
	return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}

stock bool:IsSurvivorBussy(client)
{
	return GetEntProp(client, Prop_Send, "m_tongueOwner") > 0 || GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0;
}

stock bool:IsInfectedBussy(client)
{
	return GetEntProp(client, Prop_Send, "m_tongueVictim") > 0 || GetEntProp(client, Prop_Send, "m_pounceVictim") > 0;
}

stock IsIncapacitated(client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

stock bool:IsHandingFromLedge(client)
{
	return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge");
}

stock bool:IsInfectedAlive(client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth") > 1;
}

stock bool:IsPlayerTank(tank_index)
{
	return GetEntProp(tank_index, Prop_Send, "m_zombieClass") == (IsL4DGameEx() ? TANK_INDEX_L4D : TANK_INDEX_L4D2);
}

stock bool:IsWitch(entity)
{
	decl String:sClassName[64];
	GetEntityClassname(entity, sClassName, 64);
	return !strcmp(sClassName, "witch");
}

stock bool:IsCommonInfected(entity)
{
	decl String:sClassName[64];
	GetEntityClassname(entity, sClassName, 64);
	return !strcmp(sClassName, "infected");
}

stock bool:IsWeaponClass(const String:sClassName[])
{
	return StrContains(sClassName, "weapon_") != -1 || StrContains(sClassName, "upgrade_") != -1;
}

stock GetPlayerClass(client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

stock GetFrustration(tank_index)
{
	return GetEntProp(tank_index, Prop_Send, "m_frustration");
}

stock SetTankFrustration(tank_index, iFrustration)
{
	SetEntProp(tank_index, Prop_Send, "m_frustration", 100 - iFrustration);
}

stock IsPlayerGhost(client)
{
	return GetEntProp(client, Prop_Send, "m_isGhost");
}

stock GetGhostSpawnState(client)
{
	return GetEntProp(client, Prop_Send, "m_ghostSpawnState");
}

stock GetEntityOrg(entity, Float:vOrg[3])
{
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrg);
}

stock GetHammerID(entity)
{
	return GetEntProp(entity, Prop_Data, "m_iHammerID");
}

stock bool:IsAnyOneConnected()
{
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i))
			return true;

	return false;
}

stock bool:IsServerEmpty()
{
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsFakeClient(i))
			return false;

	return true;
}

stock IsVectorNull(Float:vOrg[3])
{
	return !vOrg[0] && !vOrg[1] && !vOrg[2];
}

stock IsVectorsMatch(Float:vVectorA[3], Float:vVectorB[3])
{
	return vVectorA[0] == vVectorB[0] && vVectorA[1] == vVectorB[1] && vVectorA[2] == vVectorB[2];
}

stock PrintToTeam(team, bool:hint, const String:text[], any:...)
{
	decl String:sText[256];
	new bool:bTrans = StrContains(text, "%t") != -1;

	for (new i = 1; i <= MaxClients; i++){

		if (IsClientInGame(i) && GetClientTeam(i) == team && !IsFakeClient(i)){

			if (bTrans)
				SetGlobalTransTarget(i);

			VFormat(sText, 256, text, 4);

			if (hint)
				PrintHintText(i, sText)
			else
				PrintToChat(i, sText);
		}
	}
}

stock bool:IsL4DGame(bool:bL4D2 = false)
{
	decl String:sGameFolder[32];
	GetGameFolderName(sGameFolder, 32);
	return StrEqual(sGameFolder, bL4D2 ? "left4dead2" : "left4dead");
}

stock bool:IsL4DEngine(bool:bL4D2 = false)
{
	return GuessSDKVersion() == (bL4D2 ? SOURCE_SDK_LEFT4DEAD2 : SOURCE_SDK_LEFT4DEAD);
}

stock IsL4DGameEx()
{
	static iGame = -1;

	if (iGame == -1)
		iGame = IsL4DGame();

	return iGame;
}

stock IsL4DEngineEx()
{
	static iEngine = -1;

	if (iEngine == -1)
		iEngine = IsL4DEngine();

	return iEngine;
}

stock bool:IsFinalMap()
{
	return FindEntityByClassname(-1, "info_changelevel") == INVALID_ENT_REFERENCE;
}

stock bool:IsNewMission()
{
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	return StrContains(sMap, "01_") != -1;
}

#define LIB			"r2compmod"

#if defined REQUIRE_PLUGIN

#include <r2comp_api>

new stock bool:g_bLoadLater;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkCompNatives();
	g_bLoadLater = late;

	return APLRes_Success;
}
#endif

public SharedPlugin:__pl_r2compmod =
{
	name = LIB,
	file = "r2compmod.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
}