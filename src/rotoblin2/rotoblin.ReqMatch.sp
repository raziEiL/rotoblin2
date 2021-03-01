/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.AutoLoader.sp
 *  Type:			Module
 *  Description:	Rotoblin 2 autoloader.
 *
 *  Copyright (C) 2012-2015, 2021 raziEiL [disawar1] <mr.raz4291@gmail.com>
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

static 		Handle:g_hAllowReq, Handle:g_fwdOnMatchStarts, Handle:g_fwdOnMatchStartsPre, String:g_sMap[64];

_ReqMatch_OnPluginStart()
{
	g_fwdOnMatchStarts = CreateGlobalForward("R2comp_OnMatchStarts", ET_Ignore, Param_String);
	g_fwdOnMatchStartsPre = CreateGlobalForward("R2comp_OnMatchStarts_Pre", ET_Ignore, Param_String);

	g_hAllowReq = CreateConVarEx("allow_match_req", "0", "Sets whether any player can request to change the current match mode (!match command)", _, true, 0.0, true, 1.0);

	RegServerCmd("rotoblin_restartmap", CmdRestartMap, "Restart a map with 1.5 sec delay (respect the gamemode)");

	RegAdminCmd("sm_forcematch", CmdForceMatch, ADMFLAG_KICK, "Forces the game to use match mode");
	RegAdminCmd("sm_fmatch", CmdForceMatch, ADMFLAG_KICK, "Forces the game to use match mode");
	RegAdminCmd("sm_resetmatch", CmdResetMatch, ADMFLAG_KICK, "Forces match mode to turn off");
	RegAdminCmd("sm_rtmatch", CmdResetMatch, ADMFLAG_KICK, "Forces match mode to turn off");

	RegConsoleCmd("sm_match", CmdReqMatch);
	RegConsoleCmd("sm_load", CmdLoad);
}

_RM_OnPluginEnd()
{
	ResetConVar(g_hAllowReq);
}

public Action:CmdRestartMap(args)
{
	if (args)
		GetCmdArg(1, g_sMap, 64);

	if (!args || args > 1 || !IsMapValid(g_sMap))
		g_sMap[0] = '\0';

	CreateTimer(1.5, AL_t_RestartMap);
	return Plugin_Handled;
}

public Action:AL_t_RestartMap(Handle:timer)
{
	decl String:sMap[64];

	if (strlen(g_sMap))
		strcopy(sMap, 64, g_sMap);
	else
		GetCurrentMap(sMap, 64);

	ConvertMapByGamemode(SZF(sMap));
	ForceChangeLevel(sMap, "Resetting by Rotoblin 2");
}

public Action:CmdForceMatch(client, args)
{
	if (!args){

		MatchList(client);
		ReplyToCommand(client, "%t", "R2CompMod #10");
		return Plugin_Handled;
	}

	decl String:sReqMatch[48];
	GetCmdArg(1, sReqMatch, 48);

	if (!IsMatchExists(sReqMatch)){

		ReplyToCommand(client, "%s %t", MAIN_TAG, "R2CompMod #11");
		return Plugin_Handled;
	}

	strcopy(sMatchName, 48, sReqMatch);

	PreLoadMatch();
	ReplyToCommand(client, "%s %t", MAIN_TAG, "R2CompMod #12");

	return Plugin_Handled;
}

public Action:CmdResetMatch(client, args)
{
	ExecuteScritp(sMatchCfg[DISABLE]);
	ForceTurnOff();
	ReplyToCommand(client, "%s %t", MAIN_TAG, "R2CompMod #13");

	return Plugin_Handled;
}

public Action:CmdLoad(client, args)
{
	if (/*privat*/GetFeatureStatus(FeatureType_Native, "L4D_IsInMatchVoteMenu") == FeatureStatus_Available)
		return Plugin_Handled;

	ReplyToCommand(client, "%s %t", MAIN_TAG, "R2CompMod #14");

	return Plugin_Handled;
}

static bool:g_bTeamReq, String:g_sReqMatch[2][48]; // 0 - surv, 1 - inf

