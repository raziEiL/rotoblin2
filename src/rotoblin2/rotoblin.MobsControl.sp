/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.MobsControl.sp
 *  Type:			Module
 *  Description:	Remove natural hordes while tank in game...
 *
 *  Copyright (C) 2012-2014 raziEiL <war4291@mail.ru>
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

#define		MC_TAG	 "[MobsControl]"

static		Handle:g_hMobTimer, Handle:g_hAllowHordes, Handle:g_hTankHordes, Handle:g_hCvarNoStartsCI,
			g_iCvarMobTime, bool:g_bCvarTankHordes, bool:g_bCvarNoStartsCI, bool:g_bEvents, bool:g_bLeftStartArea, g_iTick;

_MobsControl_OnPluginStart()
{
	g_hAllowHordes		= CreateConVarEx("allow_natural_hordes",		"-1", "Sets whether natural hordes will spawn. (-1: director settings, 0: disable, > 0: spawn interval to cvar value)", _, true, -1.0);
	g_hTankHordes		= CreateConVarEx("disable_tank_hordes",			"0", "If set, natural hordes will not spawn while tank is in play. (0: enable, 1: disable).", _, true, 0.0, true, 1.0);
	g_hCvarNoStartsCI	= CreateConVarEx("remove_start_commons",		"0", "Removes all common infected near the saferoom and respawns them when one of survivors leaves the saferoom.", _, true, 0.0, true, 1.0);

	#if DEBUG_COMMANDS
		RegAdminCmd("sm_mobtimer", Command_GetMobTimer, ADMFLAG_ROOT);
	#endif
}

_MC_OnPluginEnabled()
{
	g_bLeftStartArea = false;

	HookEvent("round_start",					_MC_ev_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area",		_MC_ev_PlayerLeftStartArea, EventHookMode_PostNoCopy);

	HookConVarChange(g_hAllowHordes,		_MC_Enable_CvarChange);
	HookConVarChange(g_hTankHordes,		_MC_TankHordes_CvarChange);
	HookConVarChange(g_hCvarNoStartsCI,	_MC_NoStartsCI_CvarChange);

	Update_MC_EnableConVar();
	Update_MC_TankHordesConVar();
	Update_MC_NoStartsCIConVar();
}

_MC_OnPluginDisabled()
{
	g_bLeftStartArea = true;

	UnhookEvent("round_start",				_MC_ev_RoundStart, EventHookMode_PostNoCopy);
	UnhookEvent("player_left_start_area",	_MC_ev_PlayerLeftStartArea, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hAllowHordes,		_MC_Enable_CvarChange);
	UnhookConVarChange(g_hTankHordes,		_MC_TankHordes_CvarChange);
	UnhookConVarChange(g_hCvarNoStartsCI,	_MC_NoStartsCI_CvarChange);

	_MC_ToggleEvents(false);
}

_MC_OnMapEnd()
{
	g_hMobTimer = INVALID_HANDLE;
}

public _MC_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bLeftStartArea = false;
	_MC_TogggleBotBehavior(true);

	if (g_bCvarNoStartsCI)
		CreateTimer(0.5, _MC_t_SlayCI, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	if (g_iCvarMobTime > 0){

		_MC_ToggleHordes(true);
		_MC_KillMobTimer();
	}
}

public _MC_ev_PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bLeftStartArea = true;
	_MC_TogggleBotBehavior(false);

	DebugLog("%s Surv left start area. Timer _MC_t_SlayCI killed", MC_TAG);

	if (g_iCvarMobTime > 0){

		DebugLog("%s Mobs every %d sec", MC_TAG, g_iCvarMobTime);
		_MC_ResetMobTimer();
	}
}

// slay CI
public Action:_MC_t_SlayCI(Handle:timer)
{
	if (g_bLeftStartArea) return Plugin_Stop;

	new iEnt = -1, iCount;
	while ((iEnt = FindEntityByClassname(iEnt , "infected")) != INVALID_ENT_REFERENCE){

		AcceptEntityInput(iEnt, "Kill");
		iCount++;
	}

	if (iCount)
		DebugLog("%s Slayed %d common infected", MC_TAG, iCount);

	return Plugin_Continue;
}
// ---

// left4downtown
_MC_L4D_OnSpawnTank()
{
	if (g_iCvarMobTime > 0 && g_bCvarTankHordes && !g_bVehicleIncoming){

		if (_MC_KillMobTimer())
			DebugLog("%s Tank spawn. Hordes are turned OFF!", MC_TAG);
	}
}

