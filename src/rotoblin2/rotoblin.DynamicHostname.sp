/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.DynamicHostname.sp
 *  Type:			Module
 *  Description:	...
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

#define		DN_TAG		"[DHostName]"

static		Handle:g_hAllowDN,  Handle:g_hHostName, Handle:g_hReadyUp, String:g_sDefaultN[68], bool:g_bCvarAllowDN;

_DHostName_OnPluginStart()
{
	g_hHostName	= FindConVar("hostname");

	g_hAllowDN	=	CreateConVarEx("allow_dynamic_hostname", "0");

	HookConVarChange(g_hAllowDN, _DH_Allow_CvarChange);
}

_DN_OnPluginEnd()
{
	ResetConVar(g_hAllowDN);
}

_DN_OnPluginDisabled()
{
	if (g_bCvarAllowDN)
		ChangeServerName(g_sDefaultN);
}

_DN_OnConfigsExecuted()
{
	if (!g_bCvarAllowDN) return;

	if (!strlen(g_sDefaultN))
		GetConVarString(g_hHostName, g_sDefaultN, 68);

	if ((g_hReadyUp = FindConVar("l4d_ready_cfg_name")) == INVALID_HANDLE){

		ChangeServerName(g_sDefaultN);
		DebugLog("%s RUP ConVar l4d_ready_cfg_name no found! Change hostname to \"%s\"", DN_TAG, g_sDefaultN);
	}
	else {

		decl String:sReadyUpCfgName[128];
		GetConVarString(g_hReadyUp, sReadyUpCfgName, 128);

		if (!strlen(sReadyUpCfgName)) return;

		Format(sReadyUpCfgName, 128, "%s / %s", g_sDefaultN, sReadyUpCfgName);
		ChangeServerName(sReadyUpCfgName);
	}
}

static ChangeServerName(const String:sNewName[])
{
	SetConVarString(g_hHostName, sNewName);
	DebugLog("%s New server name \"%s\"", DN_TAG, sNewName);
}

public _DH_Allow_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_bCvarAllowDN = GetConVarBool(g_hAllowDN);

	DebugLog("%s Dynamic host name is %s", DN_TAG, g_bCvarAllowDN ? "enabled" : "disabled");
}