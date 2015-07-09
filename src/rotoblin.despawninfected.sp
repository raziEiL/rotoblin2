/*
 * ============================================================================
 *
 *  Original fixed Rotoblin module
 *
 *  File:			rotoblin.despawninfected.sp
 *  Type:			Module
 *  Description:	Despawn infected commons who is too far behind the
 *					survivors.
 * 	Credits:		SRSMod team for the original source for L4D2
 *					(http://code.google.com/p/srsmod/).
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
//       Private
// --------------------

#define DI_TAG		"[DespawnInfected]"

static	const	String:	CLASSNAME_INFECTED[]				= "infected";
static	const	String:	CLASSNAME_WITCH[]					= "witch";
static	const	String:	CLASSNAME_PHYSPROPS[]				= "prop_physics";

static	const	Float:	TRACE_TOLERANCE 					= 75.0;
static	const	Float:	COMMON_CHECK_INTERVAL 				= 1.0;
static	const	Float:	COMMON_RESPAWN_INTERVAL 			= 0.5;

static	const	Float:	DESPAWN_DISTANCE					= 700.0;
static	const	Float:	MIN_ADVANCE_DISTANCE				= 33.0;
static	const	Float:	MIN_COMMON_LIFETIME					= 15.0;
static 	const	Float:	NEAR_SAFEROOM_DISTANCE				= 1000.0;

static			Handle:	g_hCommonTimer						= INVALID_HANDLE;
static			Float:	g_fCommonLifetime[MAX_EDICTS+1]	= 0.0;
static					g_iCommonSpawnQueue					= 0;
static			Float:	g_fLastLowestSurvivorFlow			= 0.0;

static					g_iDebugChannel						= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]				= "DespawnInfected";

static Handle:g_hDIEnable, bool:g_bCvarDIEnabled, Float:g_fLastHighestFlow = -1.0;

#if DEBUG_COMMANDS
	static Handle:g_hDebugArray, Handle:g_hDebugArray2, bool:g_bRespawnedMob;
#endif
// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
_DespawnInfected_OnPluginStart()
{
	g_hDIEnable = CreateConVarEx("despawn_infected", "0", "If set, common infected will despawn if they are too far behind the survivors", _, true, 0.0, true, 1.0);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");

	#if DEBUG_COMMANDS
		RegConsoleCmd("sm_diwipemarkers", Command_WipeAllMarkers);
		g_hDebugArray = CreateArray(3);
		g_hDebugArray2 = CreateArray(3);
		CreateTimer(1.0, DI_t_DebugMarkers, _, TIMER_REPEAT);
	#endif
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
_DI_OnPluginEnabled()
{
	HookConVarChange(g_hDIEnable, DI_OnCvarChange_Enabled);
	Get_DI_Cvars();

	if (g_bLoadLater && g_bCvarDIEnabled)
		_DI_ToogleHook(true);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
_DI_OnPluginDisabled()
{
	UnhookConVarChange(g_hDIEnable, DI_OnCvarChange_Enabled);

	if (g_bCvarDIEnabled)
		_DI_ToogleHook(false);
}

/**
 * When an entity is created.
 *
 * @param entity		Entity index.
 * @param classname		Classname.
 * @noreturn
 */
_DI_OnEntityCreated(entity, const String:classname[])
{
	if (!g_bCvarDIEnabled || !StrEqual(classname, CLASSNAME_INFECTED, false)) return;
	g_fCommonLifetime[entity] = GetGameTime();

	#if DEBUG_COMMANDS
		if (!g_bRespawnedMob) return;
		CreateTimer(0.5, WI_t_DebugGetMobOrg, EntIndexToEntRef(entity));
	#endif
}

/**
 * When an entity is destroyed.
 *
 * @param entity		Entity index.
 * @noreturn
 */
_DI_OnEntityDestroyed(entity)
{
	if (!g_bCvarDIEnabled) return;
	g_fCommonLifetime[entity] = 0.0;
}

