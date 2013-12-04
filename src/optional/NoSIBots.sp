#define PLUGIN_VERSION "1.0"

#include <sourcemod>


public Plugin:myinfo =
{
	name = "No SI Bots",
	author = "raziEiL [disawar1]",
	description = "Kick special infeted bots.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public OnClientPutInServer(client)
{
	if (client && IsFakeClient(client))
		CreateTimer(0.0, NB_t_Delay, client);
}

public Action:NB_t_Delay(Handle:timer, any:client)
{
	if (IsClientInGame(client) && IsFakeClient(client) && IsSiBot(client))
		KickClient(client, "Kicked by NoSiBots plugin");
}

bool:IsSiBot(client)
{
	decl String:sName[32];
	GetClientName(client, sName, 32);

	return StrContains(sName, "Smoker") != -1 || StrContains(sName, "Boomer") != -1 || StrContains(sName, "Hunter") != -1;
}