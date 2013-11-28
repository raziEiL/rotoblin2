#define READY_VERSION "1.0.4.2"

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4downtown>

/*
* PROGRAMMING CREDITS:
* Could not do this without Fyren at all, it was his original code chunk
* 	that got me started (especially turning off directors and freezing players).
* 	Thanks to him for answering all of my silly coding questions too.
*
* TESTING CREDITS:
*
* Biggest #1 thanks goes out to Fission for always being there since the beginning
* even when this plugin was barely working.
*/

native L4D_IsInMatchVoteMenu(client);

#define READY_DEBUG					0
#define READY_DEBUG_LOG				0

// ---
#define ALLOW_TEAM_PLACEMENT		0				// uses the same code as in l4d scores
#define L4D							1				// 1 = left 4 dead, 0 = left 4 dead 2
// ---

#define READY_SCAVENGE_WARMUP				0		// 0 = L4D, 1 = L4D2
#define READY_LIVE_COUNTDOWN				5
#define L4D_UNPAUSE_DELAY					3
#define READY_UNREADY_HINT_PERIOD		10.0
#define READY_LIST_PANEL_LIFETIME		10
#define READY_RESTART_ROUND_DELAY		0.0
#define READY_RESTART_MAP_DELAY			5.0
#define READY_RESTART_SCAVENGE_TIMER	0.1
#define READY_SPECTATE_COOLDOWN			3.0
#define L4D_TEAM_SURVIVORS					2
#define L4D_TEAM_INFECTED					3
#define L4D_TEAM_SPECTATE					1
#define L4D_SCAVENGE_GAMECLOCK_HALT		(-1.0)
#define L4D_MAXCLIENTS						(MaxClients)
#define L4D_MAXCLIENTS_PLUS1				(MaxClients+1)

#define SCORE_DELAY_PLACEMENT				0.1
#define SCORE_DELAY_TEAM_SWITCH			0.1
#define SCORE_DELAY_SWITCH_MAP			1.0
#define SCORE_DELAY_EMPTY_SERVER			5.0
#define SCORE_DELAY_SCORE_SWAPPED		0.1

#define L4D_TEAM_A							0
#define L4D_TEAM_B							1
#define L4D_TEAM_NAME(%1) (%1 == 2 ? "Survivors" : (%1 == 3 ? "Infected" : (%1 == 1 ? "Spectators" : "Unknown")))

#define CONVAR_FLAGS_PLUGIN FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY

enum PersistentTeam
{
	PersistentTeam_Invalid,
	PersistentTeam_A,
	PersistentTeam_B
}

enum L4D2Team
{
	L4D2Team_Unknown,
	L4D2Team_Spectators,
	L4D2Team_Survivors,
	L4D2Team_Infected
}

static	bool:readyMode, 					//currently waiting for players to ready up?
		goingLive, 						//0 = not going live, 1 or higher = seconds until match starts
		insideCampaignRestart, 		//0=normal play, 1 or 2=programatically restarting round
		hookedPlayerHurt, 				//if we hooked player_hurt event?
		pauseBetweenHalves, 			//should we ready up before starting the 2nd round or go live right away
		bool:isSecondRound, 			//second round or later (esp. in scavenge)
		bool:isNewCampaign = true,		//Has the game been paused yet on this map?
		bool:inWarmUp, 					//Scavenge warm up during ready up.
		lastTeamPause, 					//Stores which team paused the game.
		bool:canUnpause, 				//Whether or not either team can unpause

/* Team placement		 */
		Handle:fSHS,						//SetHumanSpectator
		Handle:fTOB;						//TakeOverBot

#if ALLOW_TEAM_PLACEMENT
static	teamPlacementArray[256],		//after client connects, try to place him to this team
		teamPlacementAttempts[256];	//how many times we attempt and fail to place a person
#endif

#if READY_SCAVENGE_WARMUP
static	Handle:cvarScavengeSetup,
		bool:bReadyOffCalled = true,
		iInitialSetupTime = 45, 		//Setup time as determined by convar scavenge_round_setup_time
		iInitialGhostTimeMin,
		iInitialGhostTimeMax;
#endif

static	bool:isCampaignBeingRestarted, bool:beforeMapStart = true, forcedStart, readyStatus[MAXPLAYERS + 1], bool:temporarilyBlocked[MAXPLAYERS + 1],
		Handle:menuPanel, Handle:liveTimer, bool:isPaused, bool:isUnpausing, Handle:timerMinimumPause, iInitialAllTalk, Handle:g_hCvarReadyNotify,
		bool:unreadyTimerExists, Handle:cvarEnforceReady, Handle:cvarReadyCompetition, Handle:cvarReadyMinimum, Handle:cvarReadyHalves, Handle:cvarReadyServerCfg,
		Handle:cvarReadySearchKeyDisable, Handle:cvarSearchKey, Handle:cvarGameMode, Handle:g_hCvarGod, Handle:cvarCFGName, Handle:cvarPausesAllowed,
		Handle:cvarPauseDuration, Handle:cvarConnectEnabled, Handle:cvarBlockSpecGlobalChat, Handle:cvarDisableReadySpawns, Handle:fwdOnReadyRoundRestarted, Handle:fwdOnRoundIsLive,
		Handle:teamPlacementTrie, Handle:casterTrie, teamScores[PersistentTeam], bool:defaultTeams = true, isMapRestartPending, bool:g_bIsADMPause;


static		Handle:cvarPauseMetod, Handle:g_hCvarNbStop, Handle:g_hCvarInfAmmo, bool:g_bRoundEnd, Handle:g_hSurvLimit, Handle:g_hInfLimit; // fix by raziEiL

#if L4D
	#define GAMECONFIG_FILE "readyup"
#else
	#define GAMECONFIG_FILE "left4downtown.l4d2"
#endif

public Plugin:myinfo =
{
	name = "[L4D & L4D2] Ready Up",
	author = "Downtown1 and Frustian, continued by AtomicStryker, raziEiL [disawar1]",
	description = "Force Players to Ready Up Before Beginning Match",
	version = READY_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=84086"
};

public OnPluginStart()
{
	if(!IsTargetL4D2())
		ThrowError("Plugin does not support this game.");

	RUP_SetupSignature();

	fwdOnReadyRoundRestarted	= CreateGlobalForward("L4DReady_OnReadyRoundRestarted", ET_Ignore);
	fwdOnRoundIsLive			= CreateGlobalForward("L4DReady_OnRoundIsLive", ET_Ignore);

	teamPlacementTrie	= CreateTrie();
	casterTrie			= CreateTrie();

	g_hCvarGod			= FindConVar("god");
	g_hCvarNbStop		= FindConVar("nb_stop");
	g_hCvarInfAmmo		= FindConVar("sv_infinite_ammo");
	cvarSearchKey		= FindConVar("sv_search_key");
	cvarGameMode			= FindConVar("mp_gamemode");
	g_hSurvLimit			= FindConVar("survivor_limit");
	g_hInfLimit			= FindConVar("z_max_player_zombies");
	#if READY_SCAVENGE_WARMUP
		cvarScavengeSetup	= FindConVar("scavenge_round_setup_time");
	#endif

	CreateConVar("l4d_ready_version", READY_VERSION, "Version of the ready up plugin.", CONVAR_FLAGS_PLUGIN|FCVAR_DONTRECORD);

	cvarEnforceReady				= CreateConVar("l4d_ready_enabled",					"0",		"Make players ready up by default before a match begins", 								CONVAR_FLAGS_PLUGIN);
	cvarReadyCompetition			= CreateConVar("l4d_ready_competition",				"0",		"Disable all plugins but a few competition-allowed ones",								CONVAR_FLAGS_PLUGIN);
	cvarReadyHalves					= CreateConVar("l4d_ready_both_halves",				"0",		"Make players ready up both during the first and second rounds of a map",				CONVAR_FLAGS_PLUGIN);
	cvarReadyMinimum				= CreateConVar("l4d_ready_minimum_players",			"8",		"Minimum # of players before we can ready up",											CONVAR_FLAGS_PLUGIN);
	cvarReadyServerCfg				= CreateConVar("l4d_ready_server_cfg",				"",			"Config to execute when the map is changed (to exec after server.cfg).",				CONVAR_FLAGS_PLUGIN);
	cvarReadySearchKeyDisable	= CreateConVar("l4d_ready_search_key_disable",		"0",		"Automatically disable plugin if sv_search_key is blank",								CONVAR_FLAGS_PLUGIN);
	cvarCFGName						= CreateConVar("l4d_ready_cfg_name",					"",			"CFG Name to display on the RUP Menu",													CONVAR_FLAGS_PLUGIN);
	cvarPausesAllowed				= CreateConVar("l4d_ready_pause_allowed",			"0",		"Number of times each team can pause per campaign",										CONVAR_FLAGS_PLUGIN);
	cvarPauseDuration				= CreateConVar("l4d_ready_pause_duration",			"90.0",		"Minimum duration of pause in seconds before either team can unpause",					CONVAR_FLAGS_PLUGIN);
	cvarConnectEnabled				= CreateConVar("l4d_ready_connect_enabled",			"0",		"Show Announcements When Players Join",													CONVAR_FLAGS_PLUGIN);
	cvarBlockSpecGlobalChat		= CreateConVar("l4d_block_spectator_globalchat",		"0",		"Prevent non-caster Spectators from global chatting, it gets redirected to teamchat",	CONVAR_FLAGS_PLUGIN);
	cvarDisableReadySpawns		= CreateConVar("l4d_ready_disable_spawns",			"0",		"Prevent SI from having ghost-mode spawns during readyup.",								CONVAR_FLAGS_PLUGIN);
	cvarPauseMetod					= CreateConVar("l4d_ready_pause_metod",				"0",		"0=defualt, 1=RUP turn on while game in pause",											CONVAR_FLAGS_PLUGIN);
	g_hCvarReadyNotify				= CreateConVar("l4d_ready_notify",					"0",		"Print or not notifiy about ready",														CONVAR_FLAGS_PLUGIN);

	HookConVarChange(cvarEnforceReady,			ConVarChange_ReadyEnabled);
	HookConVarChange(cvarReadyCompetition,		ConVarChange_ReadyCompetition);
	HookConVarChange(cvarSearchKey,				ConVarChange_SearchKey);

	HookEvent("round_start",			eventRSLiveCallback, EventHookMode_PostNoCopy);
	HookEvent("round_end",			eventRoundEndCallback, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace",	eventPlayerBotReplaceCallback);
	HookEvent("bot_player_replace",	eventBotPlayerReplaceCallback);
	HookEvent("player_spawn",			eventSpawnReadyCallback);

	AddCommandListener(RUP_cmdh_JoinTeam, "jointeam");

	#if ALLOW_TEAM_PLACEMENT
		HookEvent("player_team",			Event_PlayerTeam);
	#endif

	//HookEvent("player_disconnect",	eventPlayerDisconnectCallback, EventHookMode_Pre);

	//case-insensitive handling of ready,unready,notready
	RegConsoleCmd("say",		Command_Say);
	RegConsoleCmd("say_team",	Command_Teamsay);

	RegConsoleCmd("sm_r",		Command_readyUp);
	RegConsoleCmd("sm_ready",	Command_readyUp);

	RegConsoleCmd("sm_u",		Command_readyDown);
	RegConsoleCmd("sm_unready", Command_readyDown);

	RegConsoleCmd("sm_reready", Command_Reready);

	RegConsoleCmd("sm_pause",	Command_readyPause);
	RegConsoleCmd("sm_unpause",	Command_readyUnpause);
	RegConsoleCmd("unpause",	Command_Unpause);

	RegAdminCmd("sm_forcepause",	Command_ForcereadyPause, ADMFLAG_KICK);
	RegAdminCmd("sm_fpause",		Command_ForcereadyPause, ADMFLAG_KICK);

	RegConsoleCmd("spectate",	Command_Spectate);
	//RegConsoleCmd("sm_afk",		Command_Spectate);
	RegConsoleCmd("callvote",	Command_CallVote);
	RegConsoleCmd("vote",		Command_CallVote);

	RegAdminCmd("sm_restartmap", CommandRestartMap, ADMFLAG_CHANGEMAP, "sm_restartmap - changelevels to the current map");
	RegAdminCmd("sm_abort",		Command_Abort, ADMFLAG_KICK, "sm_abort");
	RegAdminCmd("sm_fstart",		Command_Start, ADMFLAG_KICK, "sm_forcestart");
	RegAdminCmd("sm_forcestart", Command_Start, ADMFLAG_KICK);
	RegAdminCmd("sm_cast",		Command_RegCaster, ADMFLAG_GENERIC);
	RegAdminCmd("sm_toready", 	Command_ToReady, ADMFLAG_KICK);
}

native bool:BaseComm_IsClientGagged(client);

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("BaseComm_IsClientGagged");
	MarkNativeAsOptional("L4D_IsInMatchVoteMenu");
	CreateNative("L4DReady_IsGamePaused", nativeIsGamePaused);
	CreateNative("L4DReady_IsReadyMode", nativeIsRUP);
	return APLRes_Success;
}

