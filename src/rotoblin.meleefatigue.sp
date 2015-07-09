/*
 * ============================================================================
 *
 *  File:			rotoblin.meleefatigue.sp
 *  Type:			Module
 *  Description:	Allows users to mess with how quickly melee fatigue kicks in.
 *
 *					The way this works is kinda finicky.  Instead of being able to control the
 *					number of melees performed before fatigue kicks in, all you can really do
 *					is add (or .. not add!) to the shove penalty count for the particular client who
 *					is meleeing.
 *
 *					The penalty count is an integer that is usually in the range of 0 to 6 (inclusive).
 *
 *					Each 'standard' (as in, unmodded) melee adds one to the penalty count when
 *					cooloff period has not been obeyed.  The cooloff period exists to stop people
 *					melee spamming; if you wait ages between melees, then your penalty count will
 *					never climb above 1.
 *
 *					When the penalty reaches 4, the melee succeeds, but fatigue begins, causing the
 * 					time between each successive melee to increase.  Meleeing when already fatigued
 *					(possible when penalty is 4 and 5) will increase penalty up to a maximum of 6.
 * 					The cooldown period markedly increases with each melee when fatigued.
 *
 *					While we could do more fancy stuff to have our own non-standard cooldown stuff,
 *					it would probably involve the client being unable to predict/sync properly
 *
 *	Credits/Based on:	http://forums.alliedmods.net/showthread.php?t=138496 (AtomicStryker)
 *
 *  Copyright (C) 2012-2015  raziEiL <war4291@mail.ru>
 *  Copyright (C) 2010  Defrag <mjsimpson@gmail.com>
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

/**
 * How much of a shove penalty will be added if a client melees when not fatigued.
 * If you _are_ fatigued (you can tell when you're fatigued, as meleeing causes the
 * "I'm bloody knackered, mate" icon to appear), then the game will just add the
 * standard count of 1 to your shove penalty, capped at a maximum of maximum of 6.
 *
 * I.e. this setting only has an effect until you're fatigued, at which point the
 * standard code takes over.
 */
static g_nonFatiguedMeleePenalty;
static Handle:g_hNonFatiguedMeleePenalty_CVAR	= INVALID_HANDLE;

// shove penalty on a client before we stop adding to it and just let the game take over.
static const MAX_EXISTING_FATIGUE					= 3;

static const Float:MELEE_DURATION					= 0.6;

static bool:soundHookDelay[MAXPLAYERS+1];
static bool:g_bKeepPenalty[MAXPLAYERS+1];
static			g_iDebugChannel						= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]	= "MeleeFatigue";

#define			MELEE_SOUND							"Swish"

