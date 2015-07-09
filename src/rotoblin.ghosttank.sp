/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.ghosttank.sp
 *  Type:			Module
 *  Description:	Handles the tank. Prevents prelights with more.
 *	Credits:		DrThunder on AlliedModders.com, for punch fix. Stabby for hittable control.
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
static 	const	String:	SELECTION_TIME_CVAR[]				= "director_tank_lottery_selection_time";

static	const	Float:	FIRE_IMMUNITY_TIME					= 5.0;			// How long the tank is fire immune after a player gains control.
static	const			INCAP_HEALTH						= 300;			// Punch fix, incap health
static	const	Float:	INCAP_DELAY							= 0.4;			// Punch fix, how long before incaping the survivor again
static	const	String:	INCAP_WEAPON[]						= "tank_claw";	// Punch fix, which weapon used to incap the survivor before applying punch fix

static			Handle:	g_hSelectionTimeCvar				= INVALID_HANDLE;

static	const	String:	WEAPON_TANK_ROCK[]					= "tank_rock";	// Tank rock weapon name
static	const	Float:	BLOCK_USE_TIME						= 1.5;			// After a survivor have been "rock'd", how long is use blocked
static			bool:	g_bBlockUse[MAXPLAYERS +1]			= {false};
static			Handle:	g_hBlockUse_Timer[MAXPLAYERS +1]	= {INVALID_HANDLE};

static			bool:	g_bIsTankFireImmune;								// Boolean for fire immunity

static					g_iDebugChannel							= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]					= "GhostTank";