public nativeIsRUP(Handle:plugin, numParams)
{
	return readyMode;
}

#if ALLOW_TEAM_PLACEMENT
public OnAllPluginsLoaded()
{
	new bool:l4dscores = FindConVar("l4d_team_manager_ver") != INVALID_HANDLE;

	if(!l4dscores)
	{
		// l4d scores plugin is NOT loaded
		// supply these commands which would otherwise be done by the team manager

		RegAdminCmd("sm_swap", Command_Swap, ADMFLAG_BAN, "sm_swap <player1> [player2] ... [playerN] - swap all listed players to opposite teams");
		RegAdminCmd("sm_swapto", Command_SwapTo, ADMFLAG_BAN, "sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to <teamnum> (1,2, or 3)");
		RegAdminCmd("sm_swapteams", Command_SwapTeams, ADMFLAG_BAN, "sm_swapteams2 - swap the players between both teams");
	}
}
#endif

new bool:insidePluginEnd = false;

public OnPluginEnd()
{
	insidePluginEnd = true;
	readyOff();
}

public OnMapStart()
{
	g_bIsADMPause = false;
	isPaused = false;
	DebugPrintToAll("Event map started.");
	beforeMapStart = false;
	//isNewCampaign = true;
	/*
	* execute the cfg specified in l4d_ready_server_cfg
	*/
	if (teamScores[PersistentTeam_A] > teamScores[PersistentTeam_B])
	{
		defaultTeams = true;
	}
	else if (teamScores[PersistentTeam_A] < teamScores[PersistentTeam_B])
	{
		defaultTeams = false;
	}
	if(GetConVarInt(cvarEnforceReady))
	{
		decl String:cfgFile[128];
		GetConVarString(cvarReadyServerCfg, cfgFile, sizeof(cfgFile));

		if(strlen(cfgFile) == 0)
		{
			return;
		}

		decl String:cfgPath[1024];
		BuildPath(Path_SM, cfgPath, 1024, "../../cfg/%s", cfgFile);

		if(FileExists(cfgPath))
		{
			DebugPrintToAll("Executing server config %s", cfgPath);

			ServerCommand("exec %s", cfgFile);
		}
		else
		{
			LogError("[SM] Could not execute server config %s, file not found", cfgPath);
			PrintToServer("[SM] Could not execute server config %s, file not found", cfgFile);
			//PrintToChatAll("[SM] Could not execute server config %s, file not found", cfgFile);
		}
	}
}

public OnMapEnd()
{
	beforeMapStart = true;
	isSecondRound = false;

	readyOff();

	DebugPrintToAll("Event: Map ended.");
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (readyMode && !inWarmUp)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == L4D_TEAM_SURVIVORS)
		{
			ToggleFreezePlayer(client, true);
		}
	}
}

public bool:OnClientConnect(client, String:rejectmsg[], size)
{
	if (readyMode)
	{
		checkStatus();
	}

	return true;
}

public OnClientDisconnect()
{
	if (readyMode) checkStatus();
}

//public Action:eventPlayerDisconnectCallback(Handle:event, const String:name[], bool:dontBroadcast)
//{
//	if (dontBroadcast) return Plugin_Continue;
//
//	new client = GetClientOfUserId(GetEventInt(event, "userid"));
//	if( client && !IsFakeClient(client))
//	{
//		decl String:clientName[128], String:networkID[22], String:reason[128];
//		GetEventString(event, "name", clientName, sizeof(clientName));
//		GetEventString(event, "networkid", networkID, sizeof(networkID));
//		GetEventString(event, "reason", reason, sizeof(reason));
//		//announce disconnect reason
//		PrintToChatAll("[SM] %s disconnected. Reason: %s", clientName, reason);
//
//		new Handle:newEvent = CreateEvent("player_disconnect", true);
//		SetEventInt(newEvent, "userid", GetEventInt(event, "userid"));
//		SetEventString(newEvent, "reason", reason);
//		SetEventString(newEvent, "name", clientName);
//		SetEventString(newEvent, "networkid", networkID);
//		//fire non-broadcasted event instead
//		FireEvent(newEvent, true);
//		return Plugin_Stop;
//	}
//	return Plugin_Continue;
//}

public OnClientAuthorized(client,const String:SteamID[])
{
	if (GetConVarInt(cvarConnectEnabled) && !IsFakeClient(client) && (readyMode || isPaused))
		CPrintToChatAll("[SM] Player {blue}%N{default} has connected", client);
}

