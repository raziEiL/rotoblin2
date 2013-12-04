#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

public Plugin:myinfo =
{
	name = "[L4D] Remove Slowdown Modified",
	author = "Jahze, Blade, ProdigySim, raziEiL [disawar1]",
	description = "Removes the slow down from special infected",
	version = "1.0",
	url = "http://code.google.com/p/rotoblin2/"
};

static		Handle:g_hAllowSlowDown, Handle:g_hSlowDownTank, bool:g_bCvarAllowSlowDown, bool:g_bCvarSlowDownTank, bool:g_bLoadLater;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLoadLater = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	g_hAllowSlowDown	=	CreateConVar("l4d_si_slowdown", "0", "Enables/disables removal of the slow down that weapons to do special infected", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSlowDownTank		=	CreateConVar("l4d_si_slowdown_tank", "0", "Enables/disables removal of the slow down that weapons do to tanks", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	HookConVarChange(g_hAllowSlowDown,		OnCvarChange_AllowSlowDown);
	HookConVarChange(g_hSlowDownTank,		OnCvarChange_SlowDownTank);
	SD_GetCvars();

	if (g_bLoadLater && g_bCvarAllowSlowDown)
		SD_ToogleHook(true);
}

public OnClientPutInServer(client)
{
	if (g_bCvarAllowSlowDown && client)
		SDKHook(client, SDKHook_OnTakeDamagePost, SD_SDKh_OnTakeDamagePost);
}

public Action:SD_SDKh_OnTakeDamagePost(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (IsClientAndInGame(victim) && GetClientTeam(victim) == 3){

		if (!g_bCvarSlowDownTank && IsPlayerTank(victim)) return;

		SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 1.0);
	}
}

SD_ToogleHook(bool:bHook)
{
	for (new i = 1; i <= MaxClients; i++){

		if (!IsClientInGame(i)) continue;

		if (bHook)
			SDKHook(i, SDKHook_OnTakeDamagePost, SD_SDKh_OnTakeDamagePost);
		else
			SDKUnhook(i, SDKHook_OnTakeDamagePost, SD_SDKh_OnTakeDamagePost);
	}
}

public OnCvarChange_AllowSlowDown(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_bCvarAllowSlowDown = GetConVarBool(g_hAllowSlowDown);

	if (!StringToInt(oldValue))
		SD_ToogleHook(true);
	else if (!g_bCvarAllowSlowDown)
		SD_ToogleHook(false);
}

public OnCvarChange_SlowDownTank(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
		g_bCvarSlowDownTank = GetConVarBool(g_hSlowDownTank);
}

SD_GetCvars()
{
	g_bCvarAllowSlowDown = GetConVarBool(g_hAllowSlowDown);
	g_bCvarSlowDownTank = GetConVarBool(g_hSlowDownTank);
}
