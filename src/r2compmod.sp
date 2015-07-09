/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.main.sp
 *  Type:			Main
 *  Description:	Contains defines, enums, etc available to anywhere in the
 *					plugin.
 *	Credits:		Greyscale & rhelgeby for their template "project base"
 *					(http://forums.alliedmods.net/showthread.php?t=117191).
 *
 *  Copyright (C) 2012-2015  raziEiL <war4291@mail.ru>
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
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

// **********************************************
//        Compiling options (Preprocessor)
// **********************************************
#pragma semicolon						1
#define R2COMP_LOG						0
#define DEBUG_COMMANDS				0	// r2comp_dump_cvar_status, r2comp_tp, r2comp_dis, r2comp_entdis.
#define UNSCRABBLE_LOG				0
#define UNSCRABBLE_MAX_FAILURE		3
#define SCORES_COMMAND				1

// **********************************************
//                   Reference
// **********************************************
#define SERVER_INDEX					0 // The client index of the server
#define FIRST_CLIENT					1 // First valid client index
#define TEAM_SPECTATOR				1
#define TEAM_SURVIVOR				2
#define TEAM_INFECTED				3
#define MAX_EDICTS					2048

new const String:MAIN_TAG[]		=	"[Rotoblin]";

// Plugin info
#define PLUGIN_FULLNAME				"Rotoblin 2 Competitive Mod (R2compMod)"			// Used when printing the plugin name anywhere
#define PLUGIN_SHORTNAME			"rotoblin"								// Shorter version of the full name, used in file paths, and other things
#define PLUGIN_AUTHOR				"Rotoblin Team, raziEiL [disawar1]"		// Author of the plugin
#define PLUGIN_DESCRIPTION			"A Fresh competitive mod for L4D"		// Description of the plugin
#define PLUGIN_VERSION				"1.3 dev"							// http://wiki.eclipse.org/Version_Numbering
#define PLUGIN_URL					"https://code.google.com/p/rotoblin2/"	// URL associated with the project
#define PLUGIN_CVAR_PREFIX			PLUGIN_SHORTNAME					// Prefix for cvars
#define PLUGIN_CMD_PREFIX			PLUGIN_SHORTNAME					// Prefix for cmds
#define PLUGIN_TAG					"Rotoblin"								// Tag for prints and commands
#define	PLUGIN_GAMECONFIG_FILE	PLUGIN_SHORTNAME						// Name of gameconfig file

// **********************************************
//                    Includes
// **********************************************
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4downtown>
#include <l4d_direct>
#include <r2comp_api>

#undef REQUIRE_PLUGIN

#include <l4d_lib>
#include "rotoblin.inc/rotoblin2"

public Plugin:myinfo =
{
	name = PLUGIN_FULLNAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

static Handle:g_hR2Version, Handle:g_hR2Enable, bool:g_bIsZACKLoaded, bool:g_bIsPluginEnabled, bool:g_bPLend;

public OnPluginStart()
{
	DebugLog("%s			ON PL START", MAIN_TAG);
	DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Setting up...");

	decl String:sBuffer[128];
	FormatEx(sBuffer, 128, "%s version", PLUGIN_FULLNAME);

	g_hR2Version = CreateConVarEx("2_version", PLUGIN_VERSION, sBuffer);
	SetConVarString(g_hR2Version, PLUGIN_VERSION);

	g_hR2Enable = CreateConVarEx("enable", "0", "Enables Rotoblin 2 Competitive Mod (R2compMod)", _, true, 0.0, true, 1.0);

	new bool:bEnable = GetConVarBool(g_hR2Enable);

	CheckR2Cvars(bEnable);
	HookConVarChange(g_hR2Enable, _Main_Enable_CvarChange);
	DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Done setting up!");

	_H_EventManager_OnPluginStart();
	_H_TankManager_OnPluginStart();
	_H_ClientIndexes_OnPluginStart();
	_H_CommandManager_OnPluginStart();
	_H_MultiTargets_OnPluginStart();

	//_AutoUpdate_OnPluginStart();
	_HealthControl_OnPluginStart();
	_WeaponControl_OnPluginStart();
	_GhostTank_OnPluginStart();
	_Pause_OnPluginStart();
	_InfExloitFixes_OnPluginStart();
	_DespawnInfected_OnPluginStart();
	_NoPropFading_OnPluginStart();
	_ReportStatus_OnPluginStart();
	_LimitHuntingRifl_OnPluginStart();
	_ItemControl_OnPluginStart();
	_MeleeFatigue_OnPluginStart();
	_FinaleSpawn_OnPluginStart();

	_AutoLoader_OnPluginStart();
	_MapInfo_OnPluginStart();
	_TrackCvars_OnPluginStart();
	_WaterSlowdown_OnPluginStart();
	_NoEscapeTank_OnPluginStart();
	_GhostWarp_OnPluginStart();
	_ExpoliteFixed_OnPluginStart();
	_WitchTracking_OnPluginStart();
	_MobsControl_OnPluginStart();
	_Weapon_Attributes_OnPluginStart();
	_PluginManager_OnPluginStart();
	_ReqMatch_OnPluginStart();
	_DHostName_OnPluginStart();
	_HeadsUpDisplay_OnPluginStart();
	_ClientSettings_OnPluginStart();
	_Unscramble_OnPluginStart();
	_TankSpawns_OnPluginStart();
	_UnprohibitBosses_OnPluginStart();

	SetPluginState(bEnable);
}

public OnAllPluginsLoaded()
{
	DebugLog("%s			ON ALL PL LOADED", MAIN_TAG);

	_Zack_OnAllPluginsLoaded();
	_AutoLoader_OnAllPluginsLoaded();
}

public OnPluginEnd()
{
	DebugLog("%s			ON PL END", MAIN_TAG);
	g_bPLend = true;

	_TC_OnPluginDisabled();
	_PM_OnPluginDisabled();
	_DN_OnPluginEnd();
	_AL_OnPluginEnd();
	_RM_OnPluginEnd();
	_UM_OnPluginEnd();
	_TC_OnPluginEnd();
}

public OnMapStart()
{
	if (!g_bIsPluginEnabled) return;

	DebugLog("%s			ON MAP START", MAIN_TAG);

	_MI_OnMapStart();
	_CI_OnMapStart();
	_WSD_OnMapStart();
	_AS_OnMapStart();
	_UB_OnMapStart();
}


public OnMapEnd()
{
	if (!g_bIsPluginEnabled) return;

	DebugLog("%s			ON MAP END", MAIN_TAG);

	_CI_OnMapEnd();
	_IC_OnMapEnd();
	_P_OnMapEnd();
	_WC_OnMapEnd();
	_MC_OnMapEnd();
	_WT_OnMapEnd();
	_TS_OnMapEnd();
}

public OnClientPutInServer(client)
{
	if (!g_bIsPluginEnabled || !client) return;
	_FS_OnClientPutInServer(client);
	_LHR_OnClientPutInServer(client);
	_EF_OnClientPutInServer(client);
	_AS_OnClientPutInServer(client);
	_HUD_OnClientPutInServer(client);
	_GT_OnClientPutInServer(client);
}

public OnClientDisconnect(client)
{
	if (!client) return;
	_AL_OnClientDisconnect(client); // always change map when server is emtpy

	/*if (!g_bIsPluginEnabled) return;
	 *
	 *		Some code here...
	 */
}

public OnClientDisconnect_Post(client)
{
	if (!g_bIsPluginEnabled || !client) return;
	_H_TM_OnClientDisconnect_Post(client);
}

public OnConfigsExecuted()
{
	if (!g_bIsPluginEnabled) return;
	DebugLog("%s			ON CFG EXECUTED", MAIN_TAG);
	_RM_OnConfigsExecuted();
	_DN_OnConfigsExecuted();
	_WA_OnConfigsExecuted();
}
/*												+==========================================+
																Global Events
												+==========================================+
*/
Global_ev_OnTankSpawn()
{
	_NPF_ev_OnTankSpawn();
	_HUD_ev_OnTankSpawn();
	_TS_ev_OnTankSpawn();
}

Global_ev_OnTankPassed()
{

}

Global_ev_OnTankKilled()
{
	_GT_ev_OnTankKilled();
}
/*												+==========================================+
																SDK Hooks
												+==========================================+
*/
public OnEntityCreated(entity, const String:classname[])
{
	if (g_bIsPluginEnabled && entity > 0 && IsValidEntity(entity)){

		_DI_OnEntityCreated(entity, classname);
		_WC_OnEntityCreated(entity, classname);
	}
}

public OnEntityDestroyed(entity)
{
	if (g_bIsPluginEnabled && entity > 0 && IsValidEntity(entity)){

		_DI_OnEntityDestroyed(entity);
	}
}
/*												+==========================================+
																Zack plugin
												+==========================================+
*/
_Zack_OnAllPluginsLoaded()
{
	if (LibraryExists("zack")) // If ZACK is loaded on the server
		g_bIsZACKLoaded = true;
	else
		g_bIsZACKLoaded = false;
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "zack"))
		g_bIsZACKLoaded = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "zack"))
		g_bIsZACKLoaded = true;
}