checkStatus()
{
	new humans, ready, team;
	new iHumanLimit = GetConVarInt(g_hInfLimit) + GetConVarInt(g_hSurvLimit);

	//count number of non-bot players in-game
	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			team = GetClientTeam(i);

			if ((team != L4D_TEAM_SPECTATE && humans < iHumanLimit) || (team == L4D_TEAM_SPECTATE && IsClientCaster(i)))
			{
				humans++;
				if (readyStatus[i]) ready++;
			}
		}
	}
	if(!humans || humans < GetConVarInt(cvarReadyMinimum))
	{
		if (goingLive)
		{
			goingLive = 0;
			PrintHintTextToAll("Aborted going live due to player leaving.");
			KillTimer(liveTimer);
		}
		return;
	}

	if ((goingLive && (humans == ready))
	|| forcedStart)
		return;

	else if (goingLive && (humans != ready))
	{
		goingLive = 0;
		PrintHintTextToAll("Aborted going live due to player unreadying.");
		KillTimer(liveTimer);
	}
	else if (!goingLive && (humans == ready))
	{
		if(!insideCampaignRestart)
		{
			goingLive = READY_LIVE_COUNTDOWN; //TODO get from variable
			liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else if (!goingLive && (humans != ready)) PrintHintTextToAll("%d of %d players are ready.", ready, humans);
	else PrintToChatAll("checkStatus bad state (tell Downtown1)");
}

//repeatedly count down until the match goes live
public Action:timerLiveCountCallback(Handle:timer)
{
	//will go live soon
	if (goingLive)
	{
		if (!IsInAlterPause())
			if (forcedStart) PrintHintTextToAll("Going live in %d seconds.", goingLive);
			else PrintHintTextToAll("All players ready!\nGoing live in %d seconds.", goingLive);
		else
			PrintToChatAll("Going live in %d seconds.", goingLive);

		goingLive--;
	}
	//actually go live and unfreeze everyone
	else
	{
		//readyOff();

		if(ShouldResetRoundTwiceToGoLive())
		{
			PrintHintTextToAll("Match will be live after 2 round restarts.");

			insideCampaignRestart = 2;
			RestartCampaignAny();
		}
		else	 // scavenge mode, reready -- DO NOT reset the round twice
		{
			if (IsInAlterPause())
				UnpauseGame(0);

			readyOff();
			RoundIsLive();
		}

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

bool:ShouldResetRoundTwiceToGoLive()
{
	if(inWarmUp)	//scavenge pre-first round warmup
		return true;

	//do not reset the round for L4D2 versus or L4D2 scavenge reready
	return false;
}

public Action:eventRoundEndCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	DebugPrintToAll("[DEBUG] Event round has ended");
	g_bRoundEnd = true;

	#if ALLOW_TEAM_PLACEMENT
		if(isSecondRound)
			SaveSpectators();
	#endif

	if(!isCampaignBeingRestarted)
	{
		if(!isSecondRound)
		{
			DebugPrintToAll("[DEBUG] Second round detected.");
			if(GetConVarBool(cvarEnforceReady) && !isSecondRound && GetConVarBool(cvarDisableReadySpawns) && (GetConVarInt(cvarReadyHalves) || pauseBetweenHalves))
			{
				SetConVarInt(FindConVar("director_no_specials"), 1);
			}
		}
		else
			DebugPrintToAll("[DEBUG] End of second round detected.");

		isSecondRound = true;
	}

	//we just ended the last restart, match will be live soon
	if(insideCampaignRestart == 1)
	{
		//enable the director etc, but dont unfreeze all players just yet
		readyOff();
	}

	isCampaignBeingRestarted = false;
}

public Action:eventRSLiveCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (isSecondRound)
		CreateTimer(2.0, RUP_t_Respectate);

	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Event round has started");
	#endif

	CreateTimer(2.0, _RUP_t_SafeTime);

	//currently automating campaign restart before going live?
	if(insideCampaignRestart > 0)
	{
		insideCampaignRestart--;
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Round restarting, left = %d", insideCampaignRestart);
		#endif

		//first restart, do one more
		if(insideCampaignRestart == 1)
		{
		#if READY_RESTART_ROUND_DELAY
			CreateTimer(READY_RESTART_ROUND_DELAY, timerOneRoundRestart, _, _);
		#else //with RestartScenarioFromVote there is no need to have a delay
			RestartCampaignAny();
		#endif

			PrintHintTextToAll("Match will be live after 1 round restart.");

		}
		//last restart, match is now live!
		else if (!insideCampaignRestart)
		{
			RoundIsLive();
		}
		else
		{
			LogError("insideCampaignRestart somehow neither 0 nor 1 after decrementing");
		}

		return Plugin_Continue;
	}

	//normal round start event not triggered by our plugin

	//our code will just enable ready mode at the start of a round
	//if the cvar is set to it
	if(GetConVarInt(cvarEnforceReady)
	&& (!isSecondRound || GetConVarInt(cvarReadyHalves) || pauseBetweenHalves))
	{
		#if READY_DEBUG
		DebugPrintToAll("[DEBUG] Calling comPready, pauseBetweenHalves = %d", pauseBetweenHalves);
		#endif

		compReady(0, 0);
		pauseBetweenHalves = 0;
	}

	return Plugin_Continue;
}

public Action:RUP_t_Respectate(Handle:timer)
{
	//respectate trick to get around spectator camera being stuck
	//also make sure to block pause troller

	for (new i = 1; i <= MaxClients; i++){

		if (IsClientInGame(i) && GetClientTeam(i) == 1){

			temporarilyBlocked[i] = true;
			CreateTimer(0.2, Timer_UnlockClient, i);

			ChangePlayerTeam(i, L4D_TEAM_INFECTED);
			CreateTimer(0.1, Timer_Respectate, i, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:_RUP_t_SafeTime(Handle:timer)
{
	g_bRoundEnd = false;
}

public Action:timerOneRoundRestart(Handle:timer)
{
	PrintToChatAll("[SM] Match will be live after 1 round restart!");
	PrintHintTextToAll("Match will be live after 1 round restart!");

	RestartCampaignAny();

	return Plugin_Stop;
}

public Action:timerLiveMessageCallback(Handle:timer)
{
	PrintHintTextToAll("Match is LIVE!");

	if(GetConVarInt(cvarReadyHalves) || isSecondRound)
	{
		PrintToChatAll("[SM] Match is live!");
	}
	else
	{
		CPrintToChatAll("{blue}[SM] Match is LIVE for both halves, say !reready to request a ready-up before the next half.");
	}

	return Plugin_Stop;
}

public Action:eventSpawnReadyCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (readyMode && !inWarmUp)
	{
		new player = GetClientOfUserId(GetEventInt(event, "userid"));
		#if READY_DEBUG
		decl String:curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Spawned %s [%d], freezing.", curname, player);
		#endif
		ToggleFreezePlayer(player, true);
	}
	return Plugin_Handled;
}

// left4downtown forward's
public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	DebugPrintToAll("OnSpawnTank(vector[%f,%f,%f], qangle[%f,%f,%f]",
		vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);

	if(readyMode)
	{
		DebugPrintToAll("Blocking tank spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action:L4D_OnSpawnWitch(const Float:vector[3], const Float:qangle[3])
{
	DebugPrintToAll("OnSpawnWitch(vector[%f,%f,%f], qangle[%f,%f,%f])",
		vector[0], vector[1], vector[2], qangle[0], qangle[1], qangle[2]);

	if(readyMode)
	{
		DebugPrintToAll("Blocking witch spawn...");
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action:L4D_OnSetCampaignScores(&scoreA, &scoreB)
{
	teamScores[PersistentTeam_A] = scoreA;
	teamScores[PersistentTeam_B] = scoreB;
	if (!scoreA && !scoreB && beforeMapStart)
	{
		OnNewCampaign();
	}
	return Plugin_Continue;
}

public Action:L4D_OnClearTeamScores(bool:newCampaign)
{
	if (newCampaign)
		OnNewCampaign();
}
// ---;

OnNewCampaign()
{
	#if READY_DEBUG_LOG
		DebugPrintToAll("OnNewCampaign()");
	 #endif

	defaultTeams = true;
	isNewCampaign = true;

	CloseHandle(teamPlacementTrie);
	teamPlacementTrie = CreateTrie();

	CloseHandle(casterTrie);
	casterTrie = CreateTrie();
}

//When a player replaces a bot (i.e. player joins survivors team)
public Action:eventBotPlayerReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	//	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	new player = GetClientOfUserId(GetEventInt(event, "player"));

	if(readyMode && !inWarmUp)
	{
		//called when player joins survivor....?
		#if READY_DEBUG
		decl String:curname[128];
		GetClientName(player,curname,128);
		DebugPrintToAll("[DEBUG] Player %s [%d] replacing bot, freezing player.", curname, player);
		#endif

		ToggleFreezePlayer(player, true);
	}

	return Plugin_Handled;
}


//When a bot replaces a player (i.e. player switches to spectate or infected)
public Action:eventPlayerBotReplaceCallback(Handle:event, const String:name[], bool:dontBroadcast)
{
	new player = GetClientOfUserId(GetEventInt(event, "player"));
	//	new bot = GetClientOfUserId(GetEventInt(event, "bot"));

	if(readyMode && !inWarmUp)
	{
		#if READY_DEBUG
		decl String:curname[128];
		GetClientName(player,curname,128);

		DebugPrintToAll("[DEBUG] Bot replacing player %s [%d], unfreezing player.", curname, player);
		#endif

		if (player)
		{
			//if player isn't disconnected
			ToggleFreezePlayer(player, false);
		}
	}

	return Plugin_Handled;
}

RestartCampaignAny()
{
	decl String:currentmap[128];
	GetCurrentMap(currentmap, sizeof(currentmap));

	DebugPrintToAll("RestartCampaignAny() - Restarting scenario from vote ...");

	Call_StartForward(fwdOnReadyRoundRestarted);
	Call_Finish();

	L4D_RestartScenarioFromVote(currentmap);
}





// RUP Commands
public Action:CommandRestartMap(client, args)
{
	if(!isMapRestartPending)
	{
		PrintToChatAll("[SM] Map resetting in %.0f seconds.", READY_RESTART_MAP_DELAY);
		RestartMapDelayed();
	}

	return Plugin_Handled;
}

RestartMapDelayed()
{
	isMapRestartPending = true;

	CreateTimer(READY_RESTART_MAP_DELAY, timerRestartMap, _, TIMER_FLAG_NO_MAPCHANGE);
	DebugPrintToAll("[SM] Map will restart in %f seconds.", READY_RESTART_MAP_DELAY);
}

public Action:timerRestartMap(Handle:timer)
{
	RestartMapNow();
}

RestartMapNow()
{
	isMapRestartPending = false;

	decl String:currentMap[256];

	GetCurrentMap(currentMap, 256);

	ServerCommand("changelevel %s", currentMap);
}

public Action:Command_CallVote(client, args)
{
	/*
	static Handle:hVoteManager;

	if (hVoteManager == INVALID_HANDLE)
		hVoteManager = FindConVar("l4d2_votemanager_version");

	if (hVoteManager != INVALID_HANDLE)
		return Plugin_Continue;
	*/
	if (temporarilyBlocked[client]) return Plugin_Handled;
	if (client && IsClientInGame(client) && GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		return Plugin_Continue;
	}

	ReplyToCommand(client, "[SM] You must be ingame and not spectator to vote");
	return Plugin_Handled;
}

static bool:g_bSpectateTempBlock[MAXPLAYERS+1];

public Action:Command_Spectate(client, args)
{
	if (temporarilyBlocked[client] || g_bRoundEnd) return Plugin_Handled;
	if(IsPlayerAlive(client) && GetClientTeam(client) == L4D_TEAM_INFECTED)
	{
		g_bSpectateTempBlock[client] = true;
		CreateTimer(READY_SPECTATE_COOLDOWN, RUP_t_AllowJoinToInf, client);
		TeleportEntity(client, Float:{0.0, 0.0, 0.0}, NULL_VECTOR, NULL_VECTOR); // no ragdoll!
		ForcePlayerSuicide(client);
	}
	if(GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
		CPrintToChatAll("[SM] Player {blue}%N{default} has become a spectator", client);
		if(readyMode) checkStatus();
	}

	return Plugin_Handled;
}

public Action:RUP_cmdh_JoinTeam(client, const String:command[], argc)
{
	if (g_bSpectateTempBlock[client]){

		decl String:sAgr[32];
		GetCmdArg(1, sAgr, 32);

		if (StrEqual(sAgr, "3") || StrEqual(sAgr, "infected", false))
			return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:RUP_t_AllowJoinToInf(Handle:timer, any:client)
{
	g_bSpectateTempBlock[client] = false;
}

public Action:Timer_UnlockClient(Handle:timer, any:client)
{
	temporarilyBlocked[client] = false;
}

public Action:Timer_Respectate(Handle:timer, any:client)
{
	if (IsClientInGame(client))
		ChangePlayerTeam(client, L4D_TEAM_SPECTATE);
	//PrintToChatAll("[SM] %N has become a spectator (again).", client);
	if(readyMode) checkStatus();
}

bool:OptIsGagged(client)
{
	if (GetFeatureStatus(FeatureType_Native, "BaseComm_IsClientGagged") == FeatureStatus_Available)
	{
		return BaseComm_IsClientGagged(client);
	}

	return false;
}

public Action:Command_Say(client, args)
{
	if (temporarilyBlocked[client]) return Plugin_Handled;

	if (client && IsClientInGame(client)){

		new team = GetClientTeam(client);

		if (args < 1
		|| (team == L4D_TEAM_SPECTATE && (readyMode || isPaused))
		|| (team != L4D_TEAM_SPECTATE && (!readyMode && !isPaused))
		|| OptIsGagged(client))
		{
			return Plugin_Continue;
		}

		if (client &&  team == L4D_TEAM_SPECTATE)
		{
			if (!IsClientCaster(client) && GetConVarBool(cvarBlockSpecGlobalChat))
			{
				//Command_Teamsay(client, args); for l4d2

				decl String:sText[256];
				GetCmdArg(1, sText, sizeof(sText));
				if ((IsChatTrigger() && sText[0] == '/') //Ignore if it is a server message or a silent chat trigger
				|| GetUserFlagBits(client) && sText[0] == '@') //Or admin talk
				{
					return Plugin_Continue;
				}

				decl String:text[192];
				GetCmdArgString(text, 192);
				FakeClientCommandEx(client,"say_team %s", text);

				if (!isPaused)
					PrintHintText(client, "Spectators cannot global chat in ready modes");
				else
					PrintToChat(client, "Spectators cannot global chat in ready modes");
				return Plugin_Handled;
			}
		}

		decl String:sayWord[MAX_NAME_LENGTH];
		GetCmdArg(1, sayWord, sizeof(sayWord));

		if(sayWord[0] == '!' || sayWord[0] == '/')
		{
			if(StrEqual(sayWord[1], "notready")
			|| StrEqual(sayWord[1], "unready")
			|| StrEqual(sayWord[1], "ready")
			|| StrEqual(sayWord[1], "cast"))
			{
				return Plugin_Handled;
			}
		}

		if (isPaused) //Do our own chat output when the game is paused
		{
			decl String:sText[256];
			GetCmdArg(1, sText, sizeof(sText));
			if (!client
			|| (IsChatTrigger() && sText[0] == '/') //Ignore if it is a server message or a silent chat trigger
			|| GetUserFlagBits(client) && sText[0] == '@') //Or admin talk
			{
				return Plugin_Continue;
			}

			PrintToChatAll("\x03%N\x01 : %s", client, sText); //Display the users message
			return Plugin_Handled; //Since the issue only occurs sometimes we need to block default output to prevent showing text twice
		}
	}
	return Plugin_Continue;
}

public Action:Command_Teamsay(client, args)
{
	if (temporarilyBlocked[client] || !client || !IsClientInGame(client)) return Plugin_Handled;
	if (args < 1
	|| (!readyMode && !isPaused)
	|| OptIsGagged(client))
	{
		return Plugin_Continue;
	}

	decl String:sayWord[MAX_NAME_LENGTH];
	GetCmdArg(1, sayWord, sizeof(sayWord));

	if(sayWord[0] == '!' || sayWord[0] == '/')
	{
		if(StrEqual(sayWord[1], "notready")
		|| StrEqual(sayWord[1], "unready")
		|| StrEqual(sayWord[1], "ready")
		|| StrEqual(sayWord[1], "cast"))
		{
			return Plugin_Handled;
		}
	}

	if (isPaused) //Do our own chat output when the game is paused
	{
		decl String:sText[256];
		GetCmdArg(1, sText, sizeof(sText));
		if (!client
		|| (IsChatTrigger() && sText[0] == '/') //Ignore if it is a server message or a silent chat trigger
		|| sText[0] == '@') //Or admin talk
		{
			return Plugin_Continue;
		}

		decl String:sTeamName[16];
		new iTeam = GetClientTeam(client);
		if (iTeam == 3)
		{
			sTeamName = "Infected";
		}
		else if (iTeam == 2)
		{
			sTeamName = "Survivor";
		}
		else
		{
			sTeamName = "Spectator";
		}
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				if (GetClientTeam(i) == iTeam) //Is teamchat so only display it to people on the same team
				{
					PrintToChat(i, "\x01(%s) \x03%N\x01 : %s", sTeamName, client, sText); //Display the users message
				}
			}
		}
		return Plugin_Handled; //Since the issue only occurs sometimes we need to block default output to prevent showing text twice
	}
	return Plugin_Continue;
}

public Action:Command_ToReady(client, args)
{
	if (!readyMode)
		readyOn();

	return Plugin_Handled;
}

public Action:Command_readyUp(client, args)
{
	if (!readyMode
	|| !client
	|| readyStatus[client]
	|| (GetClientTeam(client) == L4D_TEAM_SPECTATE && !IsClientCaster(client)))
	{
		return Plugin_Handled;
	}

	if (GetConVarBool(g_hCvarReadyNotify)){

		//don't allow readying up if there's too few players
		new realPlayers = CountInGameHumans();
		new minPlayers = GetConVarInt(cvarReadyMinimum);

		//ready up the player and see if everyone is ready now
		decl String:name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));

		if(realPlayers >= minPlayers)
			PrintToChatAll("%s is ready.", name);
		else
			PrintToChatAll("%s is ready. A minimum of %d players is required.", name, minPlayers);
	}

	readyStatus[client] = 1;
	checkStatus();

	DrawReadyPanelList();

	return Plugin_Handled;
}

public Action:Command_readyDown(client, args)
{
	if (!readyMode
	|| !client
	|| !readyStatus[client]
	|| (GetClientTeam(client) == L4D_TEAM_SPECTATE && !IsClientCaster(client))
	|| isCampaignBeingRestarted
	|| insideCampaignRestart)
	{
		return Plugin_Handled;
	}

	decl String:name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	//PrintToChatAll("%s is no longer ready.", name);

	readyStatus[client] = 0;
	checkStatus();

	DrawReadyPanelList();

	return Plugin_Handled;
}

public Action:Command_RegCaster(client, args)
{
	if (!readyMode
	|| !client
	|| GetClientTeam(client) != L4D_TEAM_SPECTATE)
	{
		return Plugin_Handled;
	}

	decl String:authid[96];
	GetClientAuthString(client, authid, sizeof(authid));
	SetTrieValue(casterTrie, authid, 1);

	ReplyToCommand(client, "You have registered as match caster, readying up will wait for you");
	return Plugin_Handled;
}

public Action:Command_Unpause(client, args)
{
	if (isPaused) return Plugin_Handled;

	return Plugin_Continue;
}

public Action:Command_Reready(client, args)
{
	if (readyMode) return Plugin_Handled;

	pauseBetweenHalves = 1;
	CPrintToChatAll("{blue}[SM] Match will pause at the end of this half and require readying up again.");

	return Plugin_Handled;
}

public Action:Command_readyPause(client, args)
{
	//blocking pause troller
	if (isPaused || temporarilyBlocked[client]) return Plugin_Handled;

	if (!client){

		ServerPauseGame();
		CPrintToChatAll("[SM] Admin {red}%N{default} has paused the game.", client);
		return Plugin_Handled;
	}

	ClientAttemptsPause(client);

	return Plugin_Handled;
}

public Action:Command_ForcereadyPause(client, args)
{
	if (isPaused || temporarilyBlocked[client]) return Plugin_Handled;

	g_bIsADMPause = true;

	ServerPauseGame();
	CPrintToChatAll("[SM] Admin {red}%N{default} has paused the game.", client);
	return Plugin_Handled;
}


//server can pause without a request
ServerPauseGame()
{
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGame(i))
		{
			PauseGame(i);
			break;
		}
	}
}

public Action:Command_readyUnpause(client, args)
{
	//blocking unpause troller
	if (!isPaused || temporarilyBlocked[client]) return Plugin_Handled;

	if (IsInAlterPause()){

		PrintToChat(client, "Game in RUP-pause mode. Say !ready to ready up.");
		return Plugin_Handled;
	}

	new bool:bIsADM;
	if (client)
		bIsADM = g_bIsADMPause && GetUserFlagBits(client);

	//server can unpause without a request
	if(!client || bIsADM)
	{
		g_bIsADMPause = false;
		CPrintToChatAll("[SM] Admin {red}%N{default} has unpaused the game.", client);
		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			if(IsClientInGame(i))
			{
				UnpauseGame(i);
				return Plugin_Handled;
			}
		}
	}

	ClientAttemptsUnpause(client);

	return Plugin_Handled;
}
// --- Commands end;






//draws a menu panel of ready and unready players
DrawReadyPanelList()
{
	if (!readyMode) return;
	static bool:scrollingText;
	/*
	#if READY_DEBUG
	DebugPrintToAll("[DEBUG] Drawing the ready panel");
	#endif
	*/

	new numPlayersRdy, numPlayersNotRdy, numPlayersSpec;
	new ready, unready, spec;
	new bool:isCaster[L4D_MAXCLIENTS_PLUS1];

	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			isCaster[i] = IsClientCaster(i);

			if (GetClientTeam(i) == L4D_TEAM_SPECTATE && !isCaster[i])
			{
				spec++;
			}
			else
			{
				if(readyStatus[i])
					ready++;
				else
					unready++;
			}
		}
	}

	decl String:readyPlayers[1024];
	decl String:name[MAX_NAME_LENGTH];

	new Handle:panel = CreatePanel();

	decl String:sCFGName[128];
	GetConVarString(cvarCFGName, sCFGName, sizeof(sCFGName));
	Format(sCFGName, 128, "%s", sCFGName);

	if (sCFGName[0]){

		DrawPanelText(panel, sCFGName);
		DrawPanelText(panel, "       ");
	}

	if(ready)
	{
		DrawPanelText(panel, "READY");

		//->%d. %s makes the text yellow
		// otherwise the text is white

		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			if(IsClientInGameHuman(i) && (GetClientTeam(i) != L4D_TEAM_SPECTATE || IsClientCaster(i)))
			{
				GetClientName(i, name, sizeof(name));

				if(readyStatus[i])
				{
					numPlayersRdy++;
					FormatEx(readyPlayers, 1024, "->%d. %s%s", numPlayersRdy, name, isCaster[i] ? " [CASTER]" : "" );

					DrawPanelText(panel, readyPlayers);
				}
			}
		}
	}

	if(unready)
	{
		DrawPanelText(panel, "NOT READY");

		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			if(IsClientInGameHuman(i) && (GetClientTeam(i) != L4D_TEAM_SPECTATE || IsClientCaster(i)))
			{
				GetClientName(i, name, sizeof(name));

				if(!readyStatus[i])
				{
					numPlayersNotRdy++;
					FormatEx(readyPlayers, 1024, "->%d. %s%s", numPlayersNotRdy, name, isCaster[i] ? " [CASTER]" : "" );

					DrawPanelText(panel, readyPlayers);
				}
			}
		}
	}

	if (spec)
	{
		DrawPanelText(panel, "SPECTATING");

		for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			if(IsClientInGameHuman(i) && GetClientTeam(i) == L4D_TEAM_SPECTATE  && !IsClientCaster(i))
			{
				GetClientName(i, name, sizeof(name));

				numPlayersSpec++;
				Format(readyPlayers, 1024, "->%d. %s", numPlayersSpec, name);
				DrawPanelText(panel, readyPlayers);
			}
		}
	}

	decl String:versionInfo[128];

	if (scrollingText)
	{
		#if !L4D
			FormatEx(versionInfo, sizeof(versionInfo), "!rmatch / !addon");
		#else
			FormatEx(versionInfo, sizeof(versionInfo), "%s", !GetRandomInt(0, 1) ? "Ready Up Created by:\nDowntown1 & Frustian" : "Ready Up Continued by:\nAtomicStryker, raziEiL");
		#endif
	}
	else
	{
		#if !L4D
			FormatEx(versionInfo, sizeof(versionInfo), "!rmatch / !addon");
		#else

			static Handle:hR2Version;

			if (hR2Version == INVALID_HANDLE)
				hR2Version = FindConVar("rotoblin_2_version");

			new iVal;

			decl String:sVersion[32];
			if (hR2Version != INVALID_HANDLE){


				GetConVarString(hR2Version, sVersion, 32);
				iVal = GetRandomInt(0, 1);
			}
			else
				SetFailState("r2comp mod not found!");

			FormatEx(versionInfo, sizeof(versionInfo), "%s v%s", !iVal ? "Ready Up" : "R2 CompMod", !iVal ? READY_VERSION : sVersion);
		#endif
	}
	scrollingText = !scrollingText;
	DrawPanelText(panel, versionInfo);

	new bool:bVMAvalible = GetFeatureStatus(FeatureType_Native, "L4D_IsInMatchVoteMenu") == FeatureStatus_Available;

	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			// private for votemenu
			if (bVMAvalible && L4D_IsInMatchVoteMenu(i)) continue;

			SendPanelToClient(panel, i, Menu_ReadyPanel, READY_LIST_PANEL_LIFETIME);
		}
	}

	if(menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
	}
	menuPanel = panel;
}


