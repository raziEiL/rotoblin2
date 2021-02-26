/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.ClientSettings.sp
 *  Type:			Module
 *  Description:	...
 *  Credits:		Most of credits goes to Confogl (http://code.google.com/p/confogl/)
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

#define CS_TAG				"[ClientSettings]"
#define CLS_CVAR_MAXLEN	64

enum CLSAction
{
	CLSA_Kick=0,
	CLSA_Log,
	CLSA_Spec
};

enum struct CLSEntry
{
	bool CLSE_hasMin;
	float CLSE_min;
	bool CLSE_hasMax;
	float CLSE_max;
	CLSAction CLSE_action;
	char CLSE_cvar[CLS_CVAR_MAXLEN];
}

static Handle:ClientSettingsArray;
static Handle:ClientSettingsCheckTimer;

_ClientSettings_OnPluginStart()
{
	ClientSettingsArray = CreateArray(sizeof(CLSEntry));
	RegConsoleCmd("rotoblin_clientsettings", _ClientSettings_Cmd, "List Client settings enforced by rotoblin");
	/* Using Server Cmd instead of admin because these shouldn't really be changed on the fly */
	RegServerCmd("rotoblin_trackclientcvar", _TrackClientCvar_Cmd, "Add a Client CVar to be tracked and enforced by rotoblin");
	RegServerCmd("rotoblin_resetclientcvars", _ResetTracking_Cmd, "Remove all tracked client cvars");
	RegServerCmd("rotoblin_startclientchecking", _StartClientChecking_Cmd, "Start checking and enforcing client cvars tracked by this plugin");
}

_CS_OnPluginDisabled()
{
	_ResetTracking_Cmd(0);
}

public Action:_CheckClientSettings_Timer(Handle:timer)
{
	EnforceAllCliSettings();
}

static EnforceAllCliSettings()
{
	for(new client = 1; client < MaxClients+1; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			EnforceCliSettings(client);
		}
	}
}

static EnforceCliSettings(client)
{
	new iArraySize = GetArraySize(ClientSettingsArray);
	if (!iArraySize) return;

	CLSEntry clsetting;
	for(new i = 0; i < iArraySize; i++)
	{
		GetArrayArray(ClientSettingsArray, i, clsetting);
		QueryClientConVar(client, clsetting.CLSE_cvar, _EnforceCliSettings_QueryReply, i);
	}
}