bool:IsZACKLoaded()
{
	return g_bIsZACKLoaded;
}
// ===

SetPluginState(bool:enabled)
{
	if (g_bIsPluginEnabled == enabled) return; // No change in plugin state, return
	g_bIsPluginEnabled = enabled;

	DebugLog("%s			ON PL %s", MAIN_TAG, enabled ? "ENABLED" : "DISABLED");

	if (enabled){

		_DI_OnPluginEnabled();
		_FS_OnPluginEnabled();
		_GT_OnPluginEnabled();
		_CI_OnPluginEnabled();
		_H_TM_OnPluginEnabled();
		_HC_OnPluginEnabled();
		_IEF_OnPluginEnabled();
		_LHR_OnPluginEnabled();
		_MF_OnPluginEnabled();
		_NPF_OnPluginEnabled();
		_P_OnPluginEnabled();
		_WC_OnPluginEnabled();
		_EF_OnPluginEnabled();
		_GW_OnPluginEnabled();
		_HUD_OnPluginEnabled();
		_IC_OnPluginEnabled();
		_MC_OnPluginEnabled();
		_NET_OnPluginEnabled();
		_WSD_OnPluginEnabled();
		_WT_OnPluginEnabled();
		_TC_OnPluginStart();
		_UM_OnPluginEnabled();
		_TS_OnPluginEnabled();
		_UB_OnPluginEnabled();

		DebugLog("%s All MODULES SETUPED!", MAIN_TAG);
	}
	else{

		_TC_OnPluginDisabled();
		_DI_OnPluginDisabled();
		_FS_OnPluginDisabled();
		_GT_OnPluginDisabled();
		_CI_OnPluginDisabled();
		_H_TM_OnPluginDisabled();
		_HC_OnPluginDisabled();
		_IEF_OnPluginDisabled();
		_LHR_OnPluginDisabled();
		_MF_OnPluginDisabled();
		_NPF_OnPluginDisabled();
		_P_OnPluginDisabled();
		_WC_OnPluginDisabled();
		_EF_OnPluginDisabled();
		_GW_OnPluginDisabled();
		_HUD_OnPluginDisable();
		_IC_OnPluginDisabled();
		_MC_OnPluginDisabled();
		_NET_OnPluginDisable();
		_WSD_OnPluginDisabled();
		_WT_OnPluginDisabled();
		_TS_OnPluginDisabled();
		_UB_OnPluginDisabled();

		_DN_OnPluginDisabled();
		_PM_OnPluginDisabled();
		_CS_OnPluginDisabled();
		_UM_OnPluginDisabled();
	}
}

bool:IsPluginEnabled()
{
	return g_bIsPluginEnabled;
}

bool:IsPluginEnd()
{
	return g_bPLend;
}

ForceTurnOff()
{
	SetConVarBool(g_hR2Enable, false);
}

public _Main_Enable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	new bool:bNewVal = bool:StringToInt(newValue);

	if (CheckR2Cvars(bNewVal) || StrEqual(oldValue, newValue)) return;

	DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Enable cvar was changed. Old value %s, new value %s", oldValue, newValue);

	SetPluginState(bNewVal);
}

CheckR2Cvars(bool:bVal)
{
	if (bVal && !IsDedicatedServer())
	{
		SetConVarBool(g_hR2Enable, false);
		DebugPrintToAll(DEBUG_CHANNEL_GENERAL, "[Main] Unable to enable rotoblin, running on a listen server!");
		PrintToChatAll("[%s] Unable to enable %s! %s is only supported on dedicated servers", PLUGIN_TAG, PLUGIN_FULLNAME, PLUGIN_FULLNAME);
	}
}