static		Handle:g_hTankBoss, Handle:g_hNoPropDmg, Handle:g_hHittableDmg, Float:OVERHIT_TIME = 1.2, g_bOverHit[MAXPLAYERS+1];

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
_GhostTank_OnPluginStart()
{
	g_hTankBoss		=	CreateConVarEx("tank_boss", "0", "Tank can't be prelight, punch fix", _, true, 0.0, true, 1.0);
	g_hNoPropDmg		=	CreateConVarEx("tank_noprop_dmg", "0", "All hittable props won't deal any damage to the Tank", _, true, 0.0, true, 1.0);
	g_hHittableDmg	=	CreateConVarEx("tank_hittable_control", "0", "All hittable props deal static damage to surviors (100 damage hittable with glow, 25 other). [CODE HAS NOT BEEN COMPLETED. DON'T USE IT!]", _, true, 0.0, true, 1.0);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
_GT_OnPluginEnabled()
{
	g_hSelectionTimeCvar	= FindConVar(SELECTION_TIME_CVAR);

	HookEvent("round_start" , 			_GT_RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_hurt" , 			_GT_PlayerHurt_Event);
	HookEvent("player_incapacitated", 	_GT_PlayerIncap_Event);
	HookEvent("spawned_as_tank",			_GT_ev_SpawnedAsTank);

	g_bIsTankFireImmune = false;

	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
_GT_OnPluginDisabled()
{
	g_hSelectionTimeCvar	= INVALID_HANDLE;

	UnhookEvent("round_start",			_GT_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookEvent("player_hurt",			_GT_PlayerHurt_Event);
	UnhookEvent("player_incapacitated",	_GT_PlayerIncap_Event);
	UnhookEvent("spawned_as_tank",		_GT_ev_SpawnedAsTank);

	_GT_ToogleHittableHook(false);

	DebugPrintToAllEx("Module is now unloaded");
}

_GT_OnClientPutInServer(client)
{
	if (GetConVarBool(g_hHittableDmg) && IsTankInPlay())
		SDKHook(client, SDKHook_OnTakeDamage, _GT_SDKh_OnHittableDamage);
}

/**
 * Called when round start event is fired.
 *
 * @param event			INVALID_HANDLE, post no copy data.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _GT_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	_GT_ToogleHittableHook(false);
	DebugPrintToAllEx("Round start");
	g_bIsTankFireImmune = false;
}

/**
 * Called when tank is spawned.
 *
 * @noreturn
 */
_GT_L4D_OnSpawnTank()
{
	_GT_ToogleHittableHook(true);

	if (!GetConVarBool(g_hTankBoss)) return;

	g_bIsTankFireImmune = true;
	new Float:fFireImmunityTime = FIRE_IMMUNITY_TIME + GetConVarFloat(g_hSelectionTimeCvar);
	CreateTimer(fFireImmunityTime, _GT_FireImmunity_Timer); // Create fire immunity timer
	DebugPrintToAllEx("OnSpawnTank() -> fire immunity timer %f", fFireImmunityTime);
}

public _GT_ev_SpawnedAsTank(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client) return;

	if (GetConVarBool(g_hTankBoss) && g_bIsTankFireImmune && !IsFakeClient(client)){

		DebugPrintToAllEx("SpawnAsTank (%N) -> SDKHook_OnTakeDamagePost", client);
		SDKHook(client, SDKHook_OnTakeDamagePost, _GT_SDKh_OnTakeDamagePost);
	}

	if (GetConVarBool(g_hNoPropDmg)){

		DebugPrintToAllEx("SpawnAsTank (%N) -> SDKHook_OnTakeDamage", client);
		SDKHook(client, SDKHook_OnTakeDamage, _GT_SDKh_OnTakeDamage);
	}
}

public _GT_SDKh_OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (g_bIsTankFireImmune && IsValidClient(victim)){

		if (IsClientOnFire(victim)){

			decl String:sHealth[12];
			IntToString((GetClientHealth(victim) + RoundFloat(damage)), sHealth, 12);
			SetVariantString(sHealth);

			AcceptEntityInput(victim, "SetHealth");
			ExtinguishEntity(victim);

			DebugPrintToAllEx("Tank was burned while being fire immune, health restored and fire put out");
		}
	}
	else{

		DebugPrintToAllEx("OnTakeDamagePost -> Unhook");
		SDKUnhook(victim, SDKHook_OnTakeDamagePost, _GT_SDKh_OnTakeDamagePost);
	}
}

public Action:_GT_SDKh_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (IsValidClient(victim)){

		if (damage > 0 && damagetype & DMG_CRUSH && victim == attacker){

			DebugPrintToAllEx("OnTakeDamage -> block hittable prop dmg");
			return Plugin_Handled;
		}
	}
	else {

		DebugPrintToAllEx("OnTakeDamage -> Unhook");
		SDKUnhook(victim, SDKHook_OnTakeDamage, _GT_SDKh_OnTakeDamage);
	}
	return Plugin_Continue;
}

public Action:_GT_SDKh_OnHittableDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (damage > 0 && damagetype & DMG_CRUSH && IsValidEntity(inflictor) && IsClientAndInGame(victim) && GetClientTeam(victim) == 2 && IsValidClient(attacker)){

		decl String:sClassName[64];
		GetEntityClassname(inflictor, sClassName, 64);

		if (StrEqual(sClassName, "prop_physics") || StrEqual(sClassName, "prop_car_alarm")){

			if (g_bOverHit[victim])
				return Plugin_Handled;

			g_bOverHit[victim] = true;
			CreateTimer(OVERHIT_TIME, _GT_t_OverHitEnd, victim);

			if (GetEntProp(inflictor, Prop_Send, "m_hasTankGlow"))
				damage = 100.0;
			else
				damage = 25.0;

			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

static bool:IsValidClient(client)
{
	return IsClientAndInGame(client) && GetClientTeam(client) == 3 && IsPlayerTank(client);
}

public Action:_GT_t_OverHitEnd(Handle:timer, any:client)
{
	g_bOverHit[client] = false;
}

_GT_ToogleHittableHook(bool:bHook)
{
	if (!GetConVarBool(g_hHittableDmg)) return;

	for (new client = 1; client <= MaxClients; client++){

		if (!IsClientInGame(client)) continue;

		if (bHook)
			SDKHook(client, SDKHook_OnTakeDamage, _GT_SDKh_OnHittableDamage);
		else
			SDKUnhook(client, SDKHook_OnTakeDamage, _GT_SDKh_OnHittableDamage);
	}
}

/**
 * Called when tank is killed.
 *
 * @noreturn
 */
_GT_ev_OnTankKilled()
{
	_GT_ToogleHittableHook(false);
	g_bIsTankFireImmune = false;
	DebugPrintToAllEx("Tank killed");
}

/**
 * Called when a player is hurt.
 *
 * @param event			Handle to event.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _GT_PlayerHurt_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!IsTankInPlay() || !GetConVarBool(g_hTankBoss)) return; // If the tank isn't in play, return

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client) return;

	if (GetClientTeam(client) == TEAM_SURVIVOR)
	{
		decl String:weapon[32];
		GetEventString(event, "weapon", weapon, sizeof(weapon));
		if (!StrEqual(weapon, WEAPON_TANK_ROCK)) return; // If the weapon that hurt the survivor isn't a rock from tank, return

		if (g_hBlockUse_Timer[client] != INVALID_HANDLE)
		{
			CloseHandle(g_hBlockUse_Timer[client]);
		}
		g_hBlockUse_Timer[client] = CreateTimer(BLOCK_USE_TIME, _GT_BlockUse_Timer, client);
		g_bBlockUse[client] = true;
		DebugPrintToAllEx("Survivor client %i: \"%N\" took a rock and can't use for %f", client, client, BLOCK_USE_TIME);
	}
}

/**
 * Called when a player gets incapacitated.
 *
 * @param event			Handle to event.
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _GT_PlayerIncap_Event(Handle:event, String:event_name[], bool:dontBroadcast)
{
	if (!IsTankInPlay() || !GetConVarBool(g_hTankBoss)) return; // If the tank isn't in play, return

	decl String:weapon[16];
	GetEventString(event, "weapon", weapon, 16); // Get the weapon used to incap the survivor
	if (!StrEqual(weapon, INCAP_WEAPON)) return; // If tank incap'd the survivor

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);			// Unincap the survivor
	SetEntityHealth(client, 1);										// Set his health to 1
	CreateTimer(INCAP_DELAY, _GT_PlayerIncap_Timer, client);		// Create timer to reincap him
	DebugPrintToAllEx("Client %i: \"%N\" have been tank punch upon being incap'd", client, client);
}

/**
 * Called when a clients movement buttons are being processed.
 *
 * @param client		Index of the client.
 * @param buttons		Copyback buffer containing the current commands (as bitflags - see entity_prop_stocks.inc).
 * @param impulse		Copyback buffer containing the current impulse command.
 * @param vel			Players desired velocity.
 * @param angles		Players desired view angles.
 * @param weapon		Entity index of the new weapon if player switches weapon, 0 otherwise.
 * @noreturn
 */
public _GT_OnPlayerRunCmdTwo(client, &buttons)
{
	if (g_bBlockUse[client] && buttons & IN_USE)
	{
		DebugPrintToAllEx("Client %i: \"%N\" tried to use while being prohibit", client, client);
		return true;
	}
	return false;
}

/**
 * Called when the fire immunity timer interval has elapsed.
 *
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_GT_FireImmunity_Timer(Handle:timer)
{
	g_bIsTankFireImmune = false; // Tank is no longer fire immune
	DebugPrintToAllEx("Tank is no longer fire immune");
}

/**
 * Called when the block use timer interval has elapsed.
 *
 * @param timer			Handle to the timer object.
 * @param client		Client index.
 * @noreturn
 */
public Action:_GT_BlockUse_Timer(Handle:timer, any:client)
{
	g_bBlockUse[client] = false;
	g_hBlockUse_Timer[client] = INVALID_HANDLE;
}

/**
 * Called when the player incap timer interval has elapsed.
 *
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_GT_PlayerIncap_Timer(Handle:timer, any:client)
{
	if (!IsClientInGame(client)) return;

	SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);	// Incap survivor
	SetEntityHealth(client, INCAP_HEALTH);					// Reset health
}

// **********************************************
//                 Private API
// **********************************************

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