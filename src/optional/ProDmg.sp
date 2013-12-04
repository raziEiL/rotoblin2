#define PLUGIN_VERSION	"1.3"

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define debug		0

#define TAG				"[ProDMG]"

#define NULL					-1
#define BOSSES				2
#define TANK_PASS_TIME		(g_fCvarTankSelectTime + 1.0)

#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

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

static		Handle:g_hTankHealth, Handle:g_hVsBonusHealth, bool:g_bCvarSkipBots, bool:g_bCvar1v1Mode, g_iCvarHealth[BOSSES],
			g_iDamage[MAXPLAYERS+1][MAXPLAYERS+1][BOSSES], g_iWitchIndex[MAXPLAYERS+1], g_iTotalDamage[MAXPLAYERS+1][BOSSES],
			bool:bTempBlock, g_iLastKnownTank, bool:g_bTankInGame, Handle:g_hTrine, g_iCvarFlags, g_iCvarPrivateFlags,
			bool:g_bNoHrCrown[MAXPLAYERS+1], g_iWitchCount, bool:g_bCvarRunAway, g_iWitchRef[MAXPLAYERS+1], Float:g_fCvarTankSelectTime;

public OnPluginStart()
{
	g_hTankHealth		= FindConVar("z_tank_health");
	g_hVsBonusHealth	= FindConVar("versus_tank_bonus_health");

	new Handle:hCvarWitchHealth			= FindConVar("z_witch_health");
	new Handle:hCvarSurvLimit			= FindConVar("survivor_limit");
	new Handle:hCvarTankSelectTime		= FindConVar("director_tank_lottery_selection_time");

	new Handle:hCvarFlags		= CreateConVar("prodmg_announce_flags",		"0", "Flags: 0=disabled, 1=witch, 2=tank, 3=all", CVAR_FLAGS, true, 0.0, true, 3.0);
	new Handle:hCvarSkipBots	= CreateConVar("prodmg_ignore_bots",			"0", "Don't print bots stats", CVAR_FLAGS, true, 0.0, true, 1.0);
	new Handle:hCvarPrivate		= CreateConVar("prodmg_announce_private",	"0", "Don't print stats to public chat. Flags (add together): 0=disabled, 1=witch, 2=tank, 3=all", CVAR_FLAGS, true, 0.0, true, 3.0);
	new Handle:hCvarRunAway		= CreateConVar("prodmg_failed_crown",		"1", "Don't print witch stats at round end if she run away", CVAR_FLAGS, true, 0.0, true, 1.0);

	g_iCvarHealth[TANK]	= RoundFloat(FloatMul(GetConVarFloat(g_hTankHealth), GetConVarFloat(g_hVsBonusHealth)));
	g_iCvarHealth[WITCH]	= GetConVarInt(hCvarWitchHealth);
	g_bCvar1v1Mode			= GetConVarInt(hCvarSurvLimit) == 1 ? true : false;
	g_fCvarTankSelectTime = GetConVarFloat(hCvarTankSelectTime);
	g_iCvarFlags				= GetConVarInt(hCvarFlags);
	g_bCvarSkipBots			= GetConVarBool(hCvarSkipBots);
	g_bCvarRunAway			= GetConVarBool(hCvarRunAway);

	HookConVarChange(g_hTankHealth,			OnConvarChange_TankHealth);
	HookConVarChange(g_hVsBonusHealth,		OnConvarChange_TankHealth);
	HookConVarChange(hCvarWitchHealth,		OnConvarChange_WitchHealth);
	HookConVarChange(hCvarSurvLimit,		OnConvarChange_SurvLimit);
	HookConVarChange(hCvarTankSelectTime,	OnConvarChange_TankSelectTime);
	HookConVarChange(hCvarFlags,				OnConvarChange_Flags);
	HookConVarChange(hCvarSkipBots,			OnConvarChange_SkipBots);
	HookConVarChange(hCvarPrivate,			OnConvarChange_Private);
	HookConVarChange(hCvarRunAway,			OnConvarChange_RunAway);

	HookEvent("round_start",			PD_ev_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("round_end",			PD_ev_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",			PD_ev_TankSpawn,		EventHookMode_PostNoCopy);
	HookEvent("witch_spawn",			PD_ev_WitchSpawn);
	HookEvent("tank_frustrated",		PD_ev_TankFrustrated);
	HookEvent("witch_killed",			PD_ev_WitchKilled);
	HookEvent("entity_killed",		PD_ev_EntityKilled);
	HookEvent("player_hurt",			PD_ev_PlayerHurt);
	HookEvent("infected_hurt",		PD_ev_InfectedHurt);
	HookEvent("player_bot_replace",	PD_ev_PlayerBotReplace);

	g_hTrine = CreateTrie();
}

public Action:PD_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	bTempBlock = false;
	g_bTankInGame = false;
	g_iLastKnownTank = 0;
	g_iWitchCount = 0;
	ClearTrie(g_hTrine);

	for (new i; i <= MAXPLAYERS; i++){

		g_iDamage[i][i][TANK] = 0;
		g_iDamage[i][i][WITCH] = 0;
		g_iTotalDamage[i][TANK] = 0;
		g_iTotalDamage[i][WITCH] = 0;
		g_iWitchRef[i] = INVALID_ENT_REFERENCE;
		g_iWitchIndex[i] = 0;
		g_bNoHrCrown[i] = false;
	}
}

public Action:PD_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !g_iCvarFlags) return;

	bTempBlock = true;
	g_bTankInGame = false;

	decl String:sName[32];

	if (g_iCvarFlags & (1 << _:TANK)){

		new iTank = IsTankInGame();
		if (iTank && !g_iTotalDamage[iTank][TANK]){

			GetClientName(iTank, sName, 32);
			PrintToChatAll("Tank (%s) had %d health remaining", IsFakeClient(iTank) ? "AI" : sName, g_iCvarHealth[TANK] - (g_iCvarHealth[TANK] - GetClientHealth(iTank)));
		}
	}

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

			if (g_bCvarRunAway && g_iWitchRef[i] != INVALID_ENT_REFERENCE && EntRefToEntIndex(g_iWitchRef[i]) == INVALID_ENT_REFERENCE) continue;

			PrintToChatAll("Witch had %d health remaining", g_iCvarHealth[WITCH] - g_iTotalDamage[i][WITCH]);
			PrintDamage(i, false, true);
		}
	}
}

