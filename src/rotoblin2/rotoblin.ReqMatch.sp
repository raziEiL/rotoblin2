/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.AutoLoader.sp
 *  Type:			Module
 *  Description:	Rotoblin 2 autoloader.
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

#define		RQ_TAG		"[ReqMatch]"

static 		Handle:g_hAllowReq, Handle:g_fwdOnMatchStarts;

_ReqMatch_OnPluginStart()
{
	g_fwdOnMatchStarts = CreateGlobalForward("R2comp_OnMatchStarts", ET_Ignore, Param_String);

	g_hAllowReq = CreateConVarEx("allow_match_req", "0", "Allows to team choose a match", _, true, 0.0, true, 1.0);

	RegServerCmd("rotoblin_restartmap", CmdRestartMap);

	RegAdminCmd("sm_forcematch", CmdForceMatch, ADMFLAG_KICK, "Forces the game to use match mode");
	RegAdminCmd("sm_resetmatch", CmdResetMatch, ADMFLAG_KICK, "Forces match mode to turn off");

	RegConsoleCmd("sm_match", CmdReqMatch);
	RegConsoleCmd("sm_load", CmdLoad);
}

_RM_OnPluginEnd()
{
	ResetConVar(g_hAllowReq);
}

public Action:CmdRestartMap(args)
{
	CreateTimer(1.5, AL_t_RestartMap);
}

public Action:AL_t_RestartMap(Handle:timer)
{
	decl String:sMap[64];
	GetCurrentMap(sMap, 64);
	ForceChangeLevel(sMap, "Resetting by Rotoblin 2");
}

public Action:CmdForceMatch(client, args)
{
	if (!args){

		MatchList(client);
		ReplyToCommand(client, "%s Usages: !forcematch <compmatch>", MAIN_TAG);
		return Plugin_Handled;
	}

	decl String:sReqMatch[48];
	GetCmdArg(1, sReqMatch, 48);

	if (!IsMatchExists(sReqMatch)){

		ReplyToCommand(client, "%s Required match is not found. Type !forcematch to see the available matches.", MAIN_TAG);
		return Plugin_Handled;
	}

	strcopy(sMatchName, 48, sReqMatch);

	PreLoadMatch();
	ReplyToCommand(client, "%s Match is loaded.", MAIN_TAG);

	return Plugin_Handled;
}

public Action:CmdResetMatch(client, args)
{
	ExecuteScritp(sMatchCfg[DISABLE]);
	ForceTurnOff();
	ReplyToCommand(client, "%s Match mode forced to unload!", MAIN_TAG);

	return Plugin_Handled;
}

public Action:CmdLoad(client, args)
{
	if (/*privat*/GetFeatureStatus(FeatureType_Native, "L4D_IsInMatchVoteMenu") == FeatureStatus_Available)
		return Plugin_Handled;

	ReplyToCommand(client, "%s Command is deprecated. Run match with !match command.", MAIN_TAG);

	return Plugin_Handled;
}

static bool:g_bTeamReq, String:g_sReqMatch[2][48]; // 0 - surv, 1 - inf

public Action:CmdReqMatch(client, args)
{
	decl iTeam;
	if (!client || (iTeam = GetClientTeam(client)) == 1 || /*privat*/GetFeatureStatus(FeatureType_Native, "L4D_IsInMatchVoteMenu") == FeatureStatus_Available)
		return Plugin_Handled;

	if (!GetConVarBool(g_hAllowReq)){

		ReplyToCommand(client, "%s Match request is disabled by administrator.", MAIN_TAG);
		return Plugin_Handled;
	}

	if (!args){

		MatchList(client);
		return Plugin_Handled;
	}

	decl String:sReqMatch[48];
	GetCmdArg(1, sReqMatch, 48);

	if (!IsMatchExists(sReqMatch)){

		ReplyToCommand(client, "%s Required match is not found. Type !match to see the available matches.", MAIN_TAG);
		return Plugin_Handled;
	}

	iTeam -= 2;
	if (!g_bTeamReq){

		g_bTeamReq = true;
		CreateTimer(30.0, RM_t_RejectReq, iTeam, TIMER_FLAG_NO_MAPCHANGE);
	}

	strcopy(g_sReqMatch[iTeam], 48, sReqMatch);

	if (strlen(g_sReqMatch[0]) && StrEqual(g_sReqMatch[0], g_sReqMatch[1])){

		PrintToChatAll("%s %s team confirmed '%s' match.", MAIN_TAG, !iTeam ? "Survivors" : "Infected", sReqMatch);
		DebugLog("%s %N confirmed match!", RQ_TAG, client);

		ResetReqVars();

		strcopy(sMatchName, 48, sReqMatch);
		PreLoadMatch();
	}
	else
		PrintToChatAll("%s %s team requested '%s' match.", MAIN_TAG, !iTeam ? "Survivors" : "Infected", sReqMatch);

	return Plugin_Handled;
}

