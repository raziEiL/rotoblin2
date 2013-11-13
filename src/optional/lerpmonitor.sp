#pragma semicolon 1

#include <sourcemod>
#include <colors>
#include <l4d_lib>

#define CVAR_FLAGS 			FCVAR_PLUGIN|FCVAR_NOTIFY
#define PLUGIN_VERSION 		"1.1"
#define STEAMID_SIZE 		32
#define L4D_TEAM_SPECTATE 1

static const ARRAY_STEAMID = 0;
static const ARRAY_LERP = 1;
static const ARRAY_CHANGES = 2;
static const ARRAY_COUNT = 3;

static Handle:arrayLerps;
static Handle:cVarReadyUpLerpChanges;
static Handle:cVarAllowedLerpChanges;
static Handle:cVarLerpChangeSpec;
static Handle:cVarMinLerp;
static Handle:cVarMaxLerp;

static Handle:cVarMinUpdateRate;
static Handle:cVarMaxUpdateRate;
static Handle:cVarMinInterpRatio;
static Handle:cVarMaxInterpRatio;

static bool:isFirstHalf = true;
static bool:isMatchLife = true;
static Handle:cvarL4DReadyEnabled = INVALID_HANDLE;
static Handle:cvarL4DReadyBothHalves = INVALID_HANDLE;
static bool:g_bTempBlock[MAXPLAYERS + 1], bool:g_bIllegalValue[MAXPLAYERS + 1];
static Handle:cVarLerpIllegalPenalty;

public Plugin:myinfo = {
	name = "LerpMonitor++",
	author = "ProdigySim, Die Teetasse, vintik, raziEiL [diswar1]",
	description = "Keep track of players' lerp settings",
	version = PLUGIN_VERSION,
	url = "https://bitbucket.org/vintik/various-plugins"
};

public OnPluginStart() {

	cVarMinUpdateRate = FindConVar("sv_minupdaterate");
	cVarMaxUpdateRate = FindConVar("sv_maxupdaterate");
	cVarMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	cVarMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");

	cvarL4DReadyEnabled = FindConVar("l4d_ready_enabled");
	cvarL4DReadyBothHalves = FindConVar("l4d_ready_both_halves");

	cVarAllowedLerpChanges	= CreateConVar("sm_allowed_lerp_changes",	"3", "Allowed number of lerp changes for a half. 0: unlimited", CVAR_FLAGS, true, 0.0);
	cVarLerpChangeSpec			= CreateConVar("sm_lerp_change_spec",		"2", "Action for exceeded lerp count changes. 1: move to spectators, 2: blocks lerp changes (l4d only)", CVAR_FLAGS, true, 0.0, true, 2.0);
	cVarReadyUpLerpChanges	= CreateConVar("sm_readyup_lerp_changes",	"0", "0: always allows lerp changes, 1: allow when the match isn't live, 2: allows until survivor leave the saferoom. (Note: 1 and 2 values ignore \"sm_allowed_lerp_changes\" cvar)", CVAR_FLAGS, true, 0.0, true, 2.0);
	cVarLerpIllegalPenalty	= CreateConVar("sm_lerp_illegal_penalty",	"1", "Action for illegal lerp value. 0: move to spectators, 1: blocks lerp changes (l4d only)", CVAR_FLAGS, true, 0.0, true, 1.0);
	cVarMinLerp = CreateConVar("sm_min_lerp", "0.0", "Minimum allowed lerp value", CVAR_FLAGS, true, 0.0);
	cVarMaxLerp = CreateConVar("sm_max_lerp", "0.1", "Maximum allowed lerp value", CVAR_FLAGS, true, 0.0);

	RegConsoleCmd("sm_lerps", Lerps_Cmd, "List the Lerps of all players in game");

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_team", OnTeamChange);
	HookEvent("player_left_start_area", LT_ev_PlayerLeftStartArea, EventHookMode_PostNoCopy);

	// create array
	arrayLerps = CreateArray(ByteCountToCells(STEAMID_SIZE));
	// process current players
	for (new client = 1; client < MaxClients+1; client++) {
		if (!IsClientInGame(client) || IsFakeClient(client)) continue;
		ProcessPlayerLerp(client);
	}
}

public OnMapStart() {
	if (cvarL4DReadyEnabled != INVALID_HANDLE && GetConVarBool(cvarL4DReadyEnabled) || GetConVarInt(cVarReadyUpLerpChanges) == 2) {
		isMatchLife = false;
	}
	else {
		isMatchLife = true;
	}
}

public OnMapEnd() {
	isFirstHalf = true;
	ClearArray(arrayLerps);
}

public OnClientSettingsChanged(client) {
	if (IsValidEntity(client) && !IsFakeClient(client)) {
		ProcessPlayerLerp(client);
	}
}

public OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
    if (GetEventInt(event, "team") != L4D_TEAM_SPECTATE)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client > 0)
		{
			if (IsClientInGame(client) && !IsFakeClient(client))
			{
				CreateTimer(0.1, OnTeamChangeDelay, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
    }
}

public Action:OnTeamChangeDelay(Handle:timer, any:client)
{
	if (IsClientInGame(client))
		ProcessPlayerLerp(client);
}

public L4DReady_OnRoundIsLive(){

	if (!isMatchLife && GetConVarInt(cVarReadyUpLerpChanges)){

		CreateTimer(3.0, LM_t_NotifyDealy);
		isMatchLife = true;
	}
}

public Action:LM_t_NotifyDealy(Handle:timer)
{
	PrintToChatAll("Change of the lerp midgame is illegal!");
}

public LT_ev_PlayerLeftStartArea(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarInt(cVarReadyUpLerpChanges) == 2)
		L4DReady_OnRoundIsLive();
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	// little delay for other round end used modules
	CreateTimer(0.5, Timer_RoundEndDelay);
}

public Action:Timer_RoundEndDelay(Handle:timer) {
	isFirstHalf = false;

	if ((cvarL4DReadyBothHalves!=INVALID_HANDLE) && (GetConVarBool(cvarL4DReadyBothHalves))) {
		isMatchLife = false;
	}
}

stock bool:IsFirstHalf() {
	return isFirstHalf;
}

stock bool:IsMatchLife() {
	return isMatchLife;
}

stock GetClientBySteamID(const String:steamID[]) {
	decl String:tempSteamID[STEAMID_SIZE];

	for (new client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client)) continue;
		GetClientAuthString(client, tempSteamID, STEAMID_SIZE);

		if (StrEqual(steamID, tempSteamID)) {
			return client;
		}
	}

	return -1;
}

