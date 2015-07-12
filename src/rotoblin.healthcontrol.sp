/*
 * ============================================================================
 *
 *  Original modified Rotoblin module
 *
 *  File:			rotoblin.healthcontrol.sp
 *  Type:			Module
 *  Description:	Removes/replaces health items depending on settings
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

// --------------------
//       Public
// --------------------

#define			HC_TAG	"[HealthControl]"

#define 		REMOVE_THIS_ITEM	-1	// Remove them from specifically location
#define 		LEAVE_THIS_ITEM		0	// Don't replace any medkits with pills
#define 		REPLACE_TO_PILLS	1	// Replace medkits with pills
#define 		KEEP_IN_FINAL		2	// Remove them from specifically location but keep in final

// --------------------
//       Private
// --------------------
#define			PILLS				0
#define			PILLS_VS			1

static	const	String:	FIRST_AID_KIT_CLASSNAME[]		= "weapon_first_aid_kit_spawn";
static	const	String:	PAIN_PILLS_CLASSNAME[]		= "weapon_pain_pills_spawn";
static	const	String:	MODEL_PAIN_PILLS[]				= "models/w_models/weapons/w_eq_painpills.mdl";



static					g_iDebugChannel						= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]			= "HealthControl";



static 		Handle:g_hOSF_Style, Handle:g_hSSR_Style, Handle:g_hFSR_Style, Handle:g_hPills_Style, Handle:g_hESR_Style, Handle:g_h1v1WipePills, Handle:g_hItemTranslations, Handle:g_hConvert[2],
			g_iCvarOSF_Style, g_iCvarSSR_Style, g_iCvarFSR_Style, g_iCvarESR_Style, bool:g_bCvarPills_Style, g_iCvarWipePills, bool:g_bIsItemTranslations;

new 	bool:g_Public_bIsFinalMap;
// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
_HealthControl_OnPluginStart()
{
	g_hConvert[PILLS]		=	FindConVar("director_convert_pills");
	g_hConvert[PILLS_VS]	=	FindConVar("director_vs_convert_pills");

	g_hOSF_Style				=	CreateConVarEx("replace_outsidekits", "0", "How medkits will be replaced out of saferooms. (-1: remove medkits, 0: director settings, 1: replace with pain pills. Extra option 2: remove all healing items except of finals)", _, true, -1.0, true, 2.0);
	g_hSSR_Style				=	CreateConVarEx("replace_startkits", "0", "How medkits will be replaced in the saferoom. (-1: remove medkits, 0: director settings, 1: replace with pain pills)", _, true, -1.0, true, 1.0);
	g_hESR_Style				=	CreateConVarEx("replace_endkits", "0", "How medkits will be replaced in the end saferoom. (-1: remove medkits, 0: director settings, 1: replace with pain pills)", _, true, -1.0, true, 1.0);
	g_hFSR_Style				=	CreateConVarEx("replace_finalekits", "0", "How medkits will be replaced on finales. (-1: remove medkits, 0: director settings, 1: replace with pain pills)", _, true, -1.0, true, 1.0);
	g_hPills_Style			=	CreateConVarEx("pills_autogiver", "0", "Sets whether the survivors will Automatically receive pills after they leave the saferoom", _, true, 0.0, true, 1.0);
	g_h1v1WipePills			=	CreateConVarEx("1v1_wipe_pills", "0", "The number of pills that will be removed during the final (0: disable 1v1 features)", _, true, 0.0, true, 4.0);
	g_hItemTranslations		=	CreateConVarEx("item_translations", "0", "Keep items to translations in co-op gamemode", _, true, 0.0, true, 1.0);

	AddConVarToReport(g_hOSF_Style); // Add to report status module

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
_HC_OnPluginEnabled()
{
	//ConvertToPillsConVars();
	HookEvent("round_start", _HC_RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", _HC_PlayerLeftStartArea, EventHookMode_PostNoCopy);

	HookConVarChange(g_hOSF_Style, 		_HC_HealthStyle_CvarChange);
	HookConVarChange(g_hSSR_Style, 		_HC_StartKitsStyle_CvarChange);
	HookConVarChange(g_hFSR_Style, 		_HC_FinaleKitsStyle_CvarChange);
	HookConVarChange(g_hESR_Style, 		_HC_EndKitsStyle_CvarChange);
	HookConVarChange(g_hPills_Style, 	_HC_GivePillsToSurv_CvarChange);
	HookConVarChange(g_h1v1WipePills, 	_HC_1v1WipePills_CvarChange);
	HookConVarChange(g_hItemTranslations, 	_HC_ItemTranslations_CvarChange);
	Update_HC_ConVars();

	DebugLog("%s Module is now loaded", HC_TAG);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
_HC_OnPluginDisabled()
{
	UnhookEvent("round_start", _HC_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookEvent("player_left_start_area", _HC_PlayerLeftStartArea, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hOSF_Style, 		_HC_HealthStyle_CvarChange);
	UnhookConVarChange(g_hSSR_Style, 		_HC_StartKitsStyle_CvarChange);
	UnhookConVarChange(g_hFSR_Style, 		_HC_FinaleKitsStyle_CvarChange);
	UnhookConVarChange(g_hESR_Style, 		_HC_EndKitsStyle_CvarChange);
	UnhookConVarChange(g_hPills_Style, 		_HC_GivePillsToSurv_CvarChange);
	UnhookConVarChange(g_h1v1WipePills, 	_HC_1v1WipePills_CvarChange);
	UnhookConVarChange(g_hItemTranslations, 	_HC_ItemTranslations_CvarChange);
	
	SetDirectorSettings(g_hConvert[PILLS], 0);
	SetDirectorSettings(g_hConvert[PILLS_VS], 0);

	DebugLog("%s Module is now unloaded", HC_TAG);
}

public Action:_HC_PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bCvarPills_Style)
		GivePillsToSurvivors();
}

public _HC_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	DebugPrintToAllEx("Round start - Running health control");
	CreateTimer(0.3, _HC_t_RoundStartDelay);
}

public Action:_HC_t_RoundStartDelay(Handle:timer)
{
	CheckIsFinalMap();
	UpdateStartingHealthItems();
}

static CheckIsFinalMap()
{
	g_Public_bIsFinalMap = IsFinalMap();

	DebugLog("%s Final map? (%s)", HC_TAG, g_Public_bIsFinalMap ? "YES" : "NO");
}

/**
 * Replaces or removes items present at the start of the round.  Logic run is based on the chosen health style.
 *
 * @noreturn
 */
