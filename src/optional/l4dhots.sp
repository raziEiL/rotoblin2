#pragma semicolon 1

#include <sourcemod>
#include <l4d_lib>

public Plugin:myinfo =
{
	name = "L4D HOTs",
	author = "ProdigySim, raziEiL [disawar1]",
	description = "Pills and Adrenaline heal over time",
	version = "0.3",
	url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
}

static	Handle:g_hPillsHot, Handle:g_hAdrenHot, Handle:g_hContinueHot, Handle:g_hPillCvar, Handle:g_hAdrenCvar, Handle:g_hCvarHealthValue,
		bool:g_bPillsHot, bool:g_bAdrenHot;

public OnPluginStart()
{
	g_hPillCvar		= FindConVar("pain_pills_health_value");
	g_hPillsHot			= CreateConVar("l4d_pills_hot", "0", "Pills heal over time (10 hp each 1s)", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hContinueHot		= CreateConVar("l4d_pills_hot_continue", "0", "Continue healing after revive", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarHealthValue	= CreateConVar("l4d_pills_hot_value", "50", "Amount of health", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 1.0);

	HookConVarChange(g_hPillsHot, PillHotChanged);

	TooglePillsHot(GetConVarBool(g_hPillsHot));

	if (IsL4DGame(true))
	{
		g_hAdrenCvar	= FindConVar("adrenaline_health_buffer");
		g_hAdrenHot	= CreateConVar("l4d_adrenaline_hot", "0", "Adrenaline heals over time (15+10 hp each 1s)", FCVAR_PLUGIN);

		HookConVarChange(g_hAdrenHot, AdrenHotChanged);
		ToogleAdrenalineHot(GetConVarBool(g_hAdrenHot));
	}
}

public OnPluginEnd()
{
	if (g_bPillsHot)
		ResetConVar(g_hPillCvar);
	if (g_bAdrenHot)
		ResetConVar(g_hAdrenCvar);
}

public Action:PillsUsed_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	HealEntityOverTime(client, 1.0, 10, GetConVarInt(g_hCvarHealthValue));
}

public Action:AdrenalineUsed_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	HealEntityOverTime(client, 1.0, 15, 25);
}

stock HealEntityOverTime(client, Float:interval, increment, total)
{
	if (!IsValidClient(client))
		return;

	new maxhp=GetEntProp(client, Prop_Send, "m_iMaxHealth", 2);

	if(increment >= total)
	{
		HealTowardsMax(client, total, maxhp);
	}
	else
	{
		HealTowardsMax(client, increment, maxhp);
		new Handle:myDP;
		CreateDataTimer(interval, __HOT_ACTION, myDP,
			TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		WritePackCell(myDP, client);
		WritePackCell(myDP, increment);
		WritePackCell(myDP, total-increment);
		WritePackCell(myDP, maxhp);
	}
}

IsValidClient(client)
{
	return client && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2;
}

public Action:__HOT_ACTION(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new client = ReadPackCell(pack);

	if (!IsValidClient(client))
		return Plugin_Stop;

	if (IsIncapacitated(client)){

		if (GetConVarBool(g_hContinueHot))
			return Plugin_Continue;

		return Plugin_Stop;
	}

	new increment = ReadPackCell(pack);
	new pos = GetPackPosition(pack);
	new remaining = ReadPackCell(pack);
	new maxhp = ReadPackCell(pack);

//	PrintToChatAll("HOT: %d %d %d %d", client, increment, remaining, maxhp);

	if(increment >= remaining)
	{
		HealTowardsMax(client, remaining, maxhp);
		return Plugin_Stop;
	}
	HealTowardsMax(client, increment, maxhp);
	SetPackPosition(pack, pos);
	WritePackCell(pack, remaining-increment);

	return Plugin_Continue;
}

stock HealTowardsMax(client, amount, max)
{
	new Float:hb = float(amount) + GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	new Float:overflow = (hb+GetClientHealth(client))-max;
	if(overflow > 0)
	{
		hb -= overflow;
	}
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", hb);
}

public PillHotChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	TooglePillsHot(bool:(StringToInt(newValue) != 0));
}

public AdrenHotChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ToogleAdrenalineHot(bool:(StringToInt(newValue) != 0));
}

TooglePillsHot(bool:bHook)
{
	if (bHook && !g_bPillsHot){

		g_bPillsHot = true;
		SetConVarInt(g_hPillCvar, 0);
		HookEvent("pills_used", PillsUsed_Event);
	}
	else if (!bHook && g_bPillsHot){

		g_bPillsHot = false;
		ResetConVar(g_hPillCvar);
		UnhookEvent("pills_used", PillsUsed_Event);
	}
}

ToogleAdrenalineHot(bool:bHook)
{
	if (bHook && !g_bAdrenHot){

		g_bAdrenHot = true;
		SetConVarInt(g_hAdrenCvar, 0);
		HookEvent("adrenaline_used", AdrenalineUsed_Event);
	}
	else if (!bHook && g_bAdrenHot){

		g_bAdrenHot = false;
		ResetConVar(g_hAdrenCvar);
		UnhookEvent("adrenaline_used", AdrenalineUsed_Event);
	}
}