public Menu_ReadyPanel(Handle:menu, MenuAction:action, param1, param2)
{
}

//freeze everyone until they ready up
readyOn()
{

	DebugPrintToAll("readyOn() called");

#if READY_SCAVENGE_WARMUP

	if(IsScavengeMode() && !isSecondRound)
		inWarmUp = true;
	else
		inWarmUp = false;
#else
	inWarmUp = false;
#endif
	readyMode = true;

	if (!isPaused)
		PrintHintTextToAll("Ready mode on.\nSay !ready to ready up or !unready to unready.");
	else
		PrintToChatAll("RUP-pause mode on. Say !ready to ready up or !unready to unready.");

	if (!inWarmUp)
	{
		if(!hookedPlayerHurt)
		{
			ChangeConVarSilent(g_hCvarGod, 1);
			ChangeConVarSilent(g_hCvarInfAmmo, 1);

			#if L4D
				if (!isPaused)
					ChangeConVarSilent(g_hCvarNbStop, 1);
			#endif

			hookedPlayerHurt = 1;
		}
		if(IsScavengeMode())
		{
			//reset the scavenge setup timer every 0.5 seconds
			CreateTimer(READY_RESTART_SCAVENGE_TIMER, Timer_ResetScavengeSetup, _, TIMER_REPEAT);
		}
		else //versus
		{
			if(!isSecondRound && GetConVarBool(cvarDisableReadySpawns))
			{
				SetConVarInt(FindConVar("director_no_specials"), 1);
			}

			#if !L4D
				L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
			#endif
		}

		for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		{
			readyStatus[i] = 0;
			if (IsValidEntity(i) && IsClientInGame(i) && (GetClientTeam(i) == L4D_TEAM_SURVIVORS))
			{

				#if READY_DEBUG
				decl String:curname[128];
				GetClientName(i,curname,128);
				DebugPrintToAll("[DEBUG] Freezing %s [%d] during readyOn().", curname, i);
				#endif

				ToggleFreezePlayer(i, true);
			}
		}
	}
#if READY_SCAVENGE_WARMUP
	else // warm up on
	{
		if (bReadyOffCalled)
		{
			iInitialSetupTime = GetConVarInt(cvarScavengeSetup);
			iInitialAllTalk = GetConVarInt(FindConVar("sv_alltalk"));
			iInitialGhostTimeMin = GetConVarInt(FindConVar("z_ghost_delay_min"));
			iInitialGhostTimeMax = GetConVarInt(FindConVar("z_ghost_delay_max"));
		}
		bReadyOffCalled = false;
		DebugPrintToAll("Warmup on");
		iInitialSetupTime = GetConVarInt(cvarScavengeSetup);
		SetConVarInt(cvarScavengeSetup, 0);

		ChangeConVarSilent(g_hCvarGod, 1);

		SetConVarInt(FindConVar("director_no_mobs"), 1);
		SetConVarInt(FindConVar("director_ready_duration"), 0);
		SetConVarInt(FindConVar("z_common_limit"), 0);
		SetConVarInt(FindConVar("sv_alltalk"), 1);
		SetConVarInt(FindConVar("z_ghost_delay_max"), 0);
		SetConVarInt(FindConVar("z_ghost_delay_min"), 0);
		L4D_SetRoundEndTime(L4D_SCAVENGE_GAMECLOCK_HALT);
	}
#endif

	if(!unreadyTimerExists)
	{
		unreadyTimerExists = true;
		CreateTimer(READY_UNREADY_HINT_PERIOD, timerUnreadyCallback, _, TIMER_REPEAT);
	}
}

