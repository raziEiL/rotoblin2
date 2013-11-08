/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.TankSpawns.sp
 *  Type:			Module
 *  Description:	Enables forcing same coordinates for tank spawns. (BETA)
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

#define		TS_TAG					"[TankSpawns]"

enum Round
{
	First,
	Second
}

static	Handle:g_hTankSpawns, bool:g_bCvarTankSpawns, bool:g_bTankFix, bool:g_bFixed, Float:g_fTankData[2][3], g_iFlow[Round], g_iDebugChannel;

_TankSpawns_OnPluginStart()
{
	g_hTankSpawns = CreateConVarEx("tank_spawns", "0", "Enables forcing same coordinates for tank spawns.", _, true, 0.0, true, 1.0);
	g_iDebugChannel = DebugAddChannel(TS_TAG);
}

_TS_OnPluginEnabled()
{
	Update_TS_TankSpawns();
	HookConVarChange(g_hTankSpawns, _TS_TankSpawns_CvarChange);
}

_TS_OnPluginDisabled()
{
	UnhookConVarChange(g_hTankSpawns, _TS_TankSpawns_CvarChange);
}

_TS_OnMapEnd()
{
	g_iFlow[First] = 0;
	g_iFlow[Second] = 0;
	g_bTankFix = false;
	g_bFixed = false;
	ClearVec();
}

bool:_TS_L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	if (g_bCvarTankSpawns && !g_bTankFix && !IsFinalMap()){

		if (FirstRound()){

			if (IsVectorNull(g_fTankData[0]))
				CopyVec(vector, qangle);

			DebugPrintToAll(g_iDebugChannel, "round1 tank pos: %.1f %.1f %.1f", vector[0], vector[1], vector[2]);
		}
		else if (!IsVectorNull(g_fTankData[0]) && !IsTankSpawnsMatch(vector)){

			g_bTankFix = true;
			DebugPrintToAll(g_iDebugChannel, "round2 tank pos not matches: %.1f %.1f %.1f", vector[0], vector[1], vector[2]);
		}
	}

	return false;
}

public Action:TS_t_UpdateFlow(Handle:timer)
{
	g_iFlow[Second] = RoundToFloor(GetHighestSurvFlow());

	if (g_iFlow[Second] == -1 || g_iFlow[Second] >= g_iFlow[First]){

		DebugPrintToAll(g_iDebugChannel,"unprohibit tank spawn! Flow: r1 %d, r2 %d ", g_iFlow[First], g_iFlow[Second]);
		g_iFlow[Second] = g_iFlow[First];
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

_TS_ev_OnTankSpawn()
{
	if (g_bFixed || !g_bTankFix || !g_bCvarTankSpawns) return;

	g_bFixed = true;

	new iTank = GetTankClient();
	if (iTank){

		TeleportEntity(iTank, g_fTankData[0], g_fTankData[1], NULL_VECTOR);
		DebugPrintToAll(g_iDebugChannel, "teleport '%N' to round1 pos.", iTank);
	}
}

static CopyVec(const Float:vector[3], const Float:qangle[3])
{
	g_fTankData[0][0] = vector[0];
	g_fTankData[0][1] = vector[1];
	g_fTankData[0][2] = vector[2];
	g_fTankData[1][0] = qangle[0];
	g_fTankData[1][1] = qangle[1];
	g_fTankData[1][2] = qangle[2];
}

static ClearVec()
{
	g_fTankData[0][0] = 0.0;
	g_fTankData[0][1] = 0.0;
	g_fTankData[0][2] = 0.0;
	g_fTankData[1][0] = 0.0;
	g_fTankData[1][1] = 0.0;
	g_fTankData[1][2] = 0.0;
}

public Native_R2comp_GetHighestSurvivorFlow(Handle:plugin, numParams)
{
	return _:GetHighestSurvFlow();
}

Float:GetHighestSurvFlow(bool:bDown = false)
{
	new Float:fFlow = -1.0, Float:iLastFlow;

	if (g_bBlackSpot){

		for (new i = 1; i <= MaxClients; i++){

			if (IsSurvivor(i) && IsPlayerAlive(i)){

				if (bDown && (IsIncapacitated(i) || IsHandingFromLedge(i))) continue;
				
				if ((iLastFlow = GetPlayerFlowDistance(i)) > fFlow)
					fFlow = iLastFlow;
			}
		}
	}
	else if (SurvivorCount){

		for (new i = 0; i < SurvivorCount; i++){

			if (bDown && (IsIncapacitated(SurvivorIndex[i]) || IsHandingFromLedge(SurvivorIndex[i]))) continue;

			if ((iLastFlow = GetPlayerFlowDistance(SurvivorIndex[i])) > fFlow)
				fFlow = iLastFlow;
		}
	}

	return fFlow;
}

static bool:IsTankSpawnsMatch(const Float:vector[3])
{
	return g_fTankData[0][0] == vector[0] && g_fTankData[0][1] == vector[1] && g_fTankData[0][2] == vector[2];
}

public _TS_TankSpawns_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		Update_TS_TankSpawns();
}

static Update_TS_TankSpawns()
{
	g_bCvarTankSpawns = GetConVarBool(g_hTankSpawns);
}

stock _TS_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hTankSpawns)) != g_bCvarTankSpawns)
		DebugLog("%d		|	%d		|	rotoblin_tank_spawns", iVal, g_bCvarTankSpawns);
}
