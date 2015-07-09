/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.pause.sp
 *  Type:			Module
 *  Description:	Allows players to pause the game, or admins force pause.
 *	Credits:		pvtschlag at alliedmodders for [L4D2] Pause plugin. 
 *					"Loosely" stolen.
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

static	const	String:	PAUSABLE_CVAR[]				= "sv_pausable";

static	const	String:	PLUGIN_PAUSE_COMMAND[]		= "fpause";
static	const	String:	PLUGIN_UNPAUSE_COMMAND[]	= "funpause";
static	const	String:	PLUGIN_FORCEPAUSE_COMMAND[]	= "forcepause";
static	const	String:	PAUSE_COMMAND[]				= "pause";
static	const	String:	SETPAUSE_COMMAND[]			= "setpause";
static	const	String:	UNPAUSE_COMMAND[]			= "unpause";

static	const	Float:	RESET_PAUSE_REQUESTS_TIME	= 30.0;

static			Handle:	g_hPauseEnable_Cvar			= INVALID_HANDLE;
static			bool:	g_bIsPauseEnable;

static			Handle: g_hPausable					= INVALID_HANDLE;
static			bool:	g_bIsPausable				= false;
static			bool:	g_bIsUnpausable				= false;
static			bool:	g_bIsPaused					= false;
static			bool:	g_bIsUnpausing				= false;
static			bool:	g_bWasForced				= false;
static			bool:	g_bPauseRequest[2]			= {false};


static		Handle:g_hPauseDuration, bool:g_bLocked;

// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is loading.
 *
 * @noreturn
 */
