/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin.ExpolitFixes.sp
 *  Type:			Module
 *  Description:	Survivor/Infected expolit fixes.
 *
 *  Copyright (C) 2012-2013 raziEiL <war4291@mail.ru>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

#define		EF_TAG					"[ExpolitFixes]"

#define		ENGIGE_FIX				"fix_Engine"
#define		HEALTH_EXPOLIT_FIX		"HealthExpolitFixes"

// debug
#define		DEBUG_CHANNEL_NAME		"SurvivorExploitFixes"
static		g_iDebugChannel;

#define		EXPOLIT_TIMER			0.5

static		bool:g_bIsEngineFixLoaded, bool:g_bIsHealthExpolitFixLoaded, bool:g_bAllPlLoaded;

_ExpoliteFixed_OnPluginStart()
{
	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
}

_ExpolitFixed_OnAllPluginsLoaded()
{
	decl String:sPlName[128];
	new Handle:hIterator = GetPluginIterator();

	while (MorePlugins(hIterator)){

		GetPluginFilename(ReadPlugin(hIterator), sPlName, 128);

		if (StrContains(sPlName, ENGIGE_FIX) != -1)
			g_bIsEngineFixLoaded = true;
		if (StrContains(sPlName, HEALTH_EXPOLIT_FIX) != -1)
			g_bIsHealthExpolitFixLoaded = true;
		if (g_bIsEngineFixLoaded && g_bIsHealthExpolitFixLoaded)
			break;
	}
	CloseHandle(hIterator);

	DebugLog("%s _ExpolitFixed_OnAllPluginsLoaded() EngineFix %d, HealthExpolitFix %d", EF_TAG, g_bIsEngineFixLoaded, g_bIsHealthExpolitFixLoaded);

	if (IsPluginEnabled())
		_EF_SetupPLFunction(true);

	g_bAllPlLoaded = true;
}

_EF_OnPluginEnabled()
{
	HookEvent("ammo_pickup", EF_ev_AmmoPickup);

	if (g_bAllPlLoaded){

		DebugLog("%s _EF_OnPluginEnabled", EF_TAG);

		_EF_SetupPLFunction(true);
	}

	if (g_bLoadLater)
		_EF_ToogleHook(true);

	CreateTimer(EXPOLIT_TIMER, _EF_t_CheckDuckingExpolit, _, TIMER_REPEAT);
}

_EF_OnPluginDisabled()
{
	UnhookEvent("ammo_pickup", EF_ev_AmmoPickup);

	DebugLog("%s _EF_OnPluginDisabled", EF_TAG);

	_EF_SetupPLFunction(false);
	_EF_ToogleHook(false);
}

// Fixed up the game mechanics bug when the ammo piles use didn't provide a full ammo refill for weapons.
public Action:EF_ev_AmmoPickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	decl iEnt;
	if ((iEnt = GetPlayerWeaponSlot(client, 0)) == INVALID_ENT_REFERENCE) return;

	decl String:sClassName[64], iWeapIndex;
	GetEntityClassname(iEnt, sClassName, 64);

	if ((iWeapIndex = GetWeaponIndexByClass(sClassName)) == NULL){

		DebugPrintToAllEx("WTF? UNKNOWN WEAPON \"%s\"", sClassName);
		return;
	}

	new iClip = GetEntProp(iEnt, Prop_Send, "m_iClip1");

	if (g_iWeapAttributes[iWeapIndex][CLIP_SIZE] != iClip){

		SetConVarInt(g_hWeaponCvar[iWeapIndex], g_iWeapAttributes[iWeapIndex][MAX_AMMO] + (g_iWeapAttributes[iWeapIndex][CLIP_SIZE] - iClip));
		CheatCommandEx(client, "give", "ammo");
		SetConVarInt(g_hWeaponCvar[iWeapIndex], g_iWeapAttributes[iWeapIndex][MAX_AMMO]);
	}
}

static g_bTriggerCrouch[MAXPLAYERS+1];


_EF_OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_Touch, _EF_SDKh_Touch);
	SDKHook(client, SDKHook_OnTakeDamage, _IF_SDKh_OnTakeDamage);
}

_EF_ToogleHook(bool:bHook)
{
	for (new i = 1; i <= MaxClients; i++){

		if (IsClientInGame(i)){

			if (bHook){

				SDKHook(i, SDKHook_Touch, _EF_SDKh_Touch);
				SDKHook(i, SDKHook_OnTakeDamage, _IF_SDKh_OnTakeDamage);
			}
			else{

				SDKUnhook(i, SDKHook_Touch, _EF_SDKh_Touch);
				SDKUnhook(i, SDKHook_OnTakeDamage, _IF_SDKh_OnTakeDamage);
			}
		}
	}
}

