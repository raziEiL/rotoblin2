/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.AntiScrabble.sp
 *  Type:			Module
 *  Credits:		Scratchy (Idea)
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

#define AS_TAG				"[Anti-Scrabble]"

static	Handle:g_hTrine, Handle:g_hCvarNotify, Handle:g_hCvarEnable, bool:g_bCvarASEnable, bool:g_bCheked[MAXPLAYERS+1], bool:g_bJoinTeamUsed[MAXPLAYERS+1],
		g_iFailureCount[MAXPLAYERS+1], bool:g_bMapTranslition, bool:g_bTeamLock, g_isOldTeamFlipped, g_isNewTeamFlipped, g_iTrineSize;

_AntiScrabble_OnPluginStart()
{
	g_hTrine = CreateTrie();

	g_hCvarNotify = CreateConVarEx("anti_scrabble_notify", "0", "Enable/disable notification.", _, true, 0.0, true, 1.0);
	g_hCvarEnable = CreateConVarEx("allow_anti_scrabble", "0", "Enable/disable anti-scrabble", _, true, 0.0, true, 1.0);

	#if SCORES_COMMAND
		RegConsoleCmd("sm_scores", Command_Scores);
	#endif

	RegAdminCmd("sm_keepteams", Command_KeepTeams, ADMFLAG_ROOT, "Force to keep all teams right now.");
}

_AS_OnPluginEnd()
{
	ResetConVar(g_hCvarNotify);
	ResetConVar(g_hCvarEnable);
}