_Pause_OnPluginStart()
{
	g_hPauseEnable_Cvar	=	CreateConVarEx("pause_allowed", "0", "Sets whether the game can be paused by players", _, true, 0.0, true, 1.0);
	g_hPauseDuration 		=	CreateConVarEx("pause_duration", "0", "Sets the duration before the game can be unpaused by a either team", _, true, 0.0);

	AddConVarToReport(g_hPauseEnable_Cvar); // Add to report status module
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
_P_OnPluginEnabled()
{
	g_hPausable = FindConVar(PAUSABLE_CVAR);

	g_bIsPausable = false;
	g_bIsUnpausable = false;
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;
	ResetPauseRequests();

	g_bIsPauseEnable = GetConVarBool(g_hPauseEnable_Cvar);
	HookConVarChange(g_hPauseEnable_Cvar, _P_PauseEnable_CvarChange);

	if (g_bIsPauseEnable)
		_P_TooglePauseMode(true);
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
_P_OnPluginDisabled()
{
	g_bIsPausable = false;
	g_bIsUnpausable = false;
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;

	g_hPausable = INVALID_HANDLE;

	UnhookConVarChange(g_hPauseEnable_Cvar, _P_PauseEnable_CvarChange);

	_P_TooglePauseMode(false);
}

static bool:g_bListened;

_P_TooglePauseMode(bool:bHookPause)
{
	if (!g_bListened && bHookPause){
	
		g_bListened = true;
		SetConVarInt(g_hPausable, 0); // Disable pausing
		AddCommandListenerEx(_P_RotoblinPause_Command, PLUGIN_PAUSE_COMMAND);
		AddCommandListenerEx(_P_RotoblinUnpause_Command, PLUGIN_UNPAUSE_COMMAND);
		AddCommandListenerEx(_P_RotoblinForcePause_Command, PLUGIN_FORCEPAUSE_COMMAND);
		AddCommandListener(_P_Pause_Command, PAUSE_COMMAND);
		AddCommandListener(_P_Setpause_Command, SETPAUSE_COMMAND);
		AddCommandListener(_P_Unpause_Command, UNPAUSE_COMMAND);
		AddCommandListener(_P_Say_Command, "say");
		AddCommandListener(_P_SayTeam_Command, "say_team");
	}
	else if (g_bListened && !bHookPause){
	
		g_bListened = false;
		RemoveCommandListenerEx(_P_RotoblinPause_Command, PLUGIN_PAUSE_COMMAND);
		RemoveCommandListenerEx(_P_RotoblinUnpause_Command, PLUGIN_UNPAUSE_COMMAND);
		RemoveCommandListenerEx(_P_RotoblinForcePause_Command, PLUGIN_FORCEPAUSE_COMMAND);
		RemoveCommandListener(_P_Pause_Command, PAUSE_COMMAND);
		RemoveCommandListener(_P_Setpause_Command, SETPAUSE_COMMAND);
		RemoveCommandListener(_P_Unpause_Command, UNPAUSE_COMMAND);
		RemoveCommandListener(_P_Say_Command, "say");
		RemoveCommandListener(_P_SayTeam_Command, "say_team");
	}
}

/**
 * On map end.
 *
 * @noreturn
 */
_P_OnMapEnd()
{
	g_bLocked = false;
	g_bIsPausable = false;
	g_bIsUnpausable = false;
	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bWasForced = false;
	ResetPauseRequests();
}

/**
 * Pause enable cvar changed.
 *
 * @param convar		Handle to the convar that was changed.
 * @param oldValue		String containing the value of the convar before it was changed.
 * @param newValue		String containing the new value of the convar.
 * @noreturn
 */
public _P_PauseEnable_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_bIsPauseEnable = GetConVarBool(g_hPauseEnable_Cvar);

	if (g_bIsPauseEnable)
		_P_TooglePauseMode(true);
	else
		_P_TooglePauseMode(false);
}

/**
 * On client use say command.
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_Say_Command(client, const String:command[], args)
{
	if (!g_bIsPaused) return Plugin_Continue;

	decl String:buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (IsSayCommandPrivate(buffer)) return Plugin_Continue; // If its a private chat trigger, return continue

	PrintToChatAll("\x03%N\x01 : %s", client, buffer);

	return Plugin_Handled;
}

/**
 * On client use say team command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_SayTeam_Command(client, const String:command[], args)
{
	if (!g_bIsPaused) return Plugin_Continue;

	decl String:buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (IsSayCommandPrivate(buffer)) return Plugin_Continue; // If its a private chat trigger, return continue

	new teamIndex = GetClientTeam(client);
	decl String:teamName[16];
	GetTeamNameEx(teamIndex, false, teamName, sizeof(teamName));

	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != teamIndex) continue;
		PrintToChat(i, "\x01(%s) \x03%N\x01 : %s", teamName, client, buffer);
	}

	return Plugin_Handled;
}

/**
 * On client use pause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_Pause_Command(client, const String:command[], args)
{
	return Plugin_Handled; // Block & ignore the pause command completely
}

/**
 * On client use set pause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_Setpause_Command(client, const String:command[], args)
{
	if (!g_bIsPausable) return Plugin_Handled;

	g_bIsPaused = true;
	g_bIsUnpausing = false;
	g_bIsPausable = false;
	return Plugin_Continue;
}

/**
 * On client use unpause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_Unpause_Command(client, const String:command[], args)
{
	if (!g_bIsUnpausable) return Plugin_Handled;

	g_bIsPaused = false;
	g_bIsUnpausing = false;
	g_bIsUnpausable = false;
	ResetPauseRequests();
	return Plugin_Continue;
}

/**
 * On client use rotoblins pause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_RotoblinPause_Command(client, const String:command[], args)
{
	if (client == SERVER_INDEX) return Plugin_Handled;

	if (g_bIsPaused) // Already paused, tell them how to unpause
	{
		PrintToChat(client, "[%s] Game is already paused. Use !%s to resume the game.", PLUGIN_TAG, PLUGIN_UNPAUSE_COMMAND);
		return Plugin_Handled;
	}
	new teamIndex = GetClientTeam(client);
	if (teamIndex != TEAM_SURVIVOR && teamIndex != TEAM_INFECTED)
	{
		PrintToChat(client, "[%s] Only ingame players can pause the game", PLUGIN_TAG);
		return Plugin_Handled;
	}

	if (g_bPauseRequest[GetOppositeTeamIndex(teamIndex) - 2])
	{
		PrintToChatAll("[%s] Both teams have agreed to pause. Use !%s to resume the game.", PLUGIN_TAG, PLUGIN_UNPAUSE_COMMAND);
		Pause(client);

		if (GetConVarInt(g_hPauseDuration)){

			g_bLocked = true;
			CreateTimer(GetConVarFloat(g_hPauseDuration), _P_t_Duration, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else if (!g_bPauseRequest[teamIndex - 2])
	{
		g_bPauseRequest[teamIndex - 2] = true;

		decl String:teamName[20], String:oppositeTeamName[20];
		GetTeamNameEx(teamIndex, true, teamName, sizeof(teamName));
		GetTeamNameEx(GetOppositeTeamIndex(teamIndex), true, oppositeTeamName, sizeof(oppositeTeamName));

		PrintToChatAll("[%s] The %s have requested a pause. The %s must accept with the !%s command.", PLUGIN_TAG, teamName, oppositeTeamName, PLUGIN_PAUSE_COMMAND);

		CreateTimer(RESET_PAUSE_REQUESTS_TIME, _P_ResetPauseRequests_Timer, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	return Plugin_Handled;
}

public Action:_P_t_Duration(Handle:timer)
{
	g_bLocked = false;
}

/**
 * On client use rotoblins unpause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_RotoblinUnpause_Command(client, const String:command[], args)
{
	if (client == SERVER_INDEX || !g_bIsPaused) return Plugin_Handled;

	if (g_bWasForced) // An admin forced the game to pause so only an admin can unpause it
	{
		g_bLocked = false;
		PrintToChat(client, "[%s] The game was paused by an admin and can only be unpaused with !%s.", PLUGIN_TAG, PLUGIN_FORCEPAUSE_COMMAND);
		return Plugin_Handled;
	}

	new teamIndex = GetClientTeam(client);

	if (teamIndex != TEAM_SURVIVOR && teamIndex != TEAM_INFECTED)
	{
		PrintToChat(client, "[%s] The game cannot be unpaused by spectators.", PLUGIN_TAG);
		return Plugin_Handled;
	}

	if (g_bLocked){

		PrintToChatAll("[%s] You should wait %d sec. before either team can unpause.", PLUGIN_TAG, GetConVarInt(g_hPauseDuration));
		return Plugin_Handled;
	}

	decl String:teamName[16];
	GetTeamNameEx(teamIndex, true, teamName, sizeof(teamName));

	PrintToChatAll("[%s] The %s unpaused the game.", PLUGIN_TAG, teamName);
	g_bIsUnpausing = true;
	CreateTimer(1.0, _P_Unpause_Timer, client, TIMER_REPEAT); // Start unpause countdown
	return Plugin_Handled;
}

/**
 * On client use rotoblins forcepause command
 *
 * @param client		Client id that performed the command.
 * @param command		The command performed.
 * @param args			Number of arguments.
 * @return				Plugin_Handled to stop command from being performed, 
 *						Plugin_Continue to allow the command to pass.
 */
public Action:_P_RotoblinForcePause_Command(client, const String:command[], args)
{
	if (client == SERVER_INDEX) return Plugin_Handled;

	new flags = GetUserFlagBits(client);
	if (!(flags & ADMFLAG_ROOT || flags & ADMFLAG_GENERIC))
	{
		PrintToChat(client, "[%s] Only admins can force pause the game.", PLUGIN_TAG);
		return Plugin_Handled;
	}

	if (g_bIsPaused && !g_bIsUnpausing) // Is paused and not currently unpausing
	{
		g_bWasForced = false;
		PrintToChatAll("[%s] The game has been unpaused by an admin.", PLUGIN_TAG);
		g_bIsUnpausing = true; // Set unpausing state
		CreateTimer(1.0, _P_Unpause_Timer, client, TIMER_REPEAT); // Start unpause countdown
	}
	else if (!g_bIsPaused) // Is not paused
	{
		g_bWasForced = true; // Pause was forced so only allow admins to unpause
		PrintToChatAll("[%s] The game has been paused by an admin.", PLUGIN_TAG);
		Pause(client);
	}
	return Plugin_Handled;
}

/**
 * Called when the timer interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @return				Plugin_Stop to stop repeating, any other value for
 *						default behavior.
 */
public Action:_P_Unpause_Timer(Handle:timer, any:client)
{
	if (!g_bIsUnpausing) return Plugin_Stop; // Server was repaused/unpaused before the countdown finished

	static iCountdown = 3;

	if (iCountdown == 3)
	{
		PrintToChatAll("Game will resume in %d...", iCountdown);
		iCountdown--;
		return Plugin_Continue;
	}
	else if (iCountdown == 0)
	{
		PrintToChatAll("Game is Live!");
		Unpause(client);
		iCountdown = 3;
		return Plugin_Stop;
	}

	PrintToChatAll("%d...", iCountdown);
	iCountdown--;
	return Plugin_Continue;
}

/**
 * Called when the timer for reset of pause requests interval has elapsed.
 * 
 * @param timer			Handle to the timer object.
 * @noreturn
 */
public Action:_P_ResetPauseRequests_Timer(Handle:timer)
{
	ResetPauseRequests();
}

// **********************************************
//                 Private API
// **********************************************


/**
 * Resets pause requests for both teams.
 * 
 * @noreturn
 */
static ResetPauseRequests()
{
	g_bPauseRequest[0] = false;
	g_bPauseRequest[1] = false;
}

/**
 * Pauses the game.
 *
 * @param client		Client that will be selected to pause the game, if not provided
 *							a random client will be used.
 * @noreturn
 */
static Pause(client = 0)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
	{
		client = GetAnyClient(true);
		if (!client) return; // Couldn't find any clients to pause the game
	}

	g_bIsPausable = true; // Allow the next setpause command to go through

	SetConVarInt(g_hPausable, 1);
	FakeClientCommand(client, SETPAUSE_COMMAND);
	SetConVarInt(g_hPausable, 0);
	ResetPauseRequests();
}

/**
 * Unpauses the game.
 *
 * @param client		Client that will be selected to unpause the game, if not provided
 *							a random client will be used.
 * @noreturn
 */
static Unpause(client = 0)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
	{
		client = GetAnyClient(true);
		if (!client) return; // Couldn't find any clients to unpause the game
	}

	g_bIsUnpausable = true; // Allow the next unpause command to go through

	SetConVarInt(g_hPausable, 1);
	FakeClientCommand(client, UNPAUSE_COMMAND);
	SetConVarInt(g_hPausable, 0);
	ResetPauseRequests();
}

stock _P_CvarDump()
{
	decl iVal;
	if (bool:(iVal = GetConVarBool(g_hPauseEnable_Cvar)) != g_bIsPauseEnable)
		DebugLog("%d		|	%d		|	rotoblin_pause_allowed", iVal, g_bIsPauseEnable);
}
