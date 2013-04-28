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

#define		AL_TAG		"[AutoLoader]"

#define		RESETTIME		15.0

static const String:sMapList[][] =
{
	"l4d_vs_hospital01_apartment",
	//"l4d_garage01_alleys", // who cares?
	"l4d_vs_airport01_greenhouse",
	"l4d_vs_smalltown01_caves",
	"l4d_vs_farm01_hilltop",
	"l4d_river01_docks"
};

static 		Handle:g_hAllowLoader, Handle:g_fwdOnServerEmpty, Handle:g_hResetTimer;

_AutoLoader_OnPluginStart()
{
	g_fwdOnServerEmpty = CreateGlobalForward("R2comp_OnServerEmpty", ET_Ignore);

	DebugLog("%s Rotoblin 2 competitive mode started :3", AL_TAG);

	g_hAllowLoader		= CreateConVarEx("allow_autoloader", "", "Allow autoloader");

	ExecuteScritp(sMatchCfg[SETTINGS]);
}

_AL_OnPluginEnd()
{
	ResetConVar(g_hAllowLoader);
}

public _AutoLoader_OnAllPluginsLoaded()
{
	DebugLog("%s _AutoLoader_OnAllPluginsLoaded", AL_TAG);
	CreateTimer(0.5, AL_t_Delay);
}

public Action:AL_t_Delay(Handle:timer)
{
	decl String:sReqMatch[48];
	GetConVarString(g_hAllowLoader, sReqMatch, 48);

	if (!IsMatchExists(sReqMatch)){

		DebugLog("%s Autoloader is disable", AL_TAG);
		CmdResetMatch(0, 0);
		return;
	}
	DebugLog("%s Autoloader is enabled", AL_TAG);

	strcopy(sMatchName, 48, sReqMatch);
	PreLoadMatch();
}

ExecuteScritp(const String:sBuffer[])
{
	if (!strlen(sBuffer)) return;

	DebugLog("%s exec %s", AL_TAG, sBuffer);
	ServerCommand("exec %s", sBuffer);
}

_AL_OnClientDisconnect(client)
{
	if (!IsFakeClient(client)){

		if (g_hResetTimer != INVALID_HANDLE){
		
			KillTimer(g_hResetTimer);
			DebugLog("%s Timer killed. hndl %x", AL_TAG, g_hResetTimer);
		}

		g_hResetTimer = CreateTimer(RESETTIME, AL_t_ResetWhenEmpty);
		DebugLog("%s Client %L leave. Timer created. hndl %x", AL_TAG, client, g_hResetTimer);
	}
}

public Action:AL_t_ResetWhenEmpty(Handle:timer)
{
	g_hResetTimer = INVALID_HANDLE;

	if (IsClientsOnServer()) return;

	Call_StartForward(g_fwdOnServerEmpty);
	Call_Finish();

	DebugLog("%s Server is empty!", AL_TAG);
	LogMessage("Server becomes empty. Map reseted by r2compmod plugin.");

	new iMapIndex = GetRandomInt(0, sizeof(sMapList) - 1);
	
	if (IsMapValid(sMapList[iMapIndex]))
		ForceChangeLevel(sMapList[iMapIndex], "R2: Server is empty");

	CreateTimer(5.0, AL_t_Delay);
}

static bool:IsClientsOnServer()
{
	for (new i = 1; i <= MaxClients;  i++)
		if (IsClientConnected(i) && !IsFakeClient(i))
			return true;

	return false;
}
