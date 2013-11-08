#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <l4d_lib>

public Plugin:myinfo = 
{
	name = "[L4D] Infected Friendly Fire Disable",
	author = "ProdigySim, Don, raziEiL [disawar1]",
	description = "Disables friendly fire between infected players.",
	version = "1.1",
	url = "http://code.google.com/p/rotoblin2/" // L4D2 version http://bitbucket.org/ProdigySim/misc-sourcemod-plugins/
};

public OnPluginStart()
{
	if (g_bLoadLater)
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i))
				SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnClientPutInServer(client)
{
	if (client)
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (/*molotov bugfix*/damagetype & DMG_CLUB && IsClientAndInGame(victim) && GetClientTeam(victim) == 3 && IsClientAndInGame(attacker) && GetClientTeam(attacker) == 3)
	{
		if (!IsPlayerTank(attacker)) // If no tank ff or attacker is not tank
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}