static Handle:g_hCvarMeleeControlFlags, Handle:g_hCvarNoDeadStop, Handle:g_hPouncing[MAXPLAYERS+1], g_iCvarMeleeControlFlags, bool:g_bCvarNoDeadStop;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
_MeleeFatigue_OnPluginStart()
{
	g_hNonFatiguedMeleePenalty_CVAR = CreateConVarEx("melee_penalty", "0", "Sets the Shove penalty for each non-fatigued melee swipe", _, true, 0.0, true, 4.0);
	g_hCvarMeleeControlFlags = CreateConVarEx("melee_flags", "0", "Blocks melee effect on infected. Flag (add together): 0=Disable, 2=Smoker, 4=Boomer, 8=Hunter, 16=CI, 30=all", _, true, 0.0, true, 30.0);
	g_hCvarNoDeadStop = CreateConVarEx("melee_deadstop", "0", "Blocks deadstop feature", _, true, 0.0, true, 1.0);

	AddConVarToReport(g_hNonFatiguedMeleePenalty_CVAR); // Add to report status module
	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup.", g_iDebugChannel);
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
_MF_OnPluginEnabled()
{
	HookEvent("ability_use", _MF_ev_AbilityUse);

	AddNormalSoundHook(_MF_sh_OnSoundEmitted);

	HookConVarChange(g_hNonFatiguedMeleePenalty_CVAR, _MF_OnCvarChange_MeleePenalty);
	HookConVarChange(g_hCvarMeleeControlFlags, _MF_OnCvarChange_MeleeControl);
	HookConVarChange(g_hCvarNoDeadStop, _MF_OnCvarChange_NoDeadStop);

	UpdateNonFatiguedMeleePenalty();
	UpdateMeleeControlFlags();
	UpdateNoDeadStop();

	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
_MF_OnPluginDisabled()
{
	UnhookEvent("ability_use", _MF_ev_AbilityUse);

	RemoveNormalSoundHook(_MF_sh_OnSoundEmitted);

	UnhookConVarChange(g_hNonFatiguedMeleePenalty_CVAR, _MF_OnCvarChange_MeleePenalty);
	UnhookConVarChange(g_hCvarMeleeControlFlags, _MF_OnCvarChange_MeleeControl);
	UnhookConVarChange(g_hCvarNoDeadStop, _MF_OnCvarChange_NoDeadStop);

	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
 public _MF_OnCvarChange_MeleePenalty(Handle:convar, const String:oldValue[], const String:newValue[])
{
	DebugPrintToAllEx("melee penalty changed. Old value %s, new value %s", oldValue, newValue);
	UpdateNonFatiguedMeleePenalty();
}

public _MF_OnCvarChange_MeleeControl(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UpdateMeleeControlFlags();
}

public _MF_OnCvarChange_NoDeadStop(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UpdateNoDeadStop();
}

/**
 * callback function for a sound being played.  Used to determine whether a survivor
 * is meleeing, then to modify the shove penalty (if applicable).
 *
 * @param Clients		unused
 * @param NumClients	unused
 * @param StrSample		A string containing the name of the played sound sample
 * @param Entity		The entity that triggered the sound.
 * @returns				event status
 */
public Action:_MF_sh_OnSoundEmitted(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	// Only execute if appropriate.

	// Note: This is potentially wasteful, as the callback will be getting fired for each sound
	// even if the melee penalty is set to 1 (the default).  It may be better to hook/unhook the
	// callback when the feature is enabled/disabled, but let's keep it simple for now.
	if (!ShouldPerformCustomFatigueLogic(sample, entity))
		return Plugin_Continue;

	// the player just started to shove
	soundHookDelay[entity] = true;
	CreateTimer(MELEE_DURATION, ResetsoundHookDelay, entity);

	// we need to subtract 1 from the current shove penalty prior to applying
	// our own as the game has already incremented the shove penalty before we got hold of it.
	new shovePenalty = L4D_GetMeleeFatigue(entity) - 1;

	if(shovePenalty < 0)
		shovePenalty = 0;

	DebugPrintToAllEx("Current shove penalty: %i", shovePenalty);

	if (shovePenalty >= MAX_EXISTING_FATIGUE)
	{
		DebugPrintToAllEx("Current shove penalty is %i, aborting", shovePenalty);
		return Plugin_Continue;
	}

	switch (g_nonFatiguedMeleePenalty){

		case 1:
			shovePenalty += 4;
		case 2:
			shovePenalty += (shovePenalty < 1 ? 1 : 3);
		case 3:
			shovePenalty += (shovePenalty < 2 ? 1 : 3);
		case 4:
		{
			shovePenalty += 1;

			if (shovePenalty == 3){

				if (!g_bKeepPenalty[entity]){

					g_bKeepPenalty[entity] = true;
					shovePenalty--;
				}
				else {

					g_bKeepPenalty[entity] = false;
					shovePenalty = 4;
				}
			}
			else
				g_bKeepPenalty[entity] = false;
		}
	}

	if (shovePenalty > 4)
		shovePenalty = 4;

	L4D_SetMeleeFatigue(entity, shovePenalty);
	DebugPrintToAllEx("Set shove penalty to %i", shovePenalty);

	return Plugin_Continue;
}

public _MF_ev_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bCvarNoDeadStop) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_hPouncing[client] == INVALID_HANDLE){

		decl String:sAbility[64];
		GetEventString(event, "ability", sAbility, 64);

		if (StrEqual(sAbility, "ability_lunge"))
			g_hPouncing[client] = CreateTimer(0.3, _MF_t_GroundTouchCheck, client, TIMER_REPEAT);
	}
}

