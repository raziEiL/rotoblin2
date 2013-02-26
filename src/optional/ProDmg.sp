#define PLUGIN_VERSION "1.2"

#include <sourcemod>
#include <l4d_lib>

#define debug		0

#define TAG				"[ProDMG]"

#define NULL				-1
#define BOSSES			2
#define MAX_WITCHES		7

enum DATA
{
	INDEX,
	DMG,
	WITCH = 0,
	TANK
}

public Plugin:myinfo =
{
	name = "ProDMG",
	author = "raziEiL [disawar1]",
	description = "Bosses dealt damage announcer.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

static		Handle:g_hFlags, Handle:g_hSkipBots, Handle:g_hTankHealth, Handle:g_hVsBonusHealth, Handle:g_hWitchHealth,
			Handle:g_hSurvLimit, g_iCvarHealth[BOSSES], g_iDamage[MAXPLAYERS+1][MAXPLAYERS+1][BOSSES], g_iWitchIndex[MAX_WITCHES],
			g_iTotalDamage[MAXPLAYERS+1][BOSSES], bool:g_bCvarSkipBots, bool:g_b1v1Mode, bool:bTempBlock, g_iLastKnownTank;

public OnPluginStart()
{
	g_hTankHealth		= FindConVar("z_tank_health");
	g_hVsBonusHealth	= FindConVar("versus_tank_bonus_health");
	g_hWitchHealth		= FindConVar("z_witch_health");
	g_hSurvLimit			= FindConVar("survivor_limit");

	g_hFlags		= CreateConVar("prodmg_announce_flags",	"0", "0=Disabled, 1=Witch, 2=Tank, 3=All");
	g_hSkipBots	= CreateConVar("prodmg_ignore_bots",		"0");

	HookConVarChange(g_hTankHealth,			OnConvarChange_TankHealth);
	HookConVarChange(g_hVsBonusHealth,		OnConvarChange_TankHealth);
	HookConVarChange(g_hWitchHealth,		OnConvarChange_WitchHealth);
	HookConVarChange(g_hSkipBots,			OnConvarChange_SkipBots);
	HookConVarChange(g_hSurvLimit,			OnConvarChange_SurvLimit);
	PD_GetCvars();

	HookEvent("round_start",		PD_ev_RoundStart,		EventHookMode_PostNoCopy)
	HookEvent("round_end",		PD_ev_RoundEnd,			EventHookMode_PostNoCopy)
	HookEvent("tank_frustrated",	PD_ev_TankFrustrated);
	HookEvent("witch_killed",		PD_ev_WitchKilled);
	HookEvent("entity_killed",	PD_ev_EntityKilled);
	HookEvent("player_hurt",		PD_ev_PlayerHurt);
	HookEvent("infected_hurt",	PD_ev_InfectedHurt);
}

public Action:PD_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	bTempBlock = false;
	g_iLastKnownTank = 0;

	for (new i; i <= MaxClients; i++){

		g_iDamage[i][i][TANK] = 0;
		g_iDamage[i][i][WITCH] = 0;
		g_iTotalDamage[i][TANK] = 0;
		g_iTotalDamage[i][WITCH] = 0;

		if (i < MAX_WITCHES)
			g_iWitchIndex[i] = 0;
	}
}

public Action:PD_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock) return;

	bTempBlock = true;

	decl String:sName[32];

	for (new i; i <= MaxClients; i++){

		if (g_iTotalDamage[i][TANK]){

			if (!IsClientInGame(i))
				PrintToChatAll("Tank had %d health remaining", g_iCvarHealth[TANK] - g_iTotalDamage[i][TANK]);

			else{

				GetClientName(i, sName, 32);
				PrintToChatAll("Tank (%s) had %d health remaining", IsFakeClient(i) ? "AI" : sName, g_iCvarHealth[TANK] - g_iTotalDamage[i][TANK]);
			}

			PrintDamage(i, true, true);
		}
		if (g_iTotalDamage[i][WITCH]){

			PrintToChatAll("Wicth had %d health remaining", g_iCvarHealth[WITCH] - g_iTotalDamage[i][WITCH]);
			PrintDamage(i, false, true);
		}
	}
}

