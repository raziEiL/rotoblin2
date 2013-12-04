#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

//#define RESPAWN_SOUND	"UI/Pickup_GuitarRiff10.wav"
#define RESPAWN_SOUND "player/jumplanding_zombie.wav"

public Plugin:myinfo =
{
	name = "Silent SI",
	author = "raziEiL [disawar1]",
	description = "Mute some SI sounds for Survivors.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public OnPluginStart()
{
	AddNormalSoundHook(SI_sh_OnSoundEmitted);
}

public Action:SI_sh_OnSoundEmitted(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (numClients > 1 && IsClient(entity) && StrEqual(sample, RESPAWN_SOUND) && IsPlayerGhost(entity)){
		//PrintToChatAll("1. numClients %d, entity %d", numClients, entity);
		numClients = 0;
		for (new i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i))
				clients[numClients++] = i;

		return Plugin_Changed;
	}
	return Plugin_Continue;
}