public Action:CmdReqMatch(client, args)
{
	decl iTeam;
	if (!client || (iTeam = GetClientTeam(client)) == 1 || /*privat*/GetFeatureStatus(FeatureType_Native, "L4D_IsInMatchVoteMenu") == FeatureStatus_Available)
		return Plugin_Handled;

	if (!GetConVarBool(g_hAllowReq)){

		ReplyToCommand(client, "%s %t", MAIN_TAG, "R2CompMod #15");
		return Plugin_Handled;
	}

	if (!args){

		MatchList(client);
		ReplyToCommand(client, "%t", "R2CompMod #16");
		return Plugin_Handled;
	}

	decl String:sReqMatch[48];
	GetCmdArg(1, sReqMatch, 48);

	if (!IsMatchExists(sReqMatch)){

		ReplyToCommand(client, "%s %t", MAIN_TAG, "R2CompMod #17");
		return Plugin_Handled;
	}

	iTeam -= 2;
	if (!g_bTeamReq){

		g_bTeamReq = true;
		CreateTimer(30.0, RM_t_RejectReq, iTeam, TIMER_FLAG_NO_MAPCHANGE);
	}

	strcopy(g_sReqMatch[iTeam], 48, sReqMatch);

	if (strlen(g_sReqMatch[0]) && StrEqual(g_sReqMatch[0], g_sReqMatch[1])){

		PrintToChatAll("%s %t", MAIN_TAG, "R2CompMod #18", !iTeam ? "Survivors" : "Infected", sReqMatch);
		DebugLog("%s %N confirmed match!", RQ_TAG, client);

		ResetReqVars();

		strcopy(sMatchName, 48, sReqMatch);
		PreLoadMatch();
	}
	else
		PrintToChatAll("%s %t", MAIN_TAG, "R2CompMod #19", !iTeam ? "Survivors" : "Infected", sReqMatch);

	return Plugin_Handled;
}

public Action:RM_t_RejectReq(Handle:timer, any:team)
{
	if (!g_bTeamReq) return;

	ResetReqVars();

	PrintToChatAll("%s %t", MAIN_TAG, "R2CompMod #20", !team ? "Infected" : "Survivors");
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
		ReplyToCommand(client, "   * %t *", "R2CompMod #21");
		ReplyToCommand(client, "------------------------------");
		ReplyToCommand(client, "| No.   | %t ", "R2CompMod #22");
		ReplyToCommand(client, "------------------------------");

		while (ReadDirEntry(hDir, sBuffer, 64, iFileType))
			if (StrContains(sBuffer, ".") == -1)
				ReplyToCommand(client, "| %02d.   | %s ", ++iCount, sBuffer);

		ReplyToCommand(client, "------------------------------");
	}
	else {

		DebugLog("%s Error: Directory <%s> not exists!", RQ_TAG, sMatchFolder);
		ThrowError("%s Error: Directory <%s> not exists!", RQ_TAG, sMatchFolder);
	}
}

static ResetReqVars()
{
	g_bTeamReq = false;
	g_sReqMatch[0][0] = '\0';
	g_sReqMatch[1][0] = '\0';
}
// ===

// Reset previous match, read required configs for the current match.
PreLoadMatch()
{
	DebugLog("%s Reset previous match, read required configs for the current match.", RQ_TAG);

	Call_StartForward(g_fwdOnMatchStartsPre);
	Call_PushString(sMatchName);
	Call_Finish();

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
	BuldMatchPatch(CVARS);
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

static BuldMatchPatch(strPatch:iFile)
{
	decl String:sFile[96];
	FormatEx(sFile, 96, "%s%s%s", sMatchCfg[ROTODIR], sMatchName, sMatchCfg[iFile]);
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

/* 
 * coop gamemode: 
 * V l4d_vs_hospital01_apartment > l4d_hospital01_apartment
 * X l4d_garage01_alleys > l4d_garage01_alleys
 *
 * vs gamemode: 
 * X l4d_river01_docks > l4d_river01_docks
 * V l4d_hospital01_apartment > l4d_vs_hospital01_apartment
 */
static ConvertMapByGamemode(String:map[], len)
{
	decl String:sMap[64];

	if (IsVersusMode()){
		if (len > 4 && strncmp(map, "l4d_vs_", 7)){
			FormatEx(SZF(sMap), "l4d_vs_%s", map[4]);
			if (IsMapValid(sMap))
				strcopy(map, len, sMap);
		}
	}
	else if (len > 7 && !strncmp(map, "l4d_vs_", 7)){
		FormatEx(SZF(sMap), "l4d_%s", map[7]);
		if (IsMapValid(sMap))
			strcopy(map, len, sMap);
	}
}