public Action:RM_t_RejectReq(Handle:timer, any:team)
{
	if (!g_bTeamReq) return;

	ResetReqVars();

	PrintToChatAll("%s %s team has not confirmed the match.", MAIN_TAG, !team ? "Infected" : "Survivors");
}

static MatchList(client)
{
	static String:sMatchFolder[64];

	if (!strlen(sMatchFolder)){

		FormatEx(sMatchFolder, 64, "%s%s", sMatchCfg[CFGDIR], sMatchCfg[ROTODIR]);
		strcopy(sMatchFolder, strlen(sMatchFolder), sMatchFolder);
	}

	if (DirExists(sMatchFolder)){

		decl String:sBuffer[64];
		new Handle:hDir = OpenDirectory(sMatchFolder);
		new FileType:iFileType = FileType_Directory;
		new iCount;

		ReplyToCommand(client, " \n");
		ReplyToCommand(client, "   * List of Matches *");
		ReplyToCommand(client, "------------------------------");
		ReplyToCommand(client, "| No.   | Compmatch ");
		ReplyToCommand(client, "------------------------------");

		while (ReadDirEntry(hDir, sBuffer, 64, iFileType))
			if (StrContains(sBuffer, ".") == -1)
				ReplyToCommand(client, "| %02d.   | %s ", ++iCount, sBuffer);

		ReplyToCommand(client, "------------------------------");
		ReplyToCommand(client, "Usages: !match <compmatch>");
	}
	else {

		DebugLog("%s Error: Directory <%s> not exists!", RQ_TAG, sMatchFolder);
		ThrowError("%s Error: Directory <%s> not exists!", RQ_TAG, sMatchFolder);
	}
}

static ResetReqVars()
{
	g_bTeamReq = false;

	for (new i = 0; i < 2; i++)
		g_sReqMatch[i][0] = '\0';
}
// ===

// Reset previous match, read required configs for the current match.
PreLoadMatch()
{
	DebugLog("%s Reset previous match, read required configs for the current match.", RQ_TAG);
	//_TC_OnPluginDisabled();
	//_PM_OnPluginDisabled();
	ExecuteScritp(sMatchCfg[DISABLE]);
	BuldMatchPatch(PLUGINS);

	CreateTimer(1.0, RM_t_ReadOptionalCvars);
	CreateTimer(2.0, RM_t_CallFWD);
}

public Action:RM_t_ReadOptionalCvars(Handle:timer)
{
	CmdLockVariable(0);

	BuldMatchPatch(MAP);
	ExecuteScritp(sMatchCfg[RATES]);
	BuldMatchPatch(MATCH);
	BuldMatchPatch(MAIN);

	DebugLog("%s Successfully!", RQ_TAG);
}

public Action:RM_t_CallFWD(Handle:timer)
{
	Call_StartForward(g_fwdOnMatchStarts);
	Call_PushString(sMatchName);
	Call_Finish();
}

_RM_OnConfigsExecuted()
{
	ResetReqVars();

	if (strlen(sMatchName))
		BuldMatchPatch(MAP);
}

static BuldMatchPatch(iWhat)
{
	decl String:sFile[96];
	FormatEx(sFile, 96, "%s%s", sMatchCfg[ROTODIR], sMatchName);

	switch (iWhat){

		case MATCH:
			Format(sFile, 96, "%s/%s.cfg", sFile, sMatchName);
		case MAIN:
			Format(sFile, 96, "%s%s", sFile, sMatchCfg[MAIN]);
		case MAP:
			Format(sFile, 96, "%s%s", sFile, sMatchCfg[MAP]);
		case PLUGINS:
			Format(sFile, 96, "%s%s", sFile, sMatchCfg[PLUGINS]);
	}

	ExecuteScritp(sFile);
}

bool:IsMatchExists(const String:sReqMatch[])
{
	if (!strlen(sReqMatch) || StrContains(sReqMatch, ".") != -1 || StrContains(sReqMatch, "\"") != -1)
		return false;

	decl String:sBuildPatch[96];
	FormatEx(sBuildPatch, 96, "%s%s%s", sMatchCfg[CFGDIR], sMatchCfg[ROTODIR], sReqMatch);

	return DirExists(sBuildPatch);
}