/**
 * Called when round start is fired.
 *
 * @param event			INVALID_HANDLE due to EventHookMode_PostNoCopy.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _DI_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	#if DEBUG_COMMANDS
		DI_ClearDebugArray();
	#endif
	g_fLastHighestFlow = 0.0;
	for (new i = MaxClients + 1; i <= MAX_EDICTS; i++) g_fCommonLifetime[i] = 0.0;
	DebugPrintToAllEx("Round start, resetting common life time");
}

/**
 * Called when check commons interval has elapsed.
 *
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop repeating, any other value for
 *						default behavior.
 */
public Action:_DI_Check_Timer(Handle:timer)
{
	if (!SurvivorCount || !IsServerProcessing()) return Plugin_Continue; // If no survivors or server is empty, return plugin_continue

	new Float:lastSurvivorFlow, Float:firstSurvivorFlow, Float:checkAgainst, bool:foundOne, firstSurvivor;

	for (new i = 0; i < SurvivorCount; i++)
	{
		checkAgainst = L4DDirect_GetFlowDistance(SurvivorIndex[i]);

		if (checkAgainst < lastSurvivorFlow || lastSurvivorFlow == 0.0)
		{
			lastSurvivorFlow = checkAgainst;
			foundOne = true;
		}

		if (checkAgainst > firstSurvivorFlow || firstSurvivorFlow == 0.0)
		{
			firstSurvivorFlow = checkAgainst;
			firstSurvivor = SurvivorIndex[i];
		}
	}

	if (!foundOne) return Plugin_Continue; // No valid survivors, return plugin_continue

	DebugPrintToAllEx("Found valid survivors, lowest flow %f, highest flow %f", lastSurvivorFlow, firstSurvivorFlow);

	DespawningCommons(lastSurvivorFlow, firstSurvivor);
	g_fLastLowestSurvivorFlow = lastSurvivorFlow;
	g_fLastHighestFlow = firstSurvivorFlow;

	Call_StartForward(g_hEventForwards[0]);
	Call_PushFloat(g_fLastLowestSurvivorFlow);
	Call_PushFloat(g_fLastHighestFlow);
	Call_Finish();

	return Plugin_Continue;
}

/**
 * Called when respawn commons interval has elapsed.
 *
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop repeating, any other value for
 *						default behavior.
 */
public Action:_DI_RespawnInfected_Timer(Handle:timer)
{
	if (g_iCommonSpawnQueue < 1) return Plugin_Stop; // only work if there is a respawn needed, kill timer if not

	if (!SurvivorCount) return Plugin_Continue;

	#if DEBUG_COMMANDS
		g_bRespawnedMob = true;
	#endif

	CheatCommandEx(SurvivorIndex[0], "z_spawn", "infected auto");
	g_iCommonSpawnQueue--;

	#if DEBUG_COMMANDS
		g_bRespawnedMob = false;
	#endif

	DebugPrintToAllEx("Respawned common. Commons left in queue %i", g_iCommonSpawnQueue);

	return Plugin_Continue;
}

/**
 * Called on entity filtering.
 *
 * @param entity		Entity index.
 * @param contentsMask	Contents Mask.
 * @return				True to allow the current entity to be hit, otherwise false.
 */
public bool:_DI_TraceFilter(entity, contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity)) return false;

	decl String:classname[128];
	GetEntityClassname(entity, classname, sizeof(classname)); // also not zombies or witches, as unlikely that may be, or physobjects (= windows)
	if (StrEqual(classname, CLASSNAME_INFECTED, false) ||
		StrEqual(classname, CLASSNAME_WITCH, false) ||
		StrEqual(classname, CLASSNAME_PHYSPROPS, false))
	{
		return false;
	}

	return true;
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Try despawn commons.
 *
 * @param lastSurvivorFlow	The survivor with lowest flow.
 * @param firstSurvivor	The survivor futherest ahead in the flow.
 * @noreturn
 */
