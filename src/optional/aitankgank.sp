#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d_lib>

#define TANK_CLAW			"weapon_tank_claw"

public Plugin:myinfo =
{
    name = "AI Tank Gank",
    author = "Stabby, raziEiL [disawar1]",
    version = "0.2",
    description = "Kills tanks on pass to AI."
};

static Handle:hKillOnCrash, Handle:hKillOn;

public OnPluginStart()
{
	hKillOn			=	CreateConVar("tankgank_enable", "0", "Enables or disables the AI Tank Gank plugin", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hKillOnCrash		=	CreateConVar("tankgank_killoncrash",	"0", "If 0, tank will not be killed if the player that controlles him crashes.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	HookEvent("player_bot_replace", OnTankGoneAi);
}

public Action:OnTankGoneAi(Handle:event, const String: name[], bool:dontBroadcast)
{
	if (!GetConVarBool(hKillOn)) return;

	new formerTank = GetClientOfUserId(GetEventInt(event, "player"));
	new newTank = GetClientOfUserId(GetEventInt(event, "bot"));

	if (GetClientTeam(newTank) == 3 && IsPlayerTank(newTank))
	{
		if (formerTank == 0 && !GetConVarBool(hKillOnCrash) )	//if people disconnect, formerTank = 0 instead of the old player's id
			return;

		CreateTimer(0.5, Timed_CheckAndKill, newTank);
	}
}

public Action:Timed_CheckAndKill(Handle:unused, any:newTank)
{
	if (IsClientInGame(newTank) && IsFakeClient(newTank))
		ForcePlayerSuicide(newTank);

	new iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt , TANK_CLAW)) != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iEnt, "Kill");
}