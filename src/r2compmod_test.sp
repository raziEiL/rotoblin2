#define PLUGIN_VERSION "1.1"

#include <sourcemod>
#include <r2comp_api>

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkCompNatives();
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name = "r2comp test",
	author = "raziEiL [disawar1]",
	description = "Test r2comp natives/forwards",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public OnPluginStart()
{
	RegAdminCmd("sm_r2comp_status", Command_NativeStatus, ADMFLAG_ROOT);
	RegAdminCmd("sm_r2comp_test", Command_CheckNatives, ADMFLAG_ROOT);
	CreateTimer(5.0, R2T_t_ReportStatus)
}

public Action:R2T_t_ReportStatus(Handle:timer)
{
	R2T_Natives();
}

public Action:Command_NativeStatus(client, args)
{
	R2T_Natives(client);
	return Plugin_Handled;
}

R2T_Natives(client = 0)
{
	for (new i; i < _:CompNatives; i++){

		if (!client)
			LogMessage("native '%s' - %s", g_sR2API_NativeName[i], IsNativeAvailable(CompNatives:i) ? "will work!" : "not available");
		else
			PrintToChat(client, "native '%s' - %s", g_sR2API_NativeName[i], IsNativeAvailable(CompNatives:i) ? "will work!" : "not available");
	}
}

public Action:Command_CheckNatives(client, args)
{
	if (!client) return Plugin_Handled;

	if (R2comp_IsStartEntity(client))
		PrintToChat(client, "You are in start saferoom");
	else if (R2comp_IsEndEntity(client))
		PrintToChat(client, "You are in end saferoom");
	else
		PrintToChat(client, "You are outside of saferooms");

	decl Float:vStartRoom[3], Float:vEndRoom[3];

	R2comp_GetSafeRoomOrigin(vStartRoom);
	R2comp_GetSafeRoomOrigin(vEndRoom, false);

	PrintToChat(client, "Start pos: %.2f %.2f %.2f\nEnd pos: %.2f %.2f %.2f", vStartRoom[0], vStartRoom[1], vStartRoom[2],
	vEndRoom[0], vEndRoom[1], vEndRoom[2]);

	decl String:sMatch[64];
	R2comp_GetMatchName(sMatch, 64);
	PrintToChat(client, "Current match: '%s'", sMatch);
	PrintToChat(client, "Team A: %d scores, Team B: %d scores", R2comp_GetScore(0), R2comp_GetScore(1));
	PrintToChat(client, "MobTimer: %d sec.", R2comp_GetMobTimer());
	PrintToChat(client, "Survivor flow: %f", R2comp_GetHighestSurvivorFlow())

	if (IsNativeAvailable(IsGamePaused))
		PrintToChat(client, "Pause: %b, RUP: %b", L4DReady_IsGamePaused(), L4DReady_IsReadyMode());

	if (IsNativeAvailable(GetCampaingScore))
		PrintToChat(client, "Survivors/Infected scores: %d/%d", L4DScores_GetCampaingScore(2), L4DScores_GetCampaingScore(3));

	return Plugin_Handled;
}

public R2comp_OnServerEmpty()
{
	LogMessage("fwd R2comp_OnServerEmpty() has been sent out!");
}

public R2comp_OnMatchStarts(const String:match[])
{
	LogMessage("fwd R2comp_OnMatchStarts(%s) has been sent out!", match);
}

public R2comp_OnMatchStarts_Pre(const String:match[])
{
	LogMessage("fwd R2comp_OnMatchStarts_Pre(%s) has been sent out!", match);
}

public R2comp_OnUnscrambleEnd()
{
	LogMessage("fwd R2comp_OnUnscrambleEnd() has been sent out!");
}

public L4DReady_OnRoundIsLive()
{
	PrintToChatAll("fwd L4DReady_OnRoundIsLive() has been sent out!");
}