#if L4D
public SharedPlugin:__pl_r2compmod =
{
	name = "r2compmod",
	file = "r2compmod.smx",
	required = 1,
};
#endif

//reset the scavenge setup timer so it stays in setup indefinitely
public Action:Timer_ResetScavengeSetup(Handle:timer)
{
	if(!readyMode)
	{
		DebugPrintToAll("Scavenge setup timer halted , leaving ready mode");
		return Plugin_Stop;
	}
	#if !L4D
		L4D_ScavengeBeginRoundSetupTime();
	#endif
	return Plugin_Continue;
}

public Action:timerUnreadyCallback(Handle:timer)
{
	if(!readyMode)
	{
		unreadyTimerExists = false;
		return Plugin_Stop;
	}

	if(insideCampaignRestart)
		return Plugin_Continue;

	//new curPlayers = CountInGameHumans();
	//new minPlayers = GetConVarInt(cvarReadyMinimum);

	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGameHuman(i) && (GetClientTeam(i) != L4D_TEAM_SPECTATE || IsClientCaster(i)))
		{
			//use panel for ready up stuff?
			if(!readyStatus[i])
			{
				if (!isPaused)
					PrintHintText(i, "You are NOT READY!\nSay !ready in chat to ready up.");
				else
					PrintToChat(i, "You are NOT READY! Say !ready in chat to ready up.");
			}
			else
			{
				if (!isPaused)
					PrintHintText(i, "You are ready.\nSay !unready in chat if no longer ready.");
				else
					PrintToChat(i, "You are ready. Say !unready in chat if no longer ready.");
			}
		}
	}

	DrawReadyPanelList();

#if READY_SCAVENGE_WARMUP
	if (inWarmUp)
	{
		new ent = -1;
		new prev = 0;
		while ((ent = FindEntityByClassname(ent, "weapon_gascan")) != -1)
		{
			if (prev)
			{
				RemoveEdict(prev);
			}
			prev = ent;
		}
		if (prev)
		{
			RemoveEdict(prev);
		}
		DebugPrintToAll("Removed all gas cans");
	}
#endif

	return Plugin_Continue;
}

