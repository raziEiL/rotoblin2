#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

public Plugin:myinfo =
{
	name        = "Bash Kills",
	author      = "Jahze, raziEiL [disawar1]",
	version     = "1.0",
	description = "Stop special infected getting bashed to death",
	url = "http://code.google.com/p/rotoblin2/"
}

static		Handle:cvar_bashKills, bool:g_bCvarAllowBashKill, bool:g_bLoadLater;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLoadLater = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	cvar_bashKills = CreateConVar("l4d_no_bash_kills", "0", "Prevent special infected from getting bashed to death", FCVAR_PLUGIN|FCVAR_NOTIFY);

	HookConVarChange(cvar_bashKills, OnCvarChange_cvar_bashKills);
	BK_GetCvars();

	if (g_bLoadLater && g_bCvarAllowBashKill)
		BK_ToogleHook(true);

	g_bLoadLater = false;
	if (IsL4DGame())
		g_bLoadLater = true;
}

public OnClientPutInServer(client)
{
	if (g_bCvarAllowBashKill && client)
		SDKHook(client, SDKHook_OnTakeDamage, BK_SDKh_OnTakeDamage);
}

public Action:BK_SDKh_OnTakeDamage( victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3] ){

    if (damage == 250.0 && damageType & DMG_CLUB && weapon == -1){

		if (IsClient(victim) && IsClient(attacker) && IsSI(victim) && IsSurvivor(attacker))
			return Plugin_Handled;
	}

    return Plugin_Continue;
}

bool:IsSI(client)
{
    if ( GetClientTeam(client) != 3 || !IsPlayerAlive(client) ) {
        return false;
    }
    new class = GetPlayerClass(client);
    if (class == 2  || (g_bLoadLater && class == 5) || (!g_bLoadLater && class == 8)) {
        return false;
    }

    return true;
}

BK_ToogleHook(bool:bHook)
{
	for (new i = 1; i <= MaxClients; i++){

		if (!IsClientInGame(i)) continue;

		if (bHook)
			SDKHook(i, SDKHook_OnTakeDamage, BK_SDKh_OnTakeDamage);
		else
			SDKUnhook(i, SDKHook_OnTakeDamage, BK_SDKh_OnTakeDamage);
	}
}

public OnCvarChange_cvar_bashKills(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	g_bCvarAllowBashKill = GetConVarBool(cvar_bashKills);

	if (!StringToInt(oldValue))
		BK_ToogleHook(true);
	else if (!g_bCvarAllowBashKill)
		BK_ToogleHook(false);
}

BK_GetCvars()
{
	g_bCvarAllowBashKill = GetConVarBool(cvar_bashKills);
}