// Tank
public OnClientPutInServer(client)
{
	if (g_bTankInGame && g_iCvarFlags & (1 << _:TANK) && client){

		if (!IsFakeClient(client)){

			decl String:sName[32], String:sIndex[16];
			GetClientName(client, sName, 32);
			IntToString(client, sIndex, 16);
			SetTrieString(g_hTrine, sIndex, sName);
		}
		else
			CreateTimer(0.0, PD_t_CheckIsInf, client);
	}
}

public Action:PD_t_CheckIsInf(Handle:timer, any:client)
{
	if (IsClientInGame(client) && IsFakeClient(client)){

		decl String:sName[32];
		GetClientName(client, sName, 32);

		if (StrContains(sName, "Smoker") != -1 || StrContains(sName, "Boomer") != -1 || StrContains(sName, "Hunter") != -1) return;

		decl String:sIndex[16];
		IntToString(client, sIndex, 16);
		SetTrieString(g_hTrine, sIndex, sName);
	}
}

public Action:PD_ev_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bTankInGame && g_iCvarFlags & (1 << _:TANK)){

		decl String:sName[32], String:sIndex[16];

		for (new i = 1; i <= MaxClients; i++){

			if (!IsClientInGame(i) || (IsFakeClient(i) && GetClientTeam(i) == 3)) continue;

			IntToString(i, sIndex, 16);
			GetClientName(i, sName, 32);
			SetTrieString(g_hTrine, sIndex, sName);

			#if debug
				PrintToChatAll("push to trine. %s (%s)", sIndex, sName);
			#endif
		}
	}

	g_bTankInGame = true;
}