//allow everyone to move now
readyOff()
{
	DebugPrintToAll("readyOff() called");

	readyMode = false;

	//events seem to be all unhooked _before_ OnPluginEnd
	//though even if it wasnt, they'd get unhooked after anyway..
	if(hookedPlayerHurt)
	{
		ChangeConVarSilent(g_hCvarGod, 0);
		ChangeConVarSilent(g_hCvarInfAmmo, 0);

		#if L4D
			if (!isPaused)
				ChangeConVarSilent(g_hCvarNbStop, 0);
		#endif

		hookedPlayerHurt = 0;
	}
	if (!inWarmUp)
	{
		if(GetConVarBool(cvarDisableReadySpawns))
		{
			ResetConVar(FindConVar("director_no_specials"));
		}
		if(insidePluginEnd)
		{
			UnfreezeAllPlayers();
		}
	}
#if READY_SCAVENGE_WARMUP
	else //warm up off
	{
		bReadyOffCalled = true;
		DebugPrintToAll("Warmup off");
		SetConVarInt(cvarScavengeSetup, iInitialSetupTime);

		ChangeConVarSilent(g_hCvarGod, 0);

		SetConVarInt(FindConVar("sv_alltalk"), iInitialAllTalk);
		SetConVarInt(FindConVar("z_ghost_delay_max"), iInitialGhostTimeMax);
		SetConVarInt(FindConVar("z_ghost_delay_min"), iInitialGhostTimeMin);
		L4D_ResetRoundNumber();
		inWarmUp = false;
	}
#endif
	//used to unfreeze all players here always
	//now we will do it at the beginning of the round when its live
	//so that players cant open the safe room door during the restarts
}

ChangeConVarSilent(Handle:hCvar, iVal)
{
	new iFlag = GetConVarFlags(hCvar);

	SetConVarFlags(hCvar, iFlag & ~FCVAR_NOTIFY);
	SetConVarInt(hCvar, iVal);
	SetConVarFlags(hCvar, iFlag | FCVAR_NOTIFY);
}

#if READY_SCAVENGE_WARMUP
L4D_ResetRoundNumber()
{
	static bool:init = false;
	static Handle:func = INVALID_HANDLE;

	if(!init)
	{
		new Handle:conf = LoadGameConfigFile(GAMECONFIG_FILE);
		if(conf == INVALID_HANDLE)
		{
			LogError("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
			DebugPrintToAll("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
		}

		StartPrepSDKCall(SDKCall_GameRules);
		new bool:readConf = PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTerrorGameRules_ResetRoundNumber");
		if(!readConf)
		{
			ThrowError("Failed to read function from game configuration file");
		}
		func = EndPrepSDKCall();

		if(func == INVALID_HANDLE)
		{
			ThrowError("Failed to end prep sdk call");
		}

		init = true;
	}

	SDKCall(func);
	DebugPrintToAll("CTerrorGameRules::ResetRoundNumber()");
}

L4D_SetRoundEndTime(Float:endTime)
{
	static bool:init = false;
	static Handle:func = INVALID_HANDLE;
	if(!init)
	{
		new Handle:conf = LoadGameConfigFile(GAMECONFIG_FILE);
		if(conf == INVALID_HANDLE)
		{
			LogError("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
			DebugPrintToAll("Could not load gamedata/%s.txt", GAMECONFIG_FILE);
		}

		StartPrepSDKCall(SDKCall_GameRules);
		new bool:readConf = PrepSDKCall_SetFromConf(conf, SDKConf_Signature, "CTerrorGameRules_SetRoundEndTime");
		if(!readConf)
		{
			ThrowError("Failed to read function from game configuration file");
		}
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		func = EndPrepSDKCall();

		if(func == INVALID_HANDLE)
		{
			ThrowError("Failed to end prep sdk call");
		}

		init = true;
	}

	SDKCall(func, endTime);
	DebugPrintToAll("CTerrorGameRules::SetRoundTime(%f)", endTime);
}
#endif

UnfreezeAllPlayers()
{
	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if (IsClientInGame(i) && L4D2Team:GetClientTeam(i) != L4D2Team_Spectators)
		{
			#if READY_DEBUG
			decl String:curname[128];
			GetClientName(i,curname,128);
			DebugPrintToAll("[DEBUG] Unfreezing %s [%d] during UnfreezeAllPlayers().", curname, i);
			#endif

			ToggleFreezePlayer(i, false);
		}
	}
}

//make everyone un-ready, but don't actually freeze them
compOn()
{
	DebugPrintToAll("compOn() called");

	goingLive = 0;
	readyMode = false;
	forcedStart = 0;

	for (new i = 1; i <= MAXPLAYERS; i++) readyStatus[i] = 0;
}

//abort an impending countdown to a live match
public Action:Command_Abort(client, args)
{
	if (!goingLive)
	{
		ReplyToCommand(0, "L4DC: Nothing to abort.");
		return Plugin_Handled;
	}

	if (goingLive)
	{
		KillTimer(liveTimer);
		forcedStart = 0;
		goingLive = 0;
	}

	PrintHintTextToAll("Match was aborted by command.");

	return Plugin_Handled;
}

//begin the ready mode (everyone now needs to ready up before they can move)
public Action:compReady(client, args)
{
	if (goingLive)
	{
		ReplyToCommand(0, "[L4D RUP] Already going live, ignoring.");
		return Plugin_Handled;
	}

	compOn();
	readyOn();

	return Plugin_Handled;
}

//force start a match using admin
public Action:Command_Start(client, args)
{
	if(!readyMode)
		return Plugin_Handled;

	if (goingLive)
	{
		ReplyToCommand(0, "[L4D RUP] Already going live, ignoring.");
		return Plugin_Handled;
	}

	goingLive = READY_LIVE_COUNTDOWN;
	forcedStart = 1;
	liveTimer = CreateTimer(1.0, timerLiveCountCallback, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Handled;
}

//restart the map when we toggle the cvar
public ConVarChange_ReadyEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);

		if(value)
		{
			//if sv_search_key is "" && l4d_ready_disable_search_key is 1
			//then don't let admins turn on our plugin
			if(GetConVarInt(cvarReadySearchKeyDisable))
			{
				decl String:searchKey[128];
				GetConVarString(cvarSearchKey, searchKey, 128);

				if(!searchKey[0])
				{
					LogMessage("Ready plugin will not start while sv_search_key is \"\"");
					PrintToChatAll("[SM] Ready plugin will not start while sv_search_key is \"\"");

					ServerCommand("l4d_ready_enabled 0");
					return;
				}
			}

			PrintToChatAll("[SM] Ready plugin has been enabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
		}
		else
		{
			PrintToChatAll("[SM] Ready plugin has been disabled, restarting map in %.0f seconds", READY_RESTART_MAP_DELAY);
			readyOff();
		}
		//RestartMapDelayed();
	}
}


//disable most non-competitive plugins
public ConVarChange_ReadyCompetition(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		new value = StringToInt(newValue);

		if(value)
		{
			//TODO: use plugin iterators such as GetPluginIterator
			// to unload all plugins BUT the ones below

			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins unload_all");
			ServerCommand("sm plugins load basebans.smx");
			ServerCommand("sm plugins load basecommands.smx");
			ServerCommand("sm plugins load admin-flatfile.smx");
			ServerCommand("sm plugins load adminhelp.smx");
			ServerCommand("sm plugins load adminmenu.smx");
			ServerCommand("sm plugins load l4dscores.smx"); //IMPORTANT: load before l4dready!
			ServerCommand("sm plugins load l4dready.smx");
			ServerCommand("sm plugins load_lock");

			DebugPrintToAll("Competition mode enabled, plugins unloaded...");

			//TODO: also call sm_restartmap and sm_resetscores
			// this removes the dependency from configs to know what to do :)

			//Maybe make this command sm_competition_on, sm_competition_off ?
			//that way people will probably not use in server.cfg
			// and they can exec the command over and over and it will be fine
		}
		else
		{
			ServerCommand("sm plugins load_unlock");
			ServerCommand("sm plugins refresh");

			DebugPrintToAll("Competition mode enabled, plugins reloaded...");
		}
	}
}

//disable the ready mod if sv_search_key is ""
public ConVarChange_SearchKey(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (oldValue[0] == newValue[0])
	{
		return;
	}
	else
	{
		if(!newValue[0])
		{
			//wait about 5 secs and then disable the ready up mod

			//this gives time for l4d_ready_server_cfg to get executed
			//if a server.cfg disables the sv_search_key
			CreateTimer(5.0, Timer_SearchKeyDisabled, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

//repeatedly count down until the match goes live
public Action:Timer_SearchKeyDisabled(Handle:timer)
{
	//if sv_search_key is "" && l4d_ready_disable_search_key is 1
	//then don't let admins turn on our plugin
	if(GetConVarInt(cvarReadySearchKeyDisable) && GetConVarInt(cvarEnforceReady))
	{
		decl String:searchKey[128];
		GetConVarString(cvarSearchKey, searchKey, 128);

		if(!searchKey[0])
		{
			CPrintToChatAll("{red}[SM] sv_search_key is not set, the l4dready plugin will now automatically disable itself.");

			ServerCommand("l4d_ready_enabled 0");
			return;
		}
	}
}



#if ALLOW_TEAM_PLACEMENT
public Action:Command_SwapTeams(client, args)
{
	PrintToChatAll("[SM] Survivor and Infected teams have been swapped.");

	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) != L4D_TEAM_SPECTATE)
		{
			teamPlacementArray[i] = GetOppositeClientTeam(i);
		}
	}

	TryTeamPlacementDelayed();

	return Plugin_Handled;
}

public Action:Command_Swap(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swap <player1> [player2] ... [playerN] - swap all listed players to opposite teams");
		return Plugin_Handled;
	}

	new player_id;
	decl String:player[64];

	for(new i; i < args; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);

		if(player_id == -1)
			continue;

		new team = GetOppositeClientTeam(player_id);
		teamPlacementArray[player_id] = team;
		//CPrintToChatAll("[SM]{blue} %N {default}has been swapped to the{blue} %s {default}team.", player_id, L4D_TEAM_NAME(team));
	}

	TryTeamPlacement();

	return Plugin_Handled;
}


