/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.TrackCvars.sp
 *  Type:			Module
 *  Description:	...
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

#define		TC_TAG		"[TrackCvars]"
#define		SILENT	1

static		Handle:g_hConVarArray, Handle:g_hConVarArrayEx, bool:g_bLockConVars;

enum CVAR_STRUCTURE
{
	String:sCVar[64],
	iCVar
};

static const g_aStaticVars[][CVAR_STRUCTURE] =
{
	{ "versus_force_start_time",		 9999 },
	{ "director_transition_timeout",		0 },

	{ "z_mob_spawn_min_interval_normal",	8 }, // Req in rotoblin.MobsControl.sp
	{ "z_mob_spawn_max_interval_normal",	8 },

	{ "sb_all_bot_team",					1 }, // disable hibernation
	{ "sb_separation_danger_min_range",		120 },
	{ "sb_separation_danger_max_range",		0 }
};

_TrackCvars_OnPluginStart()
{
	RegServerCmd("rotoblin_track_variable",		CmdTrackVariable,		"Add a convar to track");
	RegServerCmd("rotoblin_track_variable_ex",	CmdTrackVariableEx,	"Add a convar to track but ignore a global lock");
	RegServerCmd("rotoblin_lock_variables",		CmdLockVariable,		"Lock all tracked convar to changes");
	RegServerCmd("rotoblin_unlock_variables",	CmdUnlockVariable,		"Unlock all tracked convar to changes");
	RegServerCmd("rotoblin_reset_variables",		CmdResetVariable,		"Reset all tracked convars to its default value");

	g_hConVarArray = CreateArray(64);
	g_hConVarArrayEx = CreateArray(64);

	new Handle:hSBAllBotTeam = FindConVar(g_aStaticVars[4][sCVar]);
	SetConVarInt(hSBAllBotTeam, g_aStaticVars[4][iCVar]);
	HookConVarChange(hSBAllBotTeam, OnStatic_ConVarChange);
}

_TC_OnPluginStart()
{
	StaticVars(true);
}

_TC_OnPluginDisabled()
{
	StaticVars(false);
	CmdUnlockVariable(0);
	CmdResetVariable(0);
}

public Action:CmdTrackVariable(args)
{
	if (args != 2 && args != 3){

		PrintToServer("rotoblin_track_variable <can not be reseted? true|emtpy> <convar> <val>");
		return Plugin_Handled;
	}

	decl String:sConvar[64];
	GetCmdArg(1, sConvar, 64);

	new bool:bCanBeReseted = true;
	if (StrEqual(sConvar, "true")){

		bCanBeReseted = false;
		GetCmdArg(2, sConvar, 64);
	}

	new Handle:hConVar = FindConVar(sConvar);
	if (!IsValidConVar(hConVar)){

		DebugLog("%s Warning ConVar \"%s\" not found!", TC_TAG, sConvar);
		return Plugin_Handled;
	}
	if (IsConVarTracked(g_hConVarArray, sConvar)){

		DebugLog("%s Warning ConVar \"%s\" already tracked!", TC_TAG, sConvar);
		return Plugin_Handled;
	}

	decl String:sValue[64];
	GetCmdArg(bCanBeReseted ? 2 : 3, sValue, 64);

	DebugLog("%s ConVar \"%s\" \"%s\" is added to track", TC_TAG, sConvar, sValue);

	SetConVarString(hConVar, sValue, true);
	HookConVarChange(hConVar, OnTracked_ConVarChange);

	if (bCanBeReseted)
		PushArrayString(g_hConVarArray, sConvar);

	return Plugin_Handled;
}

public Action:CmdTrackVariableEx(args)
{
	if (args != 2){

		PrintToServer("rotoblin_track_variable_ex <convar> <val>");
		return Plugin_Handled;
	}

	decl String:sConvar[64];
	GetCmdArg(1, sConvar, 64);

	new Handle:hConVar = FindConVar(sConvar);
	if (!IsValidConVar(hConVar)){

		DebugLog("%s Warning ConVarEx \"%s\" not found!", TC_TAG, sConvar);
		return Plugin_Handled;
	}

	decl String:sValue[64];
	GetCmdArg(2, sValue, 64);

	SetConVarString(hConVar, sValue, true);

	if (IsConVarTracked(g_hConVarArrayEx, sConvar))
		return Plugin_Handled;

	DebugLog("%s ConVarEx \"%s\" \"%s\" is added to track", TC_TAG, sConvar, sValue);

	PushArrayString(g_hConVarArrayEx, sConvar);
	return Plugin_Handled;
}