static DespawningCommons(Float:lastSurvivorFlow, firstSurvivor)
{
	if (lastSurvivorFlow < DESPAWN_DISTANCE) return;

	new Float:flowDifference = (lastSurvivorFlow - g_fLastLowestSurvivorFlow);
	if (flowDifference < MIN_ADVANCE_DISTANCE)
	{
		DebugPrintToAllEx("Survivors haven't advanced enough, stop despawning. Difference from last check %f (min %f)", flowDifference, MIN_ADVANCE_DISTANCE);
		return;
	}

	if (IsNearEndSafeRoom(firstSurvivor))
	{
		DebugPrintToAllEx("Survivors are too close to the end saferoom, stop despawning");
		return;
	}

	decl Float:commonFlow;
	new entity = -1;

	while ((entity = FindEntityByClassname(entity, CLASSNAME_INFECTED)) != INVALID_ENT_REFERENCE)
	{
		if (g_fCommonLifetime[entity] == 0.0) continue;

		commonFlow = L4DDirect_GetFlowDistance(entity, true);
		if (commonFlow < 0) continue; // common is in a infected-only areas, continue

		if ((lastSurvivorFlow - DESPAWN_DISTANCE) <= commonFlow) continue; // common is close to the survivors, continue

		if ((GetGameTime() - g_fCommonLifetime[entity]) < MIN_COMMON_LIFETIME) continue; // common haven't been alive for enough time, continue

		if (IsVisibleToSurvivors(entity)) continue; // Common is visible to the survivors, continue

		#if DEBUG_COMMANDS
			decl Float:vOrg[3];
			GetEntityOrg(entity, vOrg);
			PushArrayArray(g_hDebugArray, vOrg);
		#endif

		// Remove common and add to respawn queue
		SafelyRemoveEdict(entity);

		if (g_iCommonSpawnQueue < 1)
		{
			CreateTimer(COMMON_RESPAWN_INTERVAL, _DI_RespawnInfected_Timer, _, TIMER_REPEAT);
		}
		g_iCommonSpawnQueue++;

		DebugPrintToAllEx("Despawned common %i and added to the respawn queue", entity);
	}
}

/**
 * Check to see if survivor is near end safe room.
 *
 * @param client		Client to check to be near saferoom.
 * @return				True if the client is close to the end saferoom.
 */
static bool:IsNearEndSafeRoom(client)
{
	decl Float:vEndSafeRoomOrg[3], Float:vOrg[3];

	GetClientAbsOrigin(client, vOrg);
	GetSafeRoomOrg(vEndSafeRoomOrg, false);

	return GetVectorDistance(vOrg, vEndSafeRoomOrg) < NEAR_SAFEROOM_DISTANCE;
}

/**
 * Check if common is visible to the survivors.
 *
 * @param entity		Common entity index.
 * @return				True if survivors can see this common, false otherwise.
 */
static bool:IsVisibleToSurvivors(entity) // loops alive Survivors and checks entity for being visible
{
	if (!SurvivorCount) return false; // No survivors alive, return

	for (new i = 0; i < SurvivorCount; i++)
	{
		if (IsVisibleTo(SurvivorIndex[i], entity)) return true;
	}

	return false;
}

/**
 * Check if common is visible to the survivor.
 *
 * @param client		Survivor client index.
 * @param entity		Common entity index.
 * @return				True if survivors can see this common, false otherwise.
 */
static bool:IsVisibleTo(client, entity) // check an entity for being visible to a client
{
	decl Float:vAngles[3], Float:vOrigin[3], Float:vEnt[3], Float:vLookAt[3];

	GetClientEyePosition(client,vOrigin); // get both player and zombie position
	GetEntityAbsOrigin(entity, vEnt);

	MakeVectorFromPoints(vOrigin, vEnt, vLookAt); // compute vector from player to zombie
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, _DI_TraceFilter);

	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true; // if trace ray lenght plus tolerance equal or bigger absolute distance, you hit the targeted zombie
		}
	}
	else
	{
		isVisible = true;
	}

	CloseHandle(trace);
	return isVisible;
}

#if DEBUG_COMMANDS
public Action:Command_WipeAllMarkers(client, args)
{
	DI_ClearDebugArray();
	ReplyToCommand(client, "%s Markers were removed.", DI_TAG);
	return Plugin_Handled;
}