static UpdateStartingHealthItems()
{
	DebugPrintToAllEx("Updating starting health items.");
	DebugLog("%s Location: SSF - start safe room, OSR - outside safe room, ESR - end safe room", HC_TAG);

	decl Float:vOrg[3];
	new iEnt = -1, i1v1Wipe;

	while ((iEnt = FindEntityByClassname(iEnt , PAIN_PILLS_CLASSNAME)) != INVALID_ENT_REFERENCE){

		GetEntityOrg(iEnt, vOrg);

		if (IsVectorNull(vOrg)) continue;

		if (IsEntOutSideSafeRoom(vOrg)){

			if (!g_Public_bIsFinalMap && g_iCvarOSF_Style == KEEP_IN_FINAL){

				_HC_LOG(3, true, g_iCvarOSF_Style, iEnt, vOrg);
				SafelyRemoveEdict(iEnt);
			}
			else
				_HC_LOG(3, true, g_iCvarOSF_Style, iEnt, vOrg);
		}
		else
			_HC_LOG(-1, true, 0, iEnt, vOrg);
	}

	// keep translations items in co-op gamemode
	new bool:bTranslation = IsItemTranslationFeature();
	
	iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt , FIRST_AID_KIT_CLASSNAME)) != INVALID_ENT_REFERENCE){

		GetEntityOrg(iEnt, vOrg);

		if (IsVectorNull(vOrg)) continue;

		if (IsEntInStartSafeRoom(vOrg)){

			if (bTranslation) continue;

			_HC_LOG(1, false, g_iCvarSSR_Style, iEnt, vOrg);
			CaseHealthStyle(iEnt, g_iCvarSSR_Style);
		}
		else if (IsEntInEndSafeRoom(vOrg)){

			// 1v1
			if (g_Public_bIsFinalMap && i1v1Wipe < g_iCvarWipePills > 0){

				i1v1Wipe++;
				_HC_LOG(2, false, 2, iEnt, vOrg);
				SafelyRemoveEdict(iEnt);
				continue;
			}

			_HC_LOG(g_Public_bIsFinalMap ? 4 : 3, false, g_Public_bIsFinalMap ? g_iCvarFSR_Style : g_iCvarESR_Style, iEnt, vOrg);
			CaseHealthStyle(iEnt, g_Public_bIsFinalMap ? g_iCvarFSR_Style : g_iCvarESR_Style);
		}
		else {

			_HC_LOG(3, false, g_iCvarOSF_Style, iEnt, vOrg);

			// если не финальная карта и нам нужно удалить аптечки
			if (!g_Public_bIsFinalMap && g_iCvarOSF_Style == KEEP_IN_FINAL)
				SafelyRemoveEdict(iEnt);
			else
				CaseHealthStyle(iEnt, g_iCvarOSF_Style);
		}
	}
}

// Global
bool:IsItemTranslationFeature()
{
	return !IsVersusMode() && !IsNewMission() && g_bIsItemTranslations;
}

static _HC_LOG(iType, bool:bPills, iCvar, iEnt, Float:vOrg[3])
{
	DebugLog("%s [%s] [Item:%s] [Action:%s] %.1f %.1f %.1f (index %d)", HC_TAG, iType == -1 ? "No Matter" : iType == 1 ? "SSF" : iType == 2 ? "ESR" : iType == 4 ? "ESR" : "OSR", !bPills ? "Medkit" : "Pills", !iCvar ? "Skipp Me" : iCvar == 1 ? "To Pills" : iCvar == -1 ? "Remove" : "Remove but keep in final", vOrg[0], vOrg[1], vOrg[2], iEnt);
}