// Tank
public Action:PD_ev_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(GetConVarInt(g_hFlags) & (1 << _:TANK))) return;

	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (IsClientAndInGame(victim) && IsClientAndInGame(attacker) && GetClientTeam(attacker) == 2  && GetClientTeam(victim) == 3){

		if (!IsPlayerTank(victim) || g_iTotalDamage[victim][TANK] == g_iCvarHealth[TANK]) return;

		if (g_iLastKnownTank)
			CloneStats(victim);

		new iDamage = GetEventInt(event, "dmg_health");

		g_iDamage[attacker][victim][TANK] += iDamage;
		g_iTotalDamage[victim][TANK] += iDamage;

		#if debug
			PrintToChatAll("#1. total %d dmg %d (%N, health %d)", g_iTotalDamage[victim][TANK], iDamage, victim, GetEventInt(event, "health"));
		#endif
		
		CorrectDmg(attacker, victim, true);
	}
}

CloneStats(client)
{
	for (new i; i <= MaxClients; i++){
	
		if (g_iDamage[i][g_iLastKnownTank][TANK]){
		
			g_iDamage[i][client][TANK] = g_iDamage[i][g_iLastKnownTank][TANK];
			g_iDamage[i][g_iLastKnownTank][TANK] = 0;
		}
	}

	g_iTotalDamage[client][TANK] = g_iTotalDamage[g_iLastKnownTank][TANK]
	g_iTotalDamage[g_iLastKnownTank][TANK] = 0;
	g_iLastKnownTank = 0;
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (!bTempBlock && GetConVarInt(g_hFlags) & (1 << _:TANK) && IsPlayerTank((client = GetEventInt(event, "entindex_killed")))/*&& g_iTotalDamage[client][TANK] == g_iCvarHealth[TANK]*/)
		CreateTimer(1.5, PD_t_FindAnyTank, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:PD_t_FindAnyTank(Handle:timer, any:client)
{
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsPlayerTank(i) && !IsIncapacitated(i))
			return;

	PrintDamage(client, true);
}

// 1v1
public Action:PD_ev_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!g_b1v1Mode){

		g_iLastKnownTank = client;
		return;
	}

	PrintToChatAll("Tank (%N) has been lost", client);
	PrintToChatAll("He had %d health remaining", g_iCvarHealth[TANK] - g_iTotalDamage[client][TANK])

	if (g_iTotalDamage[client][TANK])
		PrintDamage(client, true, true);
}

// Witch
public Action:PD_ev_InfectedHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(GetConVarInt(g_hFlags) & (1 << _:WITCH))) return;

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	decl iWitchEnt;
	if (IsClientAndInGame(attacker) && GetClientTeam(attacker) == 2 && IsWitch((iWitchEnt = GetEventInt(event, "entityid")))){

		new iIndex = FindWitchInArray(iWitchEnt);

		if (iIndex == NULL){

			if ((iIndex = FindNullElem()) == NULL) return;

			g_iWitchIndex[iIndex] = iWitchEnt;
		}

		if (g_iTotalDamage[iIndex][WITCH] == g_iCvarHealth[WITCH]) return;

		new iDamage = GetEventInt(event, "amount");

		g_iDamage[attacker][iIndex][WITCH] += iDamage;
		g_iTotalDamage[iIndex][WITCH] += iDamage;
		
		#if debug
			PrintToChatAll("%d (Witch %d)", g_iTotalDamage[iIndex][WITCH], iWitchEnt);
		#endif
		
		CorrectDmg(attacker, iIndex, false);
	}
}

FindNullElem()
{
	for (new i; i < MAX_WITCHES; i++)
		if (!g_iWitchIndex[i])
			return i;

	return NULL;
}

FindWitchInArray(iEnt)
{
	for (new i; i < MAX_WITCHES; i++)
		if (g_iWitchIndex[i] == iEnt)
			return i;

	return NULL;
}
// ---