public Action:Command_SwapTo(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_swapto <player1> [player2] ... [playerN] <teamnum> - swap all listed players to team <teamnum> (1,2,or 3)");
		return Plugin_Handled;
	}

	new team;
	decl String:teamStr[64];
	GetCmdArg(args, teamStr, sizeof(teamStr));
	team = StringToInt(teamStr);
	if(!team)
	{
		ReplyToCommand(client, "[SM] Invalid team %s specified, needs to be 1, 2, or 3", teamStr);
		return Plugin_Handled;
	}

	new player_id;
	decl String:player[64];

	for(new i; i < args - 1; i++)
	{
		GetCmdArg(i+1, player, sizeof(player));
		player_id = FindTarget(client, player, true /*nobots*/, false /*immunity*/);

		if(player_id == -1)
			continue;

		teamPlacementArray[player_id] = team;
		//CPrintToChatAll("[SM]{blue} %N {default}has been swapped to the{blue} %s {default}team.", player_id, L4D_TEAM_NAME(team));
	}

	TryTeamPlacement();

	return Plugin_Handled;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	TryTeamPlacementDelayed();
}

/*
* Do a delayed "team placement"
*
* This way all the pending team changes will go through instantly
* and we don't end up in TryTeamPlacement again before then
*/
new bool:pendingTryTeamPlacement;
TryTeamPlacementDelayed()
{
	if(!pendingTryTeamPlacement)
	{
		CreateTimer(SCORE_DELAY_PLACEMENT, Timer_TryTeamPlacement);
		pendingTryTeamPlacement = true;
	}
}

public Action:Timer_TryTeamPlacement(Handle:timer)
{
	TryTeamPlacement();
	pendingTryTeamPlacement = false;
}

/*
* Try to place people on the right teams
* after some kind of event happens that allows someone to be moved.
*
* Should only be called indirectly by TryTeamPlacementDelayed()
*/
TryTeamPlacement()
{
	/*
	* Calculate how many free slots a team has
	*/
	new free_slots[4];

	free_slots[L4D_TEAM_SPECTATE] = GetTeamMaxHumans(L4D_TEAM_SPECTATE);
	free_slots[L4D_TEAM_SURVIVORS] = GetTeamMaxHumans(L4D_TEAM_SURVIVORS);
	free_slots[L4D_TEAM_INFECTED] = GetTeamMaxHumans(L4D_TEAM_INFECTED);

	free_slots[L4D_TEAM_SURVIVORS] -= GetTeamHumanCount(L4D_TEAM_SURVIVORS);
	free_slots[L4D_TEAM_INFECTED] -= GetTeamHumanCount(L4D_TEAM_INFECTED);

	DebugPrintToAll("TP: Trying to do team placement (free slots %d/%d)...", free_slots[L4D_TEAM_SURVIVORS], free_slots[L4D_TEAM_INFECTED]);

	/*
	* Try to place people on the teams they should be on.
	*/

	decl String:authid[96];
	new anyval;

	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			new team = teamPlacementArray[i];

			//client was not manually placed? then check...
			if(!team)
			{
				GetClientAuthString(i, authid, sizeof(authid));
				//if client was a spectator before and should go there again.
				if (GetTrieValue(teamPlacementTrie, authid, anyval))
				{
					DebugPrintToAll("TP: %N was spectator before and will be put there again.", i);

					team = L4D_TEAM_SPECTATE;
					// also scratch their info from the Trie to avoid repetition effects
					RemoveFromTrie(teamPlacementTrie, authid);
				}
				// in any other case theres nothing to do
				else
				{
					continue;
				}
			}

			new old_team = GetClientTeam(i);

			//client is already on the right team
			if(team == old_team)
			{
				teamPlacementArray[i] = 0;
				teamPlacementAttempts[i] = 0;

				DebugPrintToAll("TP: %N is already on correct team (%d)", i, team);
			}
			//there's still room to place him on the right team
			else if (free_slots[team] > 0)
			{
				ChangePlayerTeamDelayed(i, team);
				DebugPrintToAll("TP: Moving %N to %d soon", i, team);

				free_slots[team]--;
				free_slots[old_team]++;
			}
			/*
			* no room to place him on the right team,
			* so lets just move this person to spectate
			* in anticipation of being to move him later
			*/
			else
			{
				DebugPrintToAll("TP: %d attempts to move %N to team %d", teamPlacementAttempts[i], i, team);

				/*
				* don't keep playing in an infinite join spectator loop,
				* let him join another team if moving him fails
				*/
				if(teamPlacementAttempts[i] > 0)
				{
					DebugPrintToAll("TP: Cannot move %N onto %d, team full", i, team);

					//client joined a team after he was moved to spec temporarily
					if(GetClientTeam(i) != L4D_TEAM_SPECTATE)
					{
						DebugPrintToAll("TP: %N has willfully moved onto %d, cancelling placement", i, GetClientTeam(i));
						teamPlacementArray[i] = 0;
						teamPlacementAttempts[i] = 0;
					}
				}
				/*
				* place him to spectator so room on the previous team is available
				*/
				else
				{
					free_slots[L4D_TEAM_SPECTATE]--;
					free_slots[old_team]++;

					DebugPrintToAll("TP: Moved %N to spectator, as %d has no room", i, team);

					ChangePlayerTeamDelayed(i, L4D_TEAM_SPECTATE);

					teamPlacementAttempts[i]++;
				}
			}
		}
		//the player is a bot, or disconnected, etc.
		else
		{
			if(!IsClientInGame(i) || IsFakeClient(i))
			{
				if(teamPlacementArray[i])
					DebugPrintToAll("TP: Defaultly removing %d from placement consideration", i);

				teamPlacementArray[i] = 0;
				teamPlacementAttempts[i] = 0;
			}
		}
	}

	/* If somehow all 8 players are connected and on opposite teams
	*  then unfortunately this function will not work.
	*  but of course this should not be called in that case,
	*  instead swapteams can be used
	*/
}


/*
* Saves the annoying crowd of Spectators into a Trie so they dont get sorted into a team
* next map.
*/
SaveSpectators()
{
	ClearTrie(teamPlacementTrie);
	decl String:authid[96];
	for(new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			if (GetClientTeam(i) == L4D_TEAM_SPECTATE)
			{
				GetClientAuthString(i, authid, sizeof(authid));
				SetTrieValue(teamPlacementTrie, authid, L4D_TEAM_SPECTATE);
			}
		}
	}
}

ChangePlayerTeamDelayed(client, team)
{
	new Handle:pack;

	CreateDataTimer(SCORE_DELAY_TEAM_SWITCH, Timer_ChangePlayerTeam, pack);

	WritePackCell(pack, client);
	WritePackCell(pack, team);
}

public Action:Timer_ChangePlayerTeam(Handle:timer, Handle:pack)
{
	ResetPack(pack);

	new client = ReadPackCell(pack);
	new team = ReadPackCell(pack);

	ChangePlayerTeam(client, team);
}
#endif





bool:ChangePlayerTeam(client, team)
{
	if(GetClientTeam(client) == team) return true;

	if(team != L4D_TEAM_SURVIVORS)
	{
		//we can always swap to infected or spectator, it has no actual limit
		ChangeClientTeam(client, team);
		return true;
	}

	if(GetTeamHumanCount(team) == GetTeamMaxHumans(team))
	{
		DebugPrintToAll("ChangePlayerTeam() : Cannot switch %N to team %d, as team is full");
		return false;
	}

	//for survivors its more tricky
	new bot;

	for(bot = 1;
		bot < L4D_MAXCLIENTS_PLUS1 && (!IsClientInGame(bot) || !IsFakeClient(bot) || (GetClientTeam(bot) != L4D_TEAM_SURVIVORS));
		bot++) {}

	if(bot == L4D_MAXCLIENTS_PLUS1)
	{
		DebugPrintToAll("Could not find a survivor bot, adding a bot ourselves");

		CheatCmd(0, "sb_add");

		DebugPrintToAll("Added a survivor bot, trying again...");
		return false;
	}

	//have to do this to give control of a survivor bot
	SDKCall(fSHS, bot, client);
	SDKCall(fTOB, client, true);

	return true;
}

//round_start just after the last automatic restart
RoundIsLive()
{
	UnfreezeAllPlayers();

	if(GetConVarBool(cvarDisableReadySpawns))
	{
		ResetConVar(FindConVar("director_no_specials"));
	}

	#if !L4D
		L4D2_CTimerStart(L4D2CT_VersusStartTimer, GetConVarFloat(FindConVar("versus_force_start_time")));
	#endif

	Call_StartForward(fwdOnRoundIsLive);
	Call_Finish();

	CreateTimer(1.0, timerLiveMessageCallback, _, _);
}

ToggleFreezePlayer(client, freeze)
{
	new iFlags = GetEntityFlags(client);

	if (freeze && !(iFlags & FL_ATCONTROLS)){

		DebugPrintToAll("%N freezed!", client);
		SetEntityFlags(client, (iFlags |= FL_ATCONTROLS));
	}
	else if (!freeze && iFlags & FL_ATCONTROLS){

		DebugPrintToAll("%N unfreezed!", client);
		SetEntityFlags(client, (iFlags &= ~FL_ATCONTROLS));
	}
}

public PersistentTeam:GetClientPersistentTeam(client)
{
	return GetL4D2TeamPersistentTeam(L4D2Team:GetClientTeam(client));
}