DI_ClearDebugArray()
{
	ClearArray(g_hDebugArray);
	ClearArray(g_hDebugArray2);
}

public Action:DI_t_DebugMarkers(Handle:timer)
{
	new iArraySize = GetArraySize(g_hDebugArray);
	if (!iArraySize) return;

	decl Float:vOrg[3];
	for (new i; i < iArraySize; i++){

		GetArrayArray(g_hDebugArray, i, vOrg);
		TE_SetupBeamRingPoint(vOrg, 20.0, 22.0, GetLaserCaheIndex(), 0, 0, 1, 1.0, 1.0, 1.0, {255, 0, 0, 255}, 0, 0);
		TE_SendToAll();
	}

	iArraySize = GetArraySize(g_hDebugArray2);
	if (!iArraySize) return;

	for (new i; i < iArraySize; i++){

		GetArrayArray(g_hDebugArray2, i, vOrg);
		TE_SetupBeamRingPoint(vOrg, 20.0, 22.0, GetLaserCaheIndex(), 0, 0, 1, 1.0, 1.0, 1.0, {0, 255, 0, 255}, 0, 0);
		TE_SendToAll();
	}
}
public Action:WI_t_DebugGetMobOrg(Handle:timer, any:entity)
{
	if ((entity = EntRefToEntIndex(entity)) == INVALID_ENT_REFERENCE) return;

	decl Float:vOrg[3];
	GetEntityOrg(entity, vOrg);
	vOrg[2] += 5.0;
	//PrintToChatAll("%.1f %.1f %.1f", vOrg[0], vOrg[1], vOrg[2]);
	PushArrayArray(g_hDebugArray2, vOrg);
}
#endif

public Native_R2comp_GetHighestSurvivorFlowEx(Handle:plugin, numParams)
{
	return _:g_fLastHighestFlow;
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

				if ((iLastFlow = L4DDirect_GetFlowDistance(i)) > fFlow)
					fFlow = iLastFlow;
			}
		}
	}
	else if (SurvivorCount){

		for (new i = 0; i < SurvivorCount; i++){

			if (bDown && (IsIncapacitated(SurvivorIndex[i]) || IsHandingFromLedge(SurvivorIndex[i]))) continue;

			if ((iLastFlow = L4DDirect_GetFlowDistance(SurvivorIndex[i])) > fFlow)
				fFlow = iLastFlow;
		}
	}

	return fFlow;
}

_DI_ToogleHook(bool:bHook)
{
	if (bHook){

		g_fLastHighestFlow = 0.0;
		for (new i = MaxClients + 1; i <= MAX_EDICTS; i++) g_fCommonLifetime[i] = 0.0;

		g_hCommonTimer = CreateTimer(COMMON_CHECK_INTERVAL, _DI_Check_Timer, _, TIMER_REPEAT);

		HookEvent("round_start", _DI_RoundStart_Event, EventHookMode_PostNoCopy);
		DebugPrintToAllEx("Module is now loaded");
		DebugLog("%s ENABLED", DI_TAG);
	}
	else {
		g_fLastHighestFlow = -1.0;
		CloseHandle(g_hCommonTimer);

		UnhookEvent("round_start", _DI_RoundStart_Event, EventHookMode_PostNoCopy);
		DebugPrintToAllEx("Module is now unloaded");
		DebugLog("%s DISABLED", DI_TAG);
	}
}

public DI_OnCvarChange_Enabled(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (StrEqual(sOldVal, sNewVal)) return;
	Get_DI_Cvars();

	_DI_ToogleHook(g_bCvarDIEnabled);
}

static Get_DI_Cvars()
{
	g_bCvarDIEnabled = GetConVarBool(g_hDIEnable);
}

bool:IsDIModuleEnabled()
{
	return g_bCvarDIEnabled;
}

stock _DI_CvarDump()
{
	decl bool:iVal;
	if ((iVal = GetConVarBool(g_hDIEnable)) != g_bCvarDIEnabled)
		DebugLog("%d		|	%d		|	rotoblin_despawn_infected", iVal, g_bCvarDIEnabled);
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