public Action:_MC_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarTankHordes && IsPlayerTank(GetEventInt(event, "entindex_killed")))
		CreateTimer(1.0, _MC_t_FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:_MC_t_FindAnyTank(Handle:timer)
{
	if (FindTankClient()) return;

	_MC_ResetMobTimer();
	DebugLog("%s Tank killed. Hordes are turned ON!", MC_TAG);
}

static _MC_ResetMobTimer()
{
	g_hMobTimer = CreateTimer(1.0, _MC_t_SpawnMob, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:_MC_t_SpawnMob(Handle:timer)
{
	if (++g_iTick != g_iCvarMobTime) return;

	g_iTick = 0;

	_MC_ToggleHordes(false);
	CreateTimer(3.0, _MC_t_DisableSapwn);
}

public Action:_MC_t_DisableSapwn(Handle:timer)
{
	_MC_ToggleHordes(true);
}

static bool:_MC_KillMobTimer()
{
	g_iTick = 0;

	if (g_hMobTimer != INVALID_HANDLE){

		KillTimer(g_hMobTimer);
		g_hMobTimer = INVALID_HANDLE;
		return true;
	}
	return false;
}

static _MC_ToggleHordes(bool:bVal)
{
	if (bVal)
		AddConVarToTrack("director_no_mobs", "1");
	else
		ReleaseTrackedConVar("director_no_mobs");
}

static _MC_TogggleBotBehavior(bool:bStopRushing)
{
	DebugLog("%s Toggle bot behavior: %s", MC_TAG, bStopRushing ? "don't rush" : "default");

	if (bStopRushing){

		AddConVarToTrack("sb_separation_danger_min_range", "120");
		AddConVarToTrack("sb_separation_danger_max_range", "0");
	}
	else {

		ReleaseTrackedConVar("sb_separation_danger_min_range");
		ReleaseTrackedConVar("sb_separation_danger_max_range");
	}
}

public Native_R2comp_GetMobTimer(Handle:plugin, numParams)
{
	return MC_GetMobTimer();
}

MC_GetMobTimer()
{
	return g_iCvarMobTime < 1 ? -1 : g_iCvarMobTime - g_iTick;
}

public _MC_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_EnableConVar();
}

static Update_MC_EnableConVar()
{
	g_iCvarMobTime = GetConVarInt(g_hAllowHordes);

	if (g_iCvarMobTime == -1) return;

	AddConVarToTrack("z_mob_spawn_min_interval_easy", "8");
	AddConVarToTrack("z_mob_spawn_max_interval_easy", "8");
	AddConVarToTrack("z_mob_spawn_min_interval_normal", "8");
	AddConVarToTrack("z_mob_spawn_max_interval_normal", "8");
	AddConVarToTrack("z_mob_spawn_max_interval_hard", "8");
	AddConVarToTrack("z_mob_spawn_min_interval_hard", "8");
	AddConVarToTrack("z_mob_spawn_min_interval_expert", "8");
	AddConVarToTrack("z_mob_spawn_max_interval_expert", "8");

	_MC_ToggleEvents(bool:(g_iCvarMobTime));
	_MC_ToggleHordes(true);
}

public _MC_TankHordes_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_TankHordesConVar();
}

static Update_MC_TankHordesConVar()
{
	g_bCvarTankHordes = GetConVarBool(g_hTankHordes);
}

static _MC_ToggleEvents(bool:bHook)
{
	if (!g_bEvents && bHook){

		HookEvent("entity_killed",				_MC_ev_EntityKilled);
		g_bEvents = true;
	}
	else if (g_bEvents && !bHook){

		UnhookEvent("entity_killed",				_MC_ev_EntityKilled);
		g_bEvents = false;

		_MC_KillMobTimer();
	}
}

public _MC_NoStartsCI_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_MC_NoStartsCIConVar();
}

Update_MC_NoStartsCIConVar()
{
	g_bCvarNoStartsCI = GetConVarBool(g_hCvarNoStartsCI);
}

#if DEBUG_COMMANDS
public Action:Command_GetMobTimer(client, args)
{
	ReplyToCommand(client, "Mob timer: %d (-1 = Disabled)", MC_GetMobTimer());
	return Plugin_Handled;
}
#endif

stock _MC_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hAllowHordes)) != g_iCvarMobTime)
		DebugLog("%d		|	%d		|	rotoblin_allow_natural_hordes", iVal, g_iCvarMobTime);
	if (bool:(iVal = GetConVarBool(g_hTankHordes)) != g_bCvarTankHordes)
		DebugLog("%d		|	%d		|	rotoblin_disable_tank_hordes", iVal, g_bCvarTankHordes);
}