_AS_OnPluginEnabled()
{
	if (!(g_bCvarASEnable = GetConVarBool(g_hCvarEnable))){

		DebugLog("%s Anti-Scrabble is disable", AS_TAG);
		return;
	}

	DebugLog("%s Anti-Scrabble is enable", AS_TAG);

	HookEvent("round_end", AS_ev_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("vote_passed", AS_ev_VotePassed);

	AddCommandListener(AS_cmdh_JoinTeam, "jointeam");
}

_AS_OnPluginDisabled()
{
	if (!g_bCvarASEnable) return;

	UnhookEvent("round_end", AS_ev_RoundEnd, EventHookMode_PostNoCopy);
	UnhookEvent("vote_passed", AS_ev_VotePassed);

	RemoveCommandListener(AS_cmdh_JoinTeam, "jointeam");
}

#if SCORES_COMMAND
static g_iCampaignScores[2], bool:g_bTempBlock;

public Action:Command_Scores(client, args)
{
	if (IsPluginEnabled() && g_bCvarASEnable){

		new bTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");

		ReplyToCommand(client, "Survivors: %d. Infected: %d. (Diff: %d)", g_iCampaignScores[bTeamFlipped], g_iCampaignScores[!bTeamFlipped], g_iCampaignScores[bTeamFlipped] - g_iCampaignScores[!bTeamFlipped]);
	}

	return Plugin_Handled;
}

static ClearCampaingScores()
{
	g_iCampaignScores[0] = 0;
	g_iCampaignScores[1] = 0;
}

public Action:AS_t_TempRoundEndBlock(Handle:timer)
{
	g_bTempBlock = false;
}
#endif

public Action:Command_KeepTeams(client, args)
{
	AS_KeepTeams();

	return Plugin_Handled;
}

public Action:AS_cmdh_JoinTeam(client, const String:command[], argc)
{
	if (g_bTeamLock && !g_bJoinTeamUsed[client]){

		if (StrEqual(command, "jointeam 1"))
			return Plugin_Continue;

		#if UNSCRABBLE_LOG
			LogMessage("%N use '%s' cmd, but blocked!", client, command);
		#endif

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:AS_ev_VotePassed(Handle:event, const String:sName[], bool:DontBroadCast)
{
	decl String:sDetals[128];
	GetEventString(event, "details", sDetals, 128);

	if (StrEqual(sDetals, "#L4D_vote_passed_mission_change"))
		AS_KeepTeams();
}

public Action:OnLogAction(Handle:source, Identity:ident, client, target, const String:message[])
{
	if (IsPluginEnabled() && g_bCvarASEnable && StrContains(message, "changed map to") != -1)
		AS_KeepTeams();
}

/*
 * ---------------------------
 *		R2 Compmod forwards
 * ---------------------------
*/
public R2comp_OnMatchStarts(const String:match[])
{
	AS_KeepTeams();

	#if SCORES_COMMAND
		ClearCampaingScores();
	#endif
}

public R2comp_OnServerEmpty()
{
	ClearTrie(g_hTrine);
}

public L4DReady_OnRoundIsLive()
{
	g_bTeamLock = false;
}
// ---- ;

_AS_OnMapStart()
{
	#if SCORES_COMMAND
		if (IsNewMission())
			ClearCampaingScores();
	#endif

	g_bMapTranslition = false;

	if (!g_iTrineSize) return;

	g_bTeamLock = true;

	PrecacheModel("models/survivors/survivor_manager.mdl", true);
	PrecacheModel("models/survivors/survivor_biker.mdl", true);
	PrecacheModel("models/survivors/survivor_teenangst.mdl", true);
	PrecacheModel("models/survivors/survivor_namvet.mdl", true);

	CreateTimer(0.5, AS_t_TeamsFlipped);
	CreateTimer(5.0, AS_t_CheckConnected, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(60.0, AS_t_AllowTeamChanges, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:AS_t_TeamsFlipped(Handle:timer)
{
	g_isNewTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
}

public Action:AS_ev_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
#if SCORES_COMMAND
	if (!g_bTempBlock){

		g_bTempBlock = true;
		CreateTimer(15.0, AS_t_TempRoundEndBlock);

		new bTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
		new iScores = GameRules_GetProp("m_iSurvivorScore", _, bTeamFlipped);
		g_iCampaignScores[bTeamFlipped] += iScores;
	}
#endif

	if (GameRules_GetProp("m_bInSecondHalfOfRound") && !g_bMapTranslition)
		AS_KeepTeams();
}

static AS_KeepTeams()
{
	if (!g_bCvarASEnable) return;

	g_bMapTranslition = true;
	g_isOldTeamFlipped = GameRules_GetProp("m_bAreTeamsFlipped");
	ClearTrie(g_hTrine);

	decl bool:bInGame, String:sSteamID[32], iTeam;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (((!(bInGame = IsClientInGame(i)) && IsClientConnected(i)) || bInGame) && !IsFakeClient(i))
		{
			if (GetClientAuthString(i, sSteamID, 32))
			{
				iTeam = 1;

				if (bInGame){

					iTeam = GetClientTeam(i);

					if (!iTeam)
						iTeam = 1;
				}

				SetTrieValue(g_hTrine, sSteamID, iTeam);

				#if UNSCRABBLE_LOG
					LogMessage("team %d. %N (%s)", iTeam, i, sSteamID);
				#endif
			}
		}
	}

	g_iTrineSize = GetTrieSize(g_hTrine);
}

_AS_OnClientPutInServer(client)
{
	if (g_bTeamLock && !IsFakeClient(client)){

		g_bCheked[client] = true;
		g_iFailureCount[client] = 0;
		CreateTimer(1.0, AS_t_UnscrabbleMe, client, TIMER_REPEAT);
	}
}

public Action:AS_t_UnscrabbleMe(Handle:timer, any:client)
{
	if (!g_bTeamLock || !IsClientInGame(client)){

		g_bCheked[client] = false;
		return Plugin_Stop;
	}

	new iCTeam = GetClientTeam(client);

	if (!iCTeam)
		return Plugin_Continue;

	decl String:sSteamID[32], iLTeam;
	GetClientAuthString(client, sSteamID, 32);

	if (GetTrieValue(g_hTrine, sSteamID, iLTeam)){

		new iNTeam = iLTeam;

		if (IsTeamSwapped()){

			switch (iLTeam){

				case 2:
					iNTeam = 3;
				case 3:
					iNTeam = 2;
			}
		}

		if (iCTeam != iNTeam)
		{
			if (iCTeam != 1)
				ChangeClientTeam(client, 1);

			// we dont use sdk call's
			g_bJoinTeamUsed[client] = true;
			FakeClientCommand(client, "jointeam %d", iNTeam);
			g_bJoinTeamUsed[client] = false;
		}

		#if UNSCRABBLE_LOG
			LogMessage("%N (%s). Teams: last %d, current %d. Moved to %d (%s).", client, sSteamID, iLTeam, iCTeam, iNTeam, GetClientTeam(client) == iNTeam ? "Okay" : "Fail");
		#endif

		if (GetClientTeam(client) != iNTeam){

			if (++g_iFailureCount[client] >= UNSCRABBLE_MAX_FAILURE){

				g_bCheked[client] = false;
				return Plugin_Stop;
			}

			return Plugin_Continue;
		}
		else if (--g_iTrineSize == 0){

			#if UNSCRABBLE_LOG
				LogMessage("Trine is empty. Unlock 'jointeam' cmd");
			#endif

			ForceToUnlockTeams();
		}
	}
	else if (iCTeam != 1){

		ChangeClientTeam(client, 1);

		#if UNSCRABBLE_LOG
			LogMessage("%N (%s). Unknown client. Moved to 1", client, sSteamID);
		#endif
	}

	g_bCheked[client] = false;

	return Plugin_Stop;
}

public Action:AS_t_AllowTeamChanges(Handle:timer)
{
	#if UNSCRABBLE_LOG
		LogMessage("Time is up (60sec). Force to unlock 'jointeam' cmd");
	#endif

	ForceToUnlockTeams();
}

public Action:AS_t_CheckConnected(Handle:timer)
{
	if (!g_iTrineSize)
		return Plugin_Stop;

	if (IsUnscrabbleComplete()){

		#if UNSCRABBLE_LOG
			LogMessage("Last client connected. Unlock 'jointeam' cmd");
		#endif

		ForceToUnlockTeams();

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

static ForceToUnlockTeams()
{
	if (!g_bTeamLock) return;

	if (GetConVarBool(g_hCvarNotify))
		PrintToChatAll("\x03Unscrabble complited. Change of team is allowed now.");

	g_bTeamLock = false;
	g_iTrineSize = 0;
}

static bool:IsTeamSwapped()
{
	return g_isOldTeamFlipped != g_isNewTeamFlipped;
}

static bool:IsUnscrabbleComplete()
{
	for (new i = 1; i <= MaxClients; i++)
		if (g_bCheked[i] || IsClientConnected(i) && !IsClientInGame(i))
			return false;

	return true;
}