public Action:Lerps_Cmd(client, args) {
	new clientID, index;
	decl Float:lerp;
	decl String:steamID[STEAMID_SIZE];
	new iLimit = GetArraySize(arrayLerps) / ARRAY_COUNT;
	for (new i = 0; i < iLimit; i++) {
		index = (i * ARRAY_COUNT);

		GetArrayString(arrayLerps, index + ARRAY_STEAMID, steamID, STEAMID_SIZE);
		clientID = GetClientBySteamID(steamID);
		lerp = GetArrayCell(arrayLerps, index + ARRAY_LERP);

		if (clientID != -1 && GetClientTeam(clientID) != L4D_TEAM_SPECTATE) {
			ReplyToCommand(client, "%.01f: %N [%s]", lerp*1000, clientID, steamID);
		}
	}

	return Plugin_Handled;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {

	if (GetConVarInt(cVarReadyUpLerpChanges) == 2)
		isMatchLife = false;

	// delete change count for second half
	if (!IsFirstHalf()) {
		new iLimit = GetArraySize(arrayLerps) / ARRAY_COUNT;
		for (new i = 0; i < iLimit; i++) {
			SetArrayCell(arrayLerps, (i * ARRAY_COUNT) + ARRAY_CHANGES, 0);
		}
	}
}

ProcessPlayerLerp(client) {
	// get lerp
	new Float:newLerpTime = GetLerpTime(client);
	// set lerp for fixing differences between server and client with cl_inter_ratio 0
	SetEntPropFloat(client, Prop_Data, "m_fLerpTime", newLerpTime);
	// check lerp first
	if (GetClientTeam(client) == L4D_TEAM_SPECTATE) return;

	if ((FloatCompare(newLerpTime, GetConVarFloat(cVarMinLerp)) == -1) || (FloatCompare(newLerpTime, GetConVarFloat(cVarMaxLerp)) == 1)) {

		//PrintToChatAll("%N's lerp changed to %.01f", client, newLerpTime*1000);

		if (!GetConVarBool(cVarLerpIllegalPenalty)){

			if (!isMatchLife)
				PrintToChatAll("%N was moved to spectators for lerp %.01f!", client, newLerpTime*1000);

			ChangeClientTeam(client, L4D_TEAM_SPECTATE);
		}
		else {

			decl String:steamID[STEAMID_SIZE], Float:currentLerpTime;
			GetClientAuthString(client, steamID, STEAMID_SIZE);
			new index = FindStringInArray(arrayLerps, steamID);

			if (index != -1)
				currentLerpTime = GetArrayCell(arrayLerps, index + ARRAY_LERP);
			else
				currentLerpTime = GetConVarFloat(cVarMaxLerp);

			ClientCommand(client, "cl_interp %f", currentLerpTime);
			g_bIllegalValue[client] = true;
		}

		PrintToChat(client, "Illegal lerp value (min: %.01f, max: %.01f)",
					GetConVarFloat(cVarMinLerp)*1000, GetConVarFloat(cVarMaxLerp)*1000);
		// nothing else to do
		return;
	}
	else if (g_bIllegalValue[client]){

		// don't count lerps changes if we force change it back
		g_bIllegalValue[client] = false;
		return;
	}

	// Get steamid and index
	decl String:steamID[STEAMID_SIZE];
	GetClientAuthString(client, steamID, STEAMID_SIZE);
	new index = FindStringInArray(arrayLerps, steamID);

	if (index != -1)
	{
		new Float:currentLerpTime = GetArrayCell(arrayLerps, index + ARRAY_LERP);

		// no change?
		if (currentLerpTime == newLerpTime) return;
		new iCvarLerpsAction = GetConVarInt(cVarReadyUpLerpChanges);
		new count = GetArrayCell(arrayLerps, index + ARRAY_CHANGES)+1;
		new CvarMax = GetConVarInt(cVarAllowedLerpChanges);
		new bool:bIllegal = iCvarLerpsAction && isMatchLife;

		if (CvarMax && count > CvarMax || bIllegal){

			switch (GetConVarInt(cVarLerpChangeSpec))
			{
				case 1:
				{
					if (!isMatchLife){ // dont spam

						PrintToChatAll("\x01%N's lerp changed from %.01f to %.01f [\x04%d\x01/%d changes]", client, currentLerpTime*1000, newLerpTime*1000, count, CvarMax);
						PrintToChatAll("%N was moved to spectators (illegal lerp change)!", client);
					}

					if (bIllegal)
						PrintToChat(client, "Illegal change of the lerp midgame! Change it back to %.01f", currentLerpTime*1000);
					else
						PrintToChat(client, "Lerp change limit has been exceeded! Change it back to %.01f", currentLerpTime*1000);

					ChangeClientTeam(client, L4D_TEAM_SPECTATE);
				}
				case 2:
				{
					if (!g_bTempBlock[client]){

						if (bIllegal)
							CPrintToChat(client, "{red}%s!", iCvarLerpsAction == 1 ? "Lerp change is allowed during ready-up only" : "Lerp change isn't allowed after leaving the saferoom");
						else
							PrintToChat(client, "Lerp change limit has been exceeded! [\x04%d\x01/%d changes]", count, CvarMax);

						g_bTempBlock[client] = true;
						CreateTimer(0.5, LM_t_TempBlock, client);
					}

					ClientCommand(client, "cl_interp %f", currentLerpTime);
				}
			}
			// no lerp update
			return;
		}
		else {

			if (!CvarMax){

				PrintToChatAll("%N's lerp changed from %.01f to %.01f", client, currentLerpTime*1000, newLerpTime*1000);
			}
			else{

				PrintToChatAll("\x01%N's lerp changed from %.01f to %.01f [%d/%d changes]", client, currentLerpTime*1000, newLerpTime*1000, count, CvarMax);
				// update changes
				SetArrayCell(arrayLerps, index + ARRAY_CHANGES, count);
			}

			SetArrayCell(arrayLerps, index + ARRAY_LERP, newLerpTime);
		}
	}
	else {
		if (!isMatchLife)
			PrintToChatAll("%N's lerp set to %.01f", client, newLerpTime*1000);

		// add to array
		PushArrayString(arrayLerps, steamID);
		PushArrayCell(arrayLerps, newLerpTime);
		PushArrayCell(arrayLerps, 0);
	}
}

public Action:LM_t_TempBlock(Handle:timer, any:client)
{
	g_bTempBlock[client] = false;
}

Float:GetLerpTime(client) {
	decl String:buffer[64];

	if (!GetClientInfo(client, "cl_updaterate", buffer, sizeof(buffer))) buffer = "";
	new updateRate = StringToInt(buffer);
	updateRate = RoundFloat(clamp(float(updateRate), GetConVarFloat(cVarMinUpdateRate), GetConVarFloat(cVarMaxUpdateRate)));

	if (!GetClientInfo(client, "cl_interp_ratio", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpRatio = StringToFloat(buffer);

	if (!GetClientInfo(client, "cl_interp", buffer, sizeof(buffer))) buffer = "";
	new Float:flLerpAmount = StringToFloat(buffer);

	if (cVarMinInterpRatio != INVALID_HANDLE && cVarMaxInterpRatio != INVALID_HANDLE && GetConVarFloat(cVarMinInterpRatio) != -1.0 ) {
		flLerpRatio = clamp(flLerpRatio, GetConVarFloat(cVarMinInterpRatio), GetConVarFloat(cVarMaxInterpRatio) );
	}

	return maximum(flLerpAmount, flLerpRatio / updateRate);
}

Float:clamp(Float:in, Float:low, Float:high) {
	return in > high ? high : (in < low ? low : in);
}

Float:maximum(Float:a, Float:b) {
	return a > b ? a : b;
}