CorrectDmg(attacker, iIndex, bool:bTankBoss)
{
	if (g_iTotalDamage[iIndex][bTankBoss] > g_iCvarHealth[bTankBoss]){

		new iDiff = g_iTotalDamage[iIndex][bTankBoss] - g_iCvarHealth[bTankBoss];
		
		#if debug
			PrintToChatAll("dmg corrected %d. total dmg %d", iDiff, g_iTotalDamage[iIndex][bTankBoss]);
		#endif
		
		g_iDamage[attacker][iIndex][bTankBoss] -= iDiff;
		g_iTotalDamage[iIndex][bTankBoss] -= iDiff;
	}
}

public Action:PD_ev_WitchKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!(GetConVarInt(g_hFlags) & (1 << _:WITCH))) return;

	new iIndex = FindWitchInArray(GetEventInt(event, "witchid"));
	if (iIndex == NULL || !g_iTotalDamage[iIndex][WITCH]) return;

	PrintDamage(iIndex, false)
}

PrintDamage(iIndex, bool:bTankBoss, bool:bLoose = false)
{
	decl iClient[MAXPLAYERS+1][BOSSES];
	new iSurvivors;

	for (new i = 1; i <= MaxClients; i++){

		if (!g_iDamage[i][iIndex][bTankBoss]) continue;

		if (IsClientInGame(i)){

			if ((g_bCvarSkipBots && !IsFakeClient(i)) || !g_bCvarSkipBots){

				iClient[iSurvivors][INDEX] = i;
				iClient[iSurvivors][DMG] = g_iDamage[i][iIndex][bTankBoss];
				iSurvivors++;
			}
		}
		// reset var
		g_iDamage[i][iIndex][bTankBoss] = 0;
	}
	if (!iSurvivors) return;

	if (iSurvivors == 1 && !bLoose)
		PrintToChatAll("%N dealt %d damage to %s", iClient[0][INDEX], iClient[0][DMG], bTankBoss ? "Tank" : "Witch");

	else {

		new Float:fTotalDamage = float(g_iCvarHealth[bTankBoss]);

		SortCustom2D(iClient, iSurvivors, SortFuncByDamageDesc);

		if (!bLoose)
			PrintToChatAll("Damage dealt to %s (%d):", bTankBoss ? "Tank" : "Witch", g_iTotalDamage[iIndex][bTankBoss]);

		for (new i; i < iSurvivors; i++)
			PrintToChatAll("%d (%.0f%%): %N", iClient[i][DMG], FloatMul(FloatDiv(float(iClient[i][DMG]), fTotalDamage), 100.0), iClient[i][INDEX]);
	}

	// reset var
	g_iTotalDamage[iIndex][bTankBoss] = 0;
}

public SortFuncByDamageDesc(x[], y[], const array[][], Handle:hndl)
{
	if (x[1] < y[1])
		return 1;
	else if (x[1] == y[1])
		return 0;

	return NULL;
}

public OnConvarChange_TankHealth(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarHealth[TANK] = RoundFloat(FloatMul(GetConVarFloat(g_hTankHealth), GetConVarFloat(g_hVsBonusHealth)));
}

public OnConvarChange_WitchHealth(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarHealth[WITCH] = GetConVarInt(g_hWitchHealth);
}

public OnConvarChange_SkipBots(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarSkipBots = GetConVarBool(g_hSkipBots);
}

public OnConvarChange_SurvLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_b1v1Mode = GetConVarInt(g_hSurvLimit) == 1 ? true : false;
}

PD_GetCvars()
{
	g_iCvarHealth[TANK] = RoundFloat(FloatMul(GetConVarFloat(g_hTankHealth), GetConVarFloat(g_hVsBonusHealth)));
	g_iCvarHealth[WITCH] = GetConVarInt(g_hWitchHealth);
	g_bCvarSkipBots = GetConVarBool(g_hSkipBots);
	g_b1v1Mode = GetConVarInt(g_hSurvLimit) == 1 ? true : false;
}