public _EnforceCliSettings_QueryReply(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[], any:value)
{
	if(!IsClientConnected(client) || !IsClientInGame(client) || IsClientInKickQueue(client))
	{
		// Client disconnected or got kicked already
		return;
	}

	if (result != ConVarQuery_Okay)
	{
		DebugLog("%s Couldn't set cvar %s from %L, kicked from server", CS_TAG, cvarName, client);
		KickClient(client, "CVar '%s' protected or missing! Hax?", cvarName);
		return;
	}

	new iArraySize = GetArraySize(ClientSettingsArray);
	if (!iArraySize) return;

	new Float:fCvarVal = StringToFloat(cvarValue);
	new clsetting_index = value;
	CLSEntry clsetting;
	GetArrayArray(ClientSettingsArray, clsetting_index, clsetting);

	if((clsetting.CLSE_hasMin && fCvarVal < clsetting.CLSE_min)
		|| (clsetting.CLSE_hasMax && fCvarVal > clsetting.CLSE_max))
	{
		switch (clsetting.CLSE_action)
		{
			case CLSA_Kick:
			{
				DebugLog("%s Kicking %L for bad %s value (%f). Min: %d %f Max: %d %f", \
					CS_TAG, client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
				PrintToChatAll("%s %t", MAIN_TAG, "R2CompMod #25", client, cvarName, fCvarVal);
				decl String:kickMessage[256];
				FormatEx(kickMessage, sizeof(kickMessage), "%T %s (%.2f)", "R2CompMod #26", client, cvarName, fCvarVal);
				if (clsetting.CLSE_hasMin)
					Format(kickMessage, sizeof(kickMessage), "%s, Min %.2f", kickMessage, clsetting.CLSE_min);
				if (clsetting.CLSE_hasMax)
					Format(kickMessage, sizeof(kickMessage), "%s, Max %.2f", kickMessage, clsetting.CLSE_max);
				KickClient(client, kickMessage);
			}
			case CLSA_Log:
			{
				DebugLogEx("%s Client %L has a bad %s value (%f). Min: %d %f Max: %d %f", \
					CS_TAG, client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
			}
			case CLSA_Spec:
			{
				if (GetClientTeam(client) != 1){
					decl String:message[256];
					FormatEx(message, sizeof(message), "%T %s (%.2f)", "R2CompMod #27", client, cvarName, fCvarVal);
					if (clsetting.CLSE_hasMin)
						Format(message, sizeof(message), "%s, Min %.2f", message, clsetting.CLSE_min);
					if (clsetting.CLSE_hasMax)
						Format(message, sizeof(message), "%s, Max %.2f", message, clsetting.CLSE_max);

					ChangeClientTeam(client, 1);
					PrintToChat(client, "%s %s", MAIN_TAG, message);
					DebugLog("%s Moving to spec %L for bad %s value (%f). Min: %d %f Max: %d %f", \
						CS_TAG, client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
				}
			}
		}
	}
}

public Action:_ClientSettings_Cmd(client, args)
{
	new clscount = GetArraySize(ClientSettingsArray);
	CLSEntry clsetting;
	decl String:message[256], String:shortbuf[64];
	ReplyToCommand(client, "[Rotoblin] Tracked Client CVars (Total %d)", clscount);
	for(new i = 0; i < clscount; i++)
	{
		GetArrayArray(ClientSettingsArray, i, clsetting);
		FormatEx(message, sizeof(message), "[Rotoblin] Client CVar: %s ", clsetting.CLSE_cvar);
		if(clsetting.CLSE_hasMin)
		{
			FormatEx(shortbuf, sizeof(shortbuf), "Min: %f ", clsetting.CLSE_min);
			StrCat(message, sizeof(message), shortbuf);
		}
		if(clsetting.CLSE_hasMax)
		{
			FormatEx(shortbuf, sizeof(shortbuf), "Max: %f ", clsetting.CLSE_max);
			StrCat(message, sizeof(message), shortbuf);
		}
		switch(clsetting.CLSE_action)
		{
			case CLSA_Kick:
			{
				StrCat(message, sizeof(message), "Action: Kick");
			}
			case CLSA_Log:
			{
				StrCat(message, sizeof(message), "Action: Log");
			}
			case CLSA_Spec:
			{
				StrCat(message, sizeof(message), "Action: Move to spec");
			}
		}
		ReplyToCommand(client, message);
	}
	return Plugin_Handled;
}

public Action:_TrackClientCvar_Cmd(args)
{
	if(args < 3 || args == 4)
	{
		PrintToServer("Usage: rotoblin_trackclientcvar <cvar> <hasMin> <min> [<hasMax> <max> [<action>]]");
		if(IsDebugEnabled())
		{
			decl String:cmdbuf[128];
			GetCmdArgString(cmdbuf, sizeof(cmdbuf));
			DebugLog("[Rotoblin] Invalid track client cvar: %s", cmdbuf);
		}
		return Plugin_Handled;
	}
	decl String:sBuffer[CLS_CVAR_MAXLEN], String:cvar[CLS_CVAR_MAXLEN];
	new bool:hasMin, bool:hasMax, Float:min, Float:max, CLSAction:action=CLSA_Kick;
	GetCmdArg(1, cvar, sizeof(cvar));
	if(!strlen(cvar))
	{
		PrintToServer("Unreadable cvar");
		if(IsDebugEnabled())
		{
			decl String:cmdbuf[128];
			GetCmdArgString(cmdbuf, sizeof(cmdbuf));
			DebugLog("[Rotoblin] Invalid track client cvar: %s", cmdbuf);
		}
		return Plugin_Handled;
	}
	GetCmdArg(2, sBuffer, sizeof(sBuffer));
	hasMin = bool:StringToInt(sBuffer);
	GetCmdArg(3, sBuffer, sizeof(sBuffer));
	min = StringToFloat(sBuffer);
	if(args >= 5)
	{
		GetCmdArg(4, sBuffer, sizeof(sBuffer));
		hasMax = bool:StringToInt(sBuffer);
		GetCmdArg(5, sBuffer, sizeof(sBuffer));
		max = StringToFloat(sBuffer);
	}
	if(args >= 6)
	{
		GetCmdArg(6, sBuffer, sizeof(sBuffer));
		action = CLSAction:StringToInt(sBuffer);
	}

	_AddClientCvar(cvar, hasMin, min, hasMax, max, action);

	return Plugin_Handled;
}

public Action:_ResetTracking_Cmd(args)
{
	ClearArray(ClientSettingsArray);

	DebugLog("%s Stopping client settings tracking", CS_TAG);

	if (ClientSettingsCheckTimer != INVALID_HANDLE){

		KillTimer(ClientSettingsCheckTimer);
		ClientSettingsCheckTimer = INVALID_HANDLE;
	}

	return Plugin_Handled;
}

public Action:_StartClientChecking_Cmd(args)
{
	_StartTracking();
}

static _StartTracking()
{
	if(IsPluginEnabled() && ClientSettingsCheckTimer == INVALID_HANDLE)
	{
		if(IsDebugEnabled())
		{
			DebugLog("%s Starting repeating check timer", CS_TAG);
		}
		ClientSettingsCheckTimer = CreateTimer(GetRandomFloat(2.0, 4.0), _CheckClientSettings_Timer, _, TIMER_REPEAT);
	}
	else
	{
		PrintToServer("Can't start plugin tracking or tracking already started");
	}
}

static _AddClientCvar(const String:cvar[], bool:hasMin, Float:min, bool:hasMax, Float:max, CLSAction:action)
{
	if(ClientSettingsCheckTimer != INVALID_HANDLE)
	{
		PrintToServer("Can't track new cvars in the middle of a match");
		if(IsDebugEnabled())
		{
			DebugLog("%s Attempt to track new cvar %s during a match!", CS_TAG, cvar);
		}
		return;
	}
	if(!(hasMin || hasMax))
	{
		DebugLog("%s Client CVar %s specified without max or min", CS_TAG, cvar);
		return;
	}
	if(hasMin && hasMax && max < min)
	{
		DebugLog("%s Client CVar %s specified max < min (%f < %f)", CS_TAG, cvar, max, min);
		return;
	}
	if(strlen(cvar) >= CLS_CVAR_MAXLEN)
	{
		DebugLog("%s CVar Specified (%s) is longer than max cvar length (%d)", CS_TAG, cvar, CLS_CVAR_MAXLEN);
		return;
	}

	new iArraySize = GetArraySize(ClientSettingsArray);

	CLSEntry newEntry;
	for(new i = 0; i < iArraySize; i++)
	{
		GetArrayArray(ClientSettingsArray, i, newEntry);
		if(StrEqual(newEntry.CLSE_cvar, cvar, false))
		{
			DebugLog("%s Attempt to track CVar %s, which is already being tracked.", CS_TAG, cvar);
			return;
		}
	}

	newEntry.CLSE_hasMin=hasMin;
	newEntry.CLSE_min=min;
	newEntry.CLSE_hasMax=hasMax;
	newEntry.CLSE_max=max;
	newEntry.CLSE_action=action;
	strcopy(newEntry.CLSE_cvar, CLS_CVAR_MAXLEN, cvar);

	if(IsDebugEnabled())
	{
		DebugLog("%s Tracking Cvar %s Min %d %f Max %d %f Action %d", CS_TAG, cvar, hasMin, min, hasMax, max, action);
	}

	PushArrayArray(ClientSettingsArray, newEntry);
}