public Action:_EF_SDKh_Touch(entity, other)
{
	if (other == 0) return;

	if (other <= MaxClients && !IsPlayerTank(other) && IsGuyTroll(entity, other)){

		if (IsOnLadder(other)){

			decl Float:vOrg[3];
			GetClientAbsOrigin(other, vOrg);
			vOrg[2] += 2.5;
			TeleportEntity(other, vOrg, NULL_VECTOR, NULL_VECTOR);
		}
		else
			TeleportEntity(other, NULL_VECTOR, NULL_VECTOR, Float:{0.0, 0.0, 251.0});

		DebugPrintToAllEx("Player %d: \"%N\" blocks the player %d \"%N\" on a ladder.", other, other, entity, entity);
	}
	else {

		decl String:sClassName[64];
		GetEntityClassname(other, sClassName, 64);

		if (StrEqual(sClassName, "trigger_auto_crouch"))
			g_bTriggerCrouch[entity] = true;
		else
			g_bTriggerCrouch[entity] = false;
	}
}

public Action:_EF_t_CheckDuckingExpolit(Handle:timer)
{
	if (!IsServerProcessing() || g_bBlackSpot) return Plugin_Continue;

	if (!IsPluginEnabled()) return Plugin_Stop;

	decl client;

	for (new i = 0; i < SurvivorCount; i++){

		client = SurvivorIndex[i];

		if (IsTrueClient(client) && !IsOnLadder(client) && !IsSurvivorBussy(client) && IsUseDuckingExpolit(client)){

			SetEntProp(client, Prop_Send, "m_bDucking", 1);
			DebugPrintToAllEx("Survivor %i: \"%N\" was ducking and were unducked.", client, client);
		}
	}
	for (new i = 0; i < InfectedCount; i++){

		client = InfectedIndex[i];

		if (!IsInfectedBashed(client) && IsTrueClient(client) && !IsOnLadder(client) && !IsInfectedBussy(client) && IsUseDuckingExpolit(client)){

			SetEntProp(client, Prop_Send, "m_bDucking", 1);

			DebugPrintToAllEx("Infected %i: \"%N\" was ducking and were unducked.", client, client);
		}
	}

	return Plugin_Continue;
}

bool:IsTrueClient(client)
{
	return !g_bTriggerCrouch[client] && client && IsClientInGame(client) && IsPlayerAlive(client);
}

bool:IsUseDuckingExpolit(client)
{
	if (GetEntProp(client, Prop_Send, "m_nDuckTimeMsecs") == 1000)
		return false;

	static iButtons;
	iButtons = GetClientButtons(client);

	if (!(iButtons & IN_DUCK) && !(iButtons & IN_JUMP) && GetEntProp(client, Prop_Send, "m_bDucked") &&
		!GetEntProp(client, Prop_Send, "m_bDucking") && GetEntPropFloat(client, Prop_Send, "m_flFallVelocity") == 0)
		return true;

	return false;
}

bool:IsGuyTroll(victim, troll)
{
	return IsOnLadder(victim) && GetClientTeam(victim) != GetClientTeam(troll) && GetEntPropFloat(victim, Prop_Send, "m_vecOrigin[2]") < GetEntPropFloat(troll, Prop_Send, "m_vecOrigin[2]");
}

public Action:_IF_SDKh_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (damagetype & DMG_BULLET && IsClientAndInGame(attacker) && IsIncapacitated(attacker) && GetClientTeam(attacker) == 2 &&
		IsClientAndInGame(victim) && GetClientTeam(victim) == 2) return Plugin_Handled;

	return Plugin_Continue;
}

static		Handle:g_hDecayRate, Float:g_fCvarDecayRate, Handle:g_hTimer[MAXPLAYERS+1], Float:g_fTempHp[MAXPLAYERS+1];

_EF_SetupPLFunction(bool:bHook)
{
	if (bHook){

		if (!g_bIsEngineFixLoaded){

			DebugLog("%s _EF_SetupPLFunction() Hook EngineFix Events", EF_TAG);

			HookEvent("pills_used", EF_ev_PillsUsed);
			HookEvent("heal_success", EF_ev_HealSuccess);
		}
		if (!g_bIsHealthExpolitFixLoaded){

			DebugLog("%s _EF_SetupPLFunction() Hook HelthExpolitFix Events", EF_TAG);

			HookEvent("player_ledge_grab", HE_ev_PlayerLedgeGrab);
			HookEvent("revive_success", HE_ev_ReviveSuccess);
		}
		if (!g_bIsEngineFixLoaded || !g_bIsHealthExpolitFixLoaded){

			DebugLog("%s _EF_SetupPLFunction() Hook pain_pills_decay_rate convar", EF_TAG);

			g_hDecayRate = FindConVar("pain_pills_decay_rate");

			HookConVarChange(g_hDecayRate, _EF_OnCvarChange_PillsRate);
			Update_EF_PillsRateConVars();
		}

		HookEvent("player_incapacitated", HE_ev_PlayerIncapacitated);
	}
	else {

		if (!g_bIsEngineFixLoaded){

			DebugLog("%s _EF_SetupPLFunction() Unhook EngineFix Events", EF_TAG);

			UnhookEvent("pills_used", EF_ev_PillsUsed);
			UnhookEvent("heal_success", EF_ev_HealSuccess);
		}
		if (!g_bIsHealthExpolitFixLoaded){

			DebugLog("%s _EF_SetupPLFunction() Unhook HelthExpolitFix Events", EF_TAG);

			UnhookEvent("player_ledge_grab", HE_ev_PlayerLedgeGrab);
			UnhookEvent("revive_success", HE_ev_ReviveSuccess);
		}
		if (!g_bIsEngineFixLoaded || !g_bIsHealthExpolitFixLoaded){

			DebugLog("%s _EF_SetupPLFunction() Unhook pain_pills_decay_rate convar", EF_TAG);

			UnhookConVarChange(g_hDecayRate, _EF_OnCvarChange_PillsRate);
		}

		UnhookEvent("player_incapacitated", HE_ev_PlayerIncapacitated);
	}
}