public Action:PD_ev_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(g_iCvarFlags & (1 << _:TANK))) return;

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
	if (client && client != g_iLastKnownTank){

		#if debug
			PrintToChatAll("clone tank stats %N -> %N", g_iLastKnownTank, client);
		#endif

		for (new i; i <= MaxClients; i++){

			if (g_iDamage[i][g_iLastKnownTank][TANK]){

				g_iDamage[i][client][TANK] = g_iDamage[i][g_iLastKnownTank][TANK];
				g_iDamage[i][g_iLastKnownTank][TANK] = 0;
			}
		}

		g_iTotalDamage[client][TANK] = g_iTotalDamage[g_iLastKnownTank][TANK];
		g_iTotalDamage[g_iLastKnownTank][TANK] = 0;
	}
	#if debug
	else
		PrintToChatAll("don't clone tank stats %N -> %N", g_iLastKnownTank, client);
	#endif

	g_iLastKnownTank = 0;
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (!bTempBlock && g_bTankInGame && g_iCvarFlags & (1 << _:TANK) && IsPlayerTank((client = GetEventInt(event, "entindex_killed"))))
		CreateTimer(1.5, PD_t_FindAnyTank, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:PD_t_FindAnyTank(Handle:timer, any:client)
{
	#if debug
		PrintToChatAll("entity killed %d fired!", client);
	#endif

	if (!IsTankInGame()){

		g_bTankInGame = false;

		if (g_iTotalDamage[client][TANK])
			PrintDamage(client, true);
		else if (!g_bCvar1v1Mode)// wtf?
			PrintToChatAll("Tank is dead (probably got stuck)");
	}
	#if debug
	else
		PrintToChatAll("tank in game");
	#endif
}

IsTankInGame(exclude = 0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (exclude != i && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerTank(i) && IsInfectedAlive(i) && !IsIncapacitated(i))
			return i;

	return 0;
}

public Action:PD_ev_PlayerBotReplace(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || g_bCvar1v1Mode || !(g_iCvarFlags & (1 << _:TANK))) return;

	// tank leave?
	new client = GetClientOfUserId(GetEventInt(event, "player"));

	if (!g_iLastKnownTank && g_iTotalDamage[client][TANK]){

		#if debug
			PrintToChatAll("tank %N leave inf team!", client);
		#endif

		g_iLastKnownTank = client;
		CloneStats(GetClientOfUserId(GetEventInt(event, "bot")));
	}
}

public Action:PD_ev_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(g_iCvarFlags & (1 << _:TANK))) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!g_bCvar1v1Mode && !g_iLastKnownTank){

		g_iLastKnownTank = client;
		CreateTimer(TANK_PASS_TIME, PD_t_CloneStatsDelay);
		return;
	}

	// 1v1
	PrintToChatAll("Tank (%N) has been lost", client);
	PrintToChatAll("He had %d health remaining", g_iCvarHealth[TANK] - g_iTotalDamage[client][TANK]);

	if (g_iTotalDamage[client][TANK])
		PrintDamage(client, true, true);
}

public Action:PD_t_CloneStatsDelay(Handle:timer)
{
	if (g_iLastKnownTank){

		new iNextOwner = IsTankInGame(g_iLastKnownTank);
		CloneStats(iNextOwner);
	}
}

// Witch
public Action:PD_ev_WitchSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.5, PD_t_EnumThisWitch, EntIndexToEntRef(GetEventInt(event, "witchid")), TIMER_FLAG_NO_MAPCHANGE);
}

public Action:PD_t_EnumThisWitch(Handle:timer, any:entity)
{
	new ref = entity;
	if ((entity = EntRefToEntIndex(entity)) != INVALID_ENT_REFERENCE && g_iWitchCount < MAXPLAYERS){

		g_iWitchRef[g_iWitchCount] = ref;

		decl String:sWitchName[8];
		FormatEx(sWitchName, 8, "%d", g_iWitchCount++);
		DispatchKeyValue(entity, "targetname", sWitchName);
	}
}

public Action:PD_ev_InfectedHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (bTempBlock || !(g_iCvarFlags & (1 << _:WITCH))) return;

	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	decl iWitchEnt;
	if (IsWitch((iWitchEnt = GetEventInt(event, "entityid"))) && IsClientAndInGame(attacker) && GetClientTeam(attacker) == 2){

		new iIndex = GetWitchIndex(iWitchEnt);
		if (iIndex == NULL) return;

		if (!g_bNoHrCrown[iIndex] && GetEventInt(event, "amount") != 90)
			g_bNoHrCrown[iIndex] = true;

		if (g_iTotalDamage[iIndex][WITCH] == g_iCvarHealth[WITCH]) return;

		new iDamage = GetEventInt(event, "amount");

		g_iDamage[attacker][iIndex][WITCH] += iDamage;
		g_iTotalDamage[iIndex][WITCH] += iDamage;

		#if debug
			PrintToChatAll("%d (Witch: indx %d, elem %d)", g_iTotalDamage[iIndex][WITCH], iWitchEnt, iIndex);
		#endif

		CorrectDmg(attacker, iIndex, false);
	}
}

GetWitchIndex(entity)
{
	decl String:sWitchName[8];
	GetEntPropString(entity, Prop_Data, "m_iName", sWitchName, 8);
	if (strlen(sWitchName) != 1) return -1;

	return StringToInt(sWitchName);
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
	if (!(g_iCvarFlags & (1 << _:WITCH))) return;

	new iIndex = GetWitchIndex(GetEventInt(event, "witchid"));
	if (iIndex == NULL || !g_iTotalDamage[iIndex][WITCH]) return;

	PrintDamage(iIndex, false, _, !g_bNoHrCrown[iIndex] ? 2 : GetEventInt(event, "oneshot"));
	g_bNoHrCrown[iIndex] = false;
}