public Action:CmdLockVariable(args)
{
	if (g_bLockConVars) return;

	g_bLockConVars = true;
	DebugLog("%s Changing of ConVars is Locked!", TC_TAG);
}

public Action:CmdUnlockVariable(args)
{
	if (!g_bLockConVars) return;

	g_bLockConVars = false;
	DebugLog("%s Changing of ConVars is Unlocked!", TC_TAG);
}

public Action:CmdResetVariable(args)
{
	new iArraySize;

	if ((iArraySize = IsConVarTracked(g_hConVarArray, _, true)))
		ResetConVars(g_hConVarArray, iArraySize, false);

	if ((iArraySize = IsConVarTracked(g_hConVarArrayEx, _, true)))
		ResetConVars(g_hConVarArrayEx, iArraySize, true);

	DebugLog("%s Stop tracked all ConVars", TC_TAG);
}

ResetConVars(Handle:hArray, iArraySize, bool:bConVarEx)
{
	decl String:sArrayConVar[64], Handle:hConVar;

	for (new Index = 0; Index < iArraySize; Index++){

		GetArrayString(hArray, Index, sArrayConVar, 64);
		hConVar = FindConVar(sArrayConVar);

		if (!IsValidConVar(hConVar)){

			DebugLog("%s Warning tracked ConVar \"%s\" is no longer valid and skipped", TC_TAG, sArrayConVar);
			continue;
		}

		if (!bConVarEx && !IsPluginEnd())
			UnhookConVarChange(hConVar, OnTracked_ConVarChange);

		ResetConVar(hConVar);
		DebugLog("%s ResetConVar \"%s\"", TC_TAG, sArrayConVar);
	}

	ClearArray(hArray);
}

IsConVarTracked(Handle:hArray, const String:sConVar[] = "", bool:bResetConVars = false)
{
	if (hArray == INVALID_HANDLE){

		DebugLog("%s Array hndl is invalide!", TC_TAG);
		return false;
	}

	new iArraySize = GetArraySize(hArray);

	if (!iArraySize){

		if (strlen(sConVar) == 0)
			DebugLog("%s None of the ConVar is not tracked", TC_TAG);
		return false;
	}
	if (bResetConVars)
		return iArraySize;

	return FindStringInArray(hArray, sConVar) != -1;
}

bool:IsValidConVar(Handle:hConVar)
{
	return hConVar != INVALID_HANDLE;
}

static StaticVars(bool:bHook)
{
	static bool:bHooked;

	if (bHook){

		if (!bHooked)
			bHooked = true;
		else
			return;
	}
	else if (!bHook)
		bHooked = false;

	new iMaxSize = sizeof(g_aStaticVars);
	decl Handle:hCvar;

	for (new INDEX; INDEX < iMaxSize; INDEX++){

		if (INDEX == 4) continue;
		DebugLog("%s StaticConVar \"%s\" \"%d\" now is %s", TC_TAG, g_aStaticVars[INDEX][sCVar], g_aStaticVars[INDEX][iCVar], bHook ? "blocked" : "reseted");

		hCvar = FindConVar(g_aStaticVars[INDEX][sCVar]);

		if (bHook){

			SetConVarInt(hCvar, g_aStaticVars[INDEX][iCVar]);
			HookConVarChange(hCvar, OnStatic_ConVarChange);
		}
		else {

			if (!IsPluginEnd())
				UnhookConVarChange(hCvar, OnStatic_ConVarChange);

			ResetConVar(hCvar);
		}
	}
}

public OnTracked_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!g_bLockConVars || StrEqual(oldValue, newValue)) return;

	decl String:sConvar[128];
	GetConVarName(convar, sConvar, 128);
	#if !SILENT
		PrintToChatAll("ConVar \"%s\" is tracked. Can not changed from \"%s\" to \"%s\"!", sConvar, oldValue, newValue);
	#endif
	DebugLog("%s ConVar \"%s\" is tracked. Can not changed from \"%s\" to \"%s\"!", TC_TAG, sConvar, oldValue, newValue);

	UnhookConVarChange(convar, OnTracked_ConVarChange);
	SetConVarString(convar, oldValue, true);
	HookConVarChange(convar, OnTracked_ConVarChange);
}

public OnStatic_ConVarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	decl String:sConvar[128];
	GetConVarName(convar, sConvar, 128);

	DebugLog("%s StaticConVar \"%s\" is tracked. Can not changed from \"%s\" to \"%s\"!", TC_TAG, sConvar, oldValue, newValue);

	UnhookConVarChange(convar, OnStatic_ConVarChange);
	SetConVarString(convar, oldValue, true);
	HookConVarChange(convar, OnStatic_ConVarChange);
}