public bool:_EF_OnPlayerRunCmd(client)
{
	return IsPlayerAlive(client) && !IsFakeClient(client) && GetEntityMoveType(client) == MOVETYPE_LADDER;
}

public bool:_EF_OnPlayerRunCmdTwo(client, buttons)
{
	return buttons & IN_USE && GetClientTeam(client) == 2 && GetEntPropFloat(client, Prop_Send, "m_flFallVelocity") > 440;
}

public Action:EF_ev_PillsUsed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (DrownNotEqual(client)){
		TimeToKill(client);
		g_hTimer[client] = CreateTimer(0.1, EF_t_FixPillsGlitch, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:EF_ev_HealSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	new healer = GetClientOfUserId(GetEventInt(event, "userid"));
	new client = GetClientOfUserId(GetEventInt(event, "subject"));

	if (DrownNotEqual(healer) || DrownNotEqual(client)){
		new id;

		if (DrownNotEqual(healer))
			id = healer;
		else
			id = client;

		TimeToKill(id);
		g_hTimer[id] = CreateTimer(0.1, EF_t_FixPillsGlitch, id, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:EF_t_FixPillsGlitch(Handle:timer, any:client)
{
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && DrownNotEqual(client)){

		if ((CalculateLife(client) > 100 || GetClientHealth(client) == 100) && !IsIncapacitated(client)){

			if (CalculateLife(client) > 100){

				new Float:fProp = (CalculateLife(client) - 100) + (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fCvarDecayRate;
				SetEntPropFloat(client, Prop_Send, "m_healthBuffer", GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - fProp);
			}

			SetEntProp(client, Prop_Data, "m_idrownrestored", GetEntProp(client, Prop_Data, "m_idrowndmg"));
			TimeToKill(client);
		}
	}
	else
		TimeToKill(client);
}

TimeToKill(client)
{
	if (g_hTimer[client] != INVALID_HANDLE){

		KillTimer(g_hTimer[client]);
		g_hTimer[client] = INVALID_HANDLE;
	}
}

// @ Code by SilverShot
CalculateLife(client)
{
	new Float:fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fCvarDecayRate);
	return fHealth < 0 ? 0 : (RoundToFloor(fHealth) + GetClientHealth(client));
}

bool:DrownNotEqual(client)
{
	return GetEntProp(client, Prop_Data, "m_idrowndmg") != GetEntProp(client, Prop_Data, "m_idrownrestored");
}

public Action:HE_ev_PlayerIncapacitated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (GetClientTeam(client) == 2){

		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	}
}

public Action:HE_ev_PlayerLedgeGrab(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if ((g_fTempHp[client] = GetSuvivorTempHealth(client)))
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
}

public Action:HE_ev_ReviveSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!GetEventBool(event, "ledge_hang")) return;

	new client = GetClientOfUserId(GetEventInt(event, "subject"));

	if (g_fTempHp[client])
		CreateTimer(0.0, HE_t_PreRestoreHealth, client);
	else if (GetClientHealth(client) < 30)
		SetSurvivorTempHealth(client);
}

public Action:HE_t_PreRestoreHealth(Handle:timer, any:client)
{
	if (IsClientInGame(client))
		SetSurvivorTempHealth(client);
}

Float:GetSuvivorTempHealth(client)
{
	new Float:fHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * g_fCvarDecayRate;
	return fHealth < 0.0 ? 0.0 : fHealth;
}

SetSurvivorTempHealth(client)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", g_fTempHp[client]);
}

public _EF_OnCvarChange_PillsRate(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	Update_EF_PillsRateConVars();
}

Update_EF_PillsRateConVars()
{
	g_fCvarDecayRate = GetConVarFloat(g_hDecayRate);
}

/**
 * Wrapper for printing a debug message without having to define channel index
 * everytime.
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
static DebugPrintToAllEx(const String:format[], any:...)
{
	decl String:buffer[DEBUG_MESSAGE_LENGTH];
	VFormat(buffer, sizeof(buffer), format, 2);
	DebugPrintToAll(g_iDebugChannel, buffer);
}