PrintDamage(iIndex, bool:bTankBoss, bool:bLoose = false, iCrownTech = 0)
{
	decl iClient[MAXPLAYERS+1][BOSSES];
	new iSurvivors;

	for (new i = 1; i <= MaxClients; i++){

		if (!g_iDamage[i][iIndex][bTankBoss]) continue;

		if (!bTankBoss && IsClientInGame(i) || bTankBoss){

			if ((g_bCvarSkipBots && IsClientInGame(i) && !IsFakeClient(i)) || !g_bCvarSkipBots){

				iClient[iSurvivors][INDEX] = i;
				iClient[iSurvivors][DMG] = g_iDamage[i][iIndex][bTankBoss];
				iSurvivors++;
			}
		}
		// reset var
		g_iDamage[i][iIndex][bTankBoss] = 0;
	}
	if (!iSurvivors) return;

	if (iSurvivors == 1 && !bLoose){

		if (bTankBoss)
			PrintToChatAll("%N dealt %d damage to Tank", iClient[0][INDEX], iClient[0][DMG]);
		else{

			if (IsIncapacitated(iClient[0][INDEX]))
				PrintToChatAll("\x01%N '\x03Jerkstored\x01' a cr0wn (failed)", iClient[0][INDEX]);
			else
				PrintToChatAll("\x01%N \x03%scr0wn'd\x01 a Witch", iClient[0][INDEX], !iCrownTech ? "draw " : iCrownTech == 1 ? "" : "HR ");
		}
	}
	else {

		new Float:fTotalDamage = float(g_iCvarHealth[bTankBoss]);

		SortCustom2D(iClient, iSurvivors, SortFuncByDamageDesc);

		if (!bLoose && !(g_iCvarPrivateFlags & (1 << (bTankBoss ? 1 : 0))))
			PrintToChatAll("Damage dealt to %s (%d):", bTankBoss ? "Tank" : "Witch", g_iTotalDamage[iIndex][bTankBoss]);

		if (bTankBoss){

			decl String:sName[48], client, bool:bInGame;

			for (new i; i < iSurvivors; i++){

				client = iClient[i][INDEX];

				if ((bInGame = IsSurvivor(client)))
					GetClientName(client, sName, 48);
				else {

					IntToString(client, sName, 48);

					if (GetTrieString(g_hTrine, sName, sName, 48))
						Format(sName, 48, "%s (left the team)", sName);
					else
						sName = "unknown";
				}
					// private
				if (g_iCvarPrivateFlags & (1 << _:TANK)){

					if (bInGame)
						PrintToChat(client, "Damage dealt to Tank (%d):\nYou #%d: %d (%.0f%%)", g_iTotalDamage[iIndex][bTankBoss], i + 1, iClient[i][DMG], FloatMul(FloatDiv(float(iClient[i][DMG]), fTotalDamage), 100.0));
				}
				else // public
					PrintToChatAll("%d (%.0f%%): %s", iClient[i][DMG], FloatMul(FloatDiv(float(iClient[i][DMG]), fTotalDamage), 100.0), sName);
			}
		}
		else {

			for (new i; i < iSurvivors; i++){

				if (g_iCvarPrivateFlags & (1 << _:WITCH))
					PrintToChat(iClient[i][INDEX], "Damage dealt to Witch (%d):\nYou #%d: %d (%.0f%%)", g_iTotalDamage[iIndex][bTankBoss], i + 1, iClient[i][DMG], FloatMul(FloatDiv(float(iClient[i][DMG]), fTotalDamage), 100.0));
				else
					PrintToChatAll("%d (%.0f%%): %N", iClient[i][DMG], FloatMul(FloatDiv(float(iClient[i][DMG]), fTotalDamage), 100.0), iClient[i][INDEX]);
			}
		}
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
		g_iCvarHealth[WITCH] = GetConVarInt(convar);
}

public OnConvarChange_TankSelectTime(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_fCvarTankSelectTime = GetConVarFloat(convar);
}

public OnConvarChange_SkipBots(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarSkipBots = GetConVarBool(convar);
}

public OnConvarChange_SurvLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvar1v1Mode = GetConVarInt(convar) == 1 ? true : false;
}

public OnConvarChange_Flags(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarFlags = GetConVarInt(convar);
}

public OnConvarChange_Private(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_iCvarPrivateFlags = GetConVarInt(convar);
}

public OnConvarChange_RunAway(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarRunAway = GetConVarBool(convar);
}
