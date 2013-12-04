/*
To do list: maybe have more than one tank be put out - done
Maybe control the damage done to tank per second (tank burn duration cvar) and have the plugin adjust the timer according to that cvar
*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define PLUGIN_VERSION 		"0.7"
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY

public Plugin:myinfo =
{
	name = "Tank Burn",
	author = "archer, raziEiL [disawar1]",
	description = "When tank is lit, tank burns for x ammount of seconds.",
	version = PLUGIN_VERSION,
	url = "http://code.google.com/p/rotoblin2/"
};

new bool:g_bPluginIsEnabled;
//new bool:g_bIsTankInPlay;

// Which client is the tank
//new g_iTankClient;
//new g_iCurrentFrustration;

// The plugin enable cvar
new Handle:g_hEnable;

// Damage from fire cvar
//new Handle:g_hFireDamage;

// Burn Duration cvar
new Handle:g_hFireDuration;

static Handle:hBurnTime;

public OnPluginStart()
{
	hBurnTime = FindConVar("inferno_flame_lifetime");
	// ---------------------------------------------------
	// Variables
	// ----------------------------------------------------
	//g_bIsTankInPlay = false;
	// ----------------------------------------------------
	// Convars
	// ----------------------------------------------------
	g_hEnable 				= CreateConVar("tankburn"				, "0"	, "Sets whether the plugin is active or not.", CVAR_FLAGS);
	//g_hFireDamage			= CreateConVar("tankburn_damage"		, "2000"	, "Sets for how much health fire will damage the tank.", CVAR_FLAGS);
	g_hFireDuration			= CreateConVar("tankburn_duration"		, "18.0"	, "Sets for how long the tank will burn and take damage.", CVAR_FLAGS);
	//RegConsoleCmd("sm_tank", Command_Tank);	//used to find the hud reset prop
	// ----------------------------------------------------
	// Hooking of events and convars
	// ----------------------------------------------------
	HookConVarChange(g_hEnable,ConVarChange_Enable);
	HookEvent("player_hurt",Event_TankOnFire);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("item_pickup", item_pickup);
	HookEvent("entity_killed", TB_ev_EntityKilled);
}

public OnPluginEnd()
{
	RestoreMolo();
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bPluginIsEnabled) RestoreMolo();
}

public Action:item_pickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_bPluginIsEnabled) return;

	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	decl String:sItem[32];
	GetEventString(event, "item", sItem, 32);

	if (StrEqual(sItem, "molotov"))
		PrintToChat(client, "[Tank Burn] Tank will burn only %d sec.", GetConVarInt(g_hFireDuration));
}

public Action:TB_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_bPluginIsEnabled && IsPlayerTank(GetEventInt(event, "entindex_killed")))
		CreateTimer(1.0, TB_t_FindAnyTank, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:TB_t_FindAnyTank(Handle:timer)
{
	new bool:TankInGame;

	for (new i = 1; i <= MaxClients; i++){

		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsPlayerTank(i) && !IsIncapacitated(i)){

			TankInGame = true;
			break;
		}
	}

	if (!TankInGame)
		RestoreMolo();
}

public Action:Event_TankSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bPluginIsEnabled){return;}

	NerfMolo();
}

public Action:Event_TankOnFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!g_bPluginIsEnabled){return;}

	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsClientAndInGame(client) || !IsPlayerAlive(client)){return;}

	new dmgtype = GetEventInt(event,"type");
	//types found 8,  2056
	if(dmgtype != 8 && dmgtype != 2056){return;} //if not fire, return

	if (GetClientTeam(client) == 3 && IsPlayerTank(client))
	{
		CreateTimer(GetConVarFloat(g_hFireDuration), ExtinguishTimer, client);
	}
}

public Action:ExtinguishTimer(Handle:timer, any:client)
{
	if (!IsClientInGame(client) ||												// or client is not ingame
			GetClientTeam(client) != 3 ||											// or client isn't infected
			!IsPlayerAlive(client) ||												// or client isn't alive
			!IsPlayerTank(client))					// or client isn't a tank
			{
				return;
			}

	ExtinguishEntity(client);
	SetEntPropFloat(client, Prop_Send, "m_burnPercent", 0.0);
	SetEntProp(client, Prop_Send, "m_frustration", 0);
}

NerfMolo()
{
	SetConVarInt(hBurnTime, 3);
}

RestoreMolo()
{
	ResetConVar(hBurnTime);
}

public ConVarChange_Enable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bPluginIsEnabled = GetConVarBool(g_hEnable);
}