static CaseHealthStyle(entity, style)
{
	if (style == LEAVE_THIS_ITEM) return;

	switch (style){

		case REPLACE_TO_PILLS, KEEP_IN_FINAL:
			ReplaceKitWithPills(entity);
		case REMOVE_THIS_ITEM:
			SafelyRemoveEdict(entity);
	}
}

/**
 * Dishes out pills to the survivors
 *
 * @noreturn
 */
static GivePillsToSurvivors()
{
	DebugPrintToAllEx("Giving pills to survivors.");

	DebugLog("%s Pills autogiver is enable", HC_TAG);

	new iFlags = GetCommandFlags("give");

	SetCommandFlags("give", iFlags & ~FCVAR_CHEAT);

	for (new i = 1; i <= MaxClients; i++){

		if (IsClientInGame(i) && GetClientTeam(i) == 2 && GetPlayerWeaponSlot(i, 4) == -1){

			FakeClientCommand(i, "give pain_pills");
		}
	}

	SetCommandFlags("give", iFlags | FCVAR_CHEAT);
}

/**
 * Replaces medkit with pills unless the health style precludes it
 * @param entity the medkit entity to be considered for replacement
 * @noreturn
 */
static ReplaceKitWithPills(entity)
{
	new result = ReplaceEntity(entity, PAIN_PILLS_CLASSNAME, MODEL_PAIN_PILLS, 1);
	if (!result)
	{
		ThrowError("Failed to replace medkit with pills! Entity %i", entity);
	}
	DebugPrintToAllEx("Medkit (entity %i) replaced with pills (entity %i)", entity, result);
}

/**
 * Health style cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _HC_HealthStyle_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateOutSideStyleConVars();
}

public _HC_StartKitsStyle_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateStartKitsStyleConVars();
}

public _HC_FinaleKitsStyle_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateFinaleKitsStyleConVars();
}

public _HC_EndKitsStyle_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateEndKitsStyleConVars();
}

public _HC_GivePillsToSurv_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateGivePillsToSurvConVars();
}

public _HC_1v1WipePills_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update1v1WipePillsConVars();
}

public _HC_ItemTranslations_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateItemTranslationConVars();
}


static Update_HC_ConVars()
{
	UpdateOutSideStyleConVars();
	UpdateStartKitsStyleConVars();
	UpdateFinaleKitsStyleConVars();
	UpdateEndKitsStyleConVars();
	UpdateGivePillsToSurvConVars();
	Update1v1WipePillsConVars();
	UpdateItemTranslationConVars();
}

static UpdateOutSideStyleConVars()
{
	g_iCvarOSF_Style = GetConVarInt(g_hOSF_Style);

	static iVal;

	if (g_iCvarOSF_Style == LEAVE_THIS_ITEM) iVal = 0;
	else iVal = -1;

	SetDirectorSettings(g_hConvert[PILLS], iVal);
	SetDirectorSettings(g_hConvert[PILLS_VS], iVal);
}

static UpdateStartKitsStyleConVars()
{
	g_iCvarSSR_Style = GetConVarInt(g_hSSR_Style);
}

static UpdateFinaleKitsStyleConVars()
{
	g_iCvarFSR_Style = GetConVarInt(g_hFSR_Style);
}

static UpdateEndKitsStyleConVars()
{
	g_iCvarESR_Style = GetConVarInt(g_hESR_Style);
}

static UpdateGivePillsToSurvConVars()
{
	g_bCvarPills_Style = GetConVarBool(g_hPills_Style);
}

static Update1v1WipePillsConVars()
{
	g_iCvarWipePills = GetConVarInt(g_h1v1WipePills);
}

static UpdateItemTranslationConVars()
{
	g_bIsItemTranslations = GetConVarBool(g_hItemTranslations);
}

stock _HC_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hOSF_Style)) != g_iCvarOSF_Style)
		DebugLog("%d		|	%d		|	rotoblin_replace_outsidekits", iVal, g_iCvarOSF_Style);
	if ((iVal = GetConVarInt(g_hSSR_Style)) != g_iCvarSSR_Style)
		DebugLog("%d		|	%d		|	rotoblin_replace_startkits", iVal, g_iCvarSSR_Style);
	if ((iVal = GetConVarInt(g_hFSR_Style)) != g_iCvarFSR_Style)
		DebugLog("%d		|	%d		|	rotoblin_replace_finalekits", iVal, g_iCvarFSR_Style);
	if (bool:(iVal = GetConVarInt(g_hPills_Style)) != g_bCvarPills_Style)
		DebugLog("%d		|	%d		|	rotoblin_pills_autogiver", iVal, g_bCvarPills_Style);
	if ((iVal = GetConVarInt(g_h1v1WipePills)) != g_iCvarWipePills)
		DebugLog("%d		|	%d		|	rotoblin_1v1_wipe_pills", iVal, g_iCvarWipePills);
}

/**
 * Wrapper for printing a debug message without having to define channel index
 * everytime.
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
static DebugPrintToAllEx(const String:format[], any:...)
{
	decl String:buffer[DEBUG_MESSAGE_LENGTH];
	VFormat(buffer, sizeof(buffer), format, 2);
	DebugPrintToAll(g_iDebugChannel, buffer);
}