public Action:_MF_t_GroundTouchCheck(Handle:timer, any:client)
{
	if (IsClientInGame(client)){

		if (!(GetEntityFlags(client) & FL_ONGROUND || !IsInfectedAlive(client)))
			return Plugin_Continue;
	}

	g_hPouncing[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

public Action:L4D_OnEntityShoved(client, entity, weapon, const Float:vector[3])
{
	if ((g_iCvarMeleeControlFlags || g_bCvarNoDeadStop) && IsClient(client) && IsSurvivor(client)){

		if (IsClient(entity) && IsInfected(entity)){

			new iClass = GetPlayerClass(entity);

			if (iClass == ZC_HUNTER && g_hPouncing[entity] != INVALID_HANDLE){

				if (g_bCvarNoDeadStop){

					KillTimer(g_hPouncing[entity]);
					g_hPouncing[entity] = CreateTimer(0.2, _MF_t_GroundTouchCheck, entity, TIMER_REPEAT);

					return Plugin_Handled;
				}
				return Plugin_Continue;
			}

			if (g_iCvarMeleeControlFlags & (1 << iClass))
				return Plugin_Handled;
		}
		else if (g_iCvarMeleeControlFlags & (1 << ZC_UNKNOWN) && IsCommonInfected(entity))
			return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:L4D_OnShovedBySurvivor(client, victim, const Float:vector[3])
{
	if (g_bCvarNoDeadStop && g_hPouncing[victim] != INVALID_HANDLE && GetClientTeam(victim) == 3 && GetPlayerClass(victim) == ZC_HUNTER)
		return Plugin_Handled;

	return Plugin_Continue;
}

// **********************************************
//                 Private API
// **********************************************

static L4D_GetMeleeFatigue(client)
{
    return GetEntProp(client, Prop_Send, "m_iShovePenalty");
}

static L4D_SetMeleeFatigue(client, value)
{
    SetEntProp(client, Prop_Send, "m_iShovePenalty", value);
}

public Action:ResetsoundHookDelay(Handle:timer, any:client)
{
    soundHookDelay[client] = false;
}

static bool:ShouldPerformCustomFatigueLogic(const String:StrSample[PLATFORM_MAX_PATH], entity)
{
	return g_nonFatiguedMeleePenalty && IsClient(entity) && !soundHookDelay[entity] && StrContains(StrSample, MELEE_SOUND, false) != -1;
}

static UpdateNonFatiguedMeleePenalty()
{
	g_nonFatiguedMeleePenalty = GetConVarInt(g_hNonFatiguedMeleePenalty_CVAR);

	DebugPrintToAllEx("Updated non fatigued melee penalty global var; %d", g_nonFatiguedMeleePenalty);
}

static UpdateMeleeControlFlags()
{
	g_iCvarMeleeControlFlags = GetConVarInt(g_hCvarMeleeControlFlags);
}

static UpdateNoDeadStop()
{
	g_bCvarNoDeadStop = GetConVarBool(g_hCvarNoDeadStop);
}

stock _MF_CvarDump()
{
	decl iVal;
	if ((iVal = GetConVarInt(g_hNonFatiguedMeleePenalty_CVAR)) != g_nonFatiguedMeleePenalty)
		DebugLog("%d		|	%d		|	rotoblin_melee_penalty", iVal, g_nonFatiguedMeleePenalty);
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