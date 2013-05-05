#define PLUGIN_VERSION "1.0"

// Note: readyup and scores should be loaded. Run some match to test natives

#include <sourcemod>
#include <r2comp_api>

#define L4D_SCORES	0 // Outdated, no longer supported!

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
	RegAdminCmd("sm_r2ntvs", CmdR2Natives, ADMFLAG_ROOT);
	RegAdminCmd("sm_r2test", CmdR2CompTest, ADMFLAG_ROOT);
}

public Action:CmdR2Natives(client, args)
{
	if (IsNativeAvailable(IsStartEntity))
		ReplyToCommand(client, "R2comp_IsStartEntity - OK");
	else
		ReplyToCommand(client, "R2comp_IsStartEntity - BAD");

	if (IsNativeAvailable(IsEndEntity))
		ReplyToCommand(client, "R2comp_IsEndEntity - OK");
	else
		ReplyToCommand(client, "R2comp_IsEndEntity - BAD");

	if (IsNativeAvailable(GetSafeRoomOrigin))
		ReplyToCommand(client, "R2comp_GetSafeRoomOrigin - OK");
	else
		ReplyToCommand(client, "R2comp_GetSafeRoomOrigin - BAD");

	if (IsNativeAvailable(GetMobTimer))
		ReplyToCommand(client, "R2comp_GetMobTimer - OK");
	else
		ReplyToCommand(client, "R2comp_GetMobTimer - BAD");

	if (IsNativeAvailable(GetMatchName))
		ReplyToCommand(client, "R2comp_GetMatchName - OK");
	else
		ReplyToCommand(client, "R2comp_GetMatchName - BAD");

	if (IsNativeAvailable(IsGamePaused))
		ReplyToCommand(client, "L4DReady_IsGamePaused - OK");
	else
		ReplyToCommand(client, "L4DReady_IsGamePaused - BAD");

	if (IsNativeAvailable(IsReadyMode))
		ReplyToCommand(client, "L4DReady_IsReadyMode - OK");
	else
		ReplyToCommand(client, "L4DReady_IsReadyMode - BAD");

#if L4D_SCORES
	if (IsNativeAvailable(GetCampaingScore))
		ReplyToCommand(client, "L4DScores_GetCampaingScore - OK");
	else
		ReplyToCommand(client, "L4DScores_GetCampaingScore - BAD");
#endif
}

public Action:CmdR2CompTest(client, args)
{
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

	PrintToChat(client, "MobTimer: %d sec.", R2comp_GetMobTimer());

	PrintToChat(client, "Pause: %b, RUP: %b", L4DReady_IsGamePaused(), L4DReady_IsReadyMode());

#if L4D_SCORES
	PrintToChat(client, "Survivors/Infected scores: %d/%d", L4DScores_GetCampaingScore(2), L4DScores_GetCampaingScore(3));
#endif

	decl String:sMatch[64];
	R2comp_GetMatchName(sMatch, 64);
	PrintToChat(client, "Current match: '%s'", sMatch);

	return Plugin_Handled;
}

public R2comp_OnServerEmpty()
{
	LogMessage("fwd R2comp_OnServerEmpty is fired!");
}

public R2comp_OnMatchStarts(const String:match[])
{
	LogMessage("fwd R2comp_OnMatchStarts is fired! Current match: %s", match);
}

public L4DReady_OnRoundIsLive()
{
	PrintToChatAll("fwd L4DReady_OnRoundIsLive is fired!");
}