public PersistentTeam:GetL4D2TeamPersistentTeam(L4D2Team:team)
{
	if (team == L4D2Team_Unknown || team == L4D2Team_Spectators)
	{
		return PersistentTeam_Invalid;
	}
	if ((defaultTeams && !isSecondRound) || (!defaultTeams && isSecondRound))
	{
		if (team == L4D2Team_Survivors)
		{
			return PersistentTeam_A;
		}
		else
		{
			return PersistentTeam_B;
		}
	}
	else
	{
		if (team == L4D2Team_Survivors)
		{
			return PersistentTeam_B;
		}
		else
		{
			return PersistentTeam_A;
		}
	}
}

TeamAttemptPause(client)
{
	static iPauses[PersistentTeam];
	if (isNewCampaign)
	{
		iPauses[PersistentTeam_A] = 0;
		iPauses[PersistentTeam_B] = 0;
		isNewCampaign = false;
	}
	if (iPauses[GetClientPersistentTeam(client)] >= GetConVarInt(cvarPausesAllowed))
	{
		ReplyToCommand(client, "[SM] Your team does not have any pauses remaining for this campaign");
		return false;
	}
	iPauses[GetClientPersistentTeam(client)]++;
	CPrintToChatAll("[SM] {red}%N{default} has paused the game. Their team has {red}%d{default} pauses remaining for this campaign", client, GetConVarInt(cvarPausesAllowed) - iPauses[GetClientPersistentTeam(client)]);
	PauseGame(client);
	return true;
}

ClientAttemptsPause(client)
{
	new team = GetClientTeam(client);
	if(!(team == L4D_TEAM_INFECTED || team == L4D_TEAM_SURVIVORS) || !GetConVarInt(cvarPausesAllowed) || readyMode || isPaused)
	{
		return;
	}
	if (TeamAttemptPause(client))
	{
		lastTeamPause = team;
	}
}

ClientAttemptsUnpause(client)
{
	new team = GetClientTeam(client);
	if(!(team == L4D_TEAM_INFECTED || team == L4D_TEAM_SURVIVORS) || !GetConVarInt(cvarPausesAllowed) || !isPaused || isUnpausing || readyMode)
	{
		return;
	}
	if (team == lastTeamPause || canUnpause)
	{
		CPrintToChatAll("[SM] {blue}%N{default} has unpaused the game.\nGame is going live in {blue}%d{default} seconds...", client, L4D_UNPAUSE_DELAY);
		UnpauseGameDelay(client);
		return;
	}
	ReplyToCommand(client, "[SM]Your team can not unpause at this time");
}

ToogleAntiFlood(bool:disable)
{
	new Handle:hFloodtime = FindConVar("sm_flood_time");
	if (hFloodtime != INVALID_HANDLE){

		if (disable)
			SetConVarFloat(hFloodtime, 0.0);
		else
			ResetConVar(hFloodtime);
	}
}

public nativeIsGamePaused(Handle:plugin, numParams)
{
	return isPaused;
}

PauseGame(any:client)
{
	ToogleAntiFlood(true);
	isPaused = true;
	canUnpause = false;
	iInitialAllTalk = GetConVarInt(FindConVar("sv_alltalk"));
	SetConVarInt(FindConVar("sv_alltalk"), 1);
	//0.2s-delay fixes the issue with alltalk enabling
	CreateTimer(0.2, PauseGameDelayed, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:PauseGameDelayed(Handle:timer, any:client)
{
	if ((client<=0) || (!IsClientInGame(client))) //If player leaved during 0.2 sec
	{
		client = GetAnyClient();
	}
	SetConVarInt(FindConVar("sv_pausable"), 1); //Ensure sv_pausable is set to 1
	FakeClientCommand(client, "setpause"); //Send pause command
	SetConVarInt(FindConVar("sv_pausable"), 0); //Reset sv_pausable back to 0

	if (!IsInAlterPause())
		timerMinimumPause = CreateTimer(GetConVarFloat(cvarPauseDuration), AllCanUnpause, _, TIMER_FLAG_NO_MAPCHANGE);
	else {

		canUnpause = true;
		Command_ToReady(0, 0);
	}
}
bool:IsInAlterPause()
{
	return isPaused && GetConVarBool(cvarPauseMetod);
}

UnpauseGame(any:client)
{
	if ((client<=0) || (!IsClientInGame(client)))
	{
		client = GetAnyClient();
	}

	ToogleAntiFlood(false);
	isPaused = false;
	SetConVarInt(FindConVar("sv_pausable"), 1); //Ensure sv_pausable is set to 1
	FakeClientCommand(client, "unpause"); //Send unpause command
	SetConVarInt(FindConVar("sv_pausable"), 0); //Reset sv_pausable back to 0
	SetConVarInt(FindConVar("sv_alltalk"), iInitialAllTalk);
	if (!canUnpause)
	{
		KillTimer(timerMinimumPause);
		canUnpause = true;
	}
}

public Action:UnPauseCountDown(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	static Countdown = L4D_UNPAUSE_DELAY-1;
	//new timeslooped = RoundToCeil(GetGameTime())-ReadPackCell(pack);
	if (Countdown <= 0)
	{
		PrintHintTextToAll("Game is LIVE");
		isUnpausing = false;
		Countdown = L4D_UNPAUSE_DELAY-1;
		UnpauseGame(ReadPackCell(pack));

		return Plugin_Stop;
	}

	CPrintToChatAll("Going live in {blue}%d{default} seconds", Countdown);
	if (Countdown >= L4D_UNPAUSE_DELAY-1 || !isUnpausing)
		isUnpausing = true;
	Countdown--;

	return Plugin_Continue;
}

UnpauseGameDelay(client)
{
	isUnpausing = true;
	new Handle:pack;
	CreateDataTimer(1.0, UnPauseCountDown, pack, TIMER_REPEAT);
	//WritePackCell(pack, RoundToCeil(GetGameTime()));
	WritePackCell(pack, client);
}

public Action:AllCanUnpause(Handle:timer)
{
	if (isPaused)
	{
		canUnpause = true;
		PrintToChatAll("[SM] The required minimum pause time has elapsed. Either team can now unpause the game");
	}
	return Plugin_Stop;
}


CountInGameHumans()
{
	new i, realPlayers = 0;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i))
		{
			realPlayers++;
		}
	}
	return realPlayers;
}


#if ALLOW_TEAM_PLACEMENT
// Return the opposite team of that the client is on
GetOppositeClientTeam(client)
{
	return OppositeCurrentTeam(GetClientTeam(client));
}

OppositeCurrentTeam(team)
{
	if(team == L4D_TEAM_INFECTED)
		return L4D_TEAM_SURVIVORS;
	else if(team == L4D_TEAM_SURVIVORS)
		return L4D_TEAM_INFECTED;
	else if(team == L4D_TEAM_SPECTATE)
		return L4D_TEAM_SPECTATE;

	else
		return -1;
}
#endif

GetTeamHumanCount(team)
{
	new humans = 0;

	new i;
	for(i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
	{
		if(IsClientInGameHuman(i) && GetClientTeam(i) == team)
		{
			humans++;
		}
	}

	return humans;
}

GetTeamMaxHumans(team)
{
	if(team == L4D_TEAM_SURVIVORS)
	{
		return GetConVarInt(FindConVar("survivor_limit"));
	}
	else if(team == L4D_TEAM_INFECTED)
	{
		return GetConVarInt(FindConVar("z_max_player_zombies"));
	}
	else if(team == L4D_TEAM_SPECTATE)
	{
		return L4D_MAXCLIENTS;
	}

	return -1;
}

GetAnyClient()
{
	for (new i = 1; i < L4D_MAXCLIENTS_PLUS1; i++)
		if (IsClientInGameHuman(i))
			return i;

	return 0;
}
//client is in-game and not a bot
bool:IsClientInGameHuman(client)
{
	return IsClientInGame(client) && !IsFakeClient(client);
}

bool:IsClientCaster(client)
{
	decl String:authid[96];
	new dummy;
	GetClientAuthString(client, authid, sizeof(authid));

	if (GetTrieValue(casterTrie, authid, dummy))
		return true;

	return false;
}

bool:IsTargetL4D2()
{
	decl String:gameFolder[32];
	GetGameFolderName(gameFolder, sizeof(gameFolder));
	return StrContains(gameFolder, "left4dead") != -1;
}

bool:IsScavengeMode()
{
	decl String:sGameMode[32];
	GetConVarString(cvarGameMode, sGameMode, sizeof(sGameMode));
	return StrContains(sGameMode, "scavenge") > -1;
}

CheatCmd(client, const String:sCommand[])
{
	new iFlag = GetCommandFlags(sCommand);

	if (!SetCommandFlags(sCommand, iFlag & ~FCVAR_CHEAT)) return;

	if (client)
		FakeClientCommand(client, sCommand);
	else
		ServerCommand(sCommand);

	SetCommandFlags(sCommand, iFlag);
}

RUP_SetupSignature()
{
	// Team swapping SDK calls
	new Handle:hGameConf = LoadGameConfigFile(GAMECONFIG_FILE);

	if (hGameConf == INVALID_HANDLE)
		SetFailState("Unable to load gamedata/%s", GAMECONFIG_FILE);

	StartPrepSDKCall(SDKCall_Player);

	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec")){

		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);

		if ((fSHS = EndPrepSDKCall()) == INVALID_HANDLE)
				SetFailState("EndPreSDKCall SetHumanSpec is fail");
	}
	else
		SetFailState("Unable to find SetHumanSpec signatures");

	StartPrepSDKCall(SDKCall_Player);

	if (PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TakeOverBot")){

		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);

		if ((fTOB = EndPrepSDKCall()) == INVALID_HANDLE)
				SetFailState("EndPreSDKCall TakeOverBot is fail");
	}
}

DebugPrintToAll(const String:format[], any:...)
{
#if READY_DEBUG	|| READY_DEBUG_LOG
	decl String:buffer[192];

	VFormat(buffer, sizeof(buffer), format, 2);

#if READY_DEBUG
	PrintToChatAll("[READY] %s", buffer);
#endif
	LogMessage("%s", buffer);
#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
#endif
}