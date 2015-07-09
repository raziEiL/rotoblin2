/*
 * ============================================================================
 *
 *  Original modified Rotoblin module
 *
 *  File:			limithuntingrifle
 *  Type:			Module
 *  Description:	Adds a limit to hunting rifles for the survivors.
 *
 *  Copyright (C) 2012-2015  raziEiL <war4291@mail.ru>
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com
 *
 *  Rotoblin is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Rotoblin is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Rotoblin.  If not, see <http://www.gnu.org/licenses/>.
 *
 * ============================================================================
 */

/*
 * ==================================================
 *                     Variables
 * ==================================================
 */

/*
 * --------------------
 *       Private
 * --------------------
 */

static	const	Float:	TIP_TIMEOUT						= 8.0;
static			bool:	g_bHaveTipped[MAXPLAYERS + 1];

static Handle:g_hLimit[WEAPONS_LIMIT], g_iCvarLimit[WEAPONS_LIMIT];

/**
 * Called on plugin start.
 *
 * @noreturn
 */
_LimitHuntingRifl_OnPluginStart()
{
	decl String:sCvar[64], String:sDescr[256];

	for (new i; i < WEAPONS_LIMIT; i++){

		FormatEx(sCvar, 64, "limit_%s", g_sWeapon_Names[i][CVAR]);
		FormatEx(sDescr, 256, "Maximum number of %ss that can be equipped by the Survivor team. (-1: unlimited, 0: not allowed, > 0: limits in according with cvar value).", g_sWeapon_Names[i][NAME]);
		g_hLimit[i] = CreateConVarEx(sCvar, "-1", sDescr, _, true, -1.0);
	}
}

/**
 * Called on plugin enabled.
 *
 * @noreturn
 */
_LHR_OnPluginEnabled()
{
	_LHR_GetCvars();

	for (new i; i < WEAPONS_LIMIT; i++)
		HookConVarChange(g_hLimit[i], _LHR_OnCvarChange_Limit);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKHook(client, SDKHook_WeaponCanUse, _LHR_SDKh_OnWeaponCanUse);
	}
}

/**
 * Called on plugin disabled.
 *
 * @noreturn
 */
_LHR_OnPluginDisabled()
{
	for (new i; i < WEAPONS_LIMIT; i++)
		UnhookConVarChange(g_hLimit[i], _LHR_OnCvarChange_Limit);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client)) continue;
		SDKUnhook(client, SDKHook_WeaponCanUse, _LHR_SDKh_OnWeaponCanUse);
	}
}

/**
 * Called on client put in server.
 *
 * @param client		Client index.
 * @noreturn
 */
_LHR_OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponCanUse, _LHR_SDKh_OnWeaponCanUse);
}


/**
 * Called on weapon can use.
 *
 * @param client		Client index.
 * @param weapon		Weapon entity index.
 * @return				Plugin_Continue to allow weapon usage, Plugin_Handled
 *						to disallow weapon usage.
 */
public Action:_LHR_SDKh_OnWeaponCanUse(client, weapon)
{
	if (GetClientTeam(client) != TEAM_SURVIVOR) return Plugin_Continue;

	decl iWeap;
	if ((iWeap = GetWeaponIndexByClassEx(weapon)) == NULL || g_iCvarLimit[iWeap] == NULL) return Plugin_Continue;

	if (iWeap == WEAPINDEX_SNIPER && IsFakeClient(client) && IsVersusMode()) return Plugin_Handled;

	decl icurWeapon;
	if ((icurWeapon = GetPlayerWeaponSlot(client, 0)) != NULL && IsValidEntity(icurWeapon)){

		decl String:sClassName[64];
		GetEntityClassname(icurWeapon, sClassName, 64);

		// Survivor already got a weapon and trying to pick up a ammo refill, allow it
		if (StrEqual(sClassName, g_sWeapon_Names[iWeap][CLASS])) return Plugin_Continue;
	}

	if (g_bBlackSpot) return Plugin_Handled;

	if (GetActiveWeap(g_sWeapon_Names[iWeap][CLASS]) >= g_iCvarLimit[iWeap]) // If ammount of active weapons are at the limit
	{
		if (!IsFakeClient(client) && !g_bHaveTipped[client])
		{
			g_bHaveTipped[client] = true;

			if (g_iCvarLimit[iWeap] > 0)
				PrintToChat(client, "%s %s weapon group has reached its max of %d", MAIN_TAG, g_sWeapon_Names[iWeap][NAME], g_iCvarLimit[iWeap]);
			else
				PrintToChat(client, "%s %s is not allowed.", MAIN_TAG, g_sWeapon_Names[iWeap][NAME]);

			CreateTimer(TIP_TIMEOUT, _LHR_Tip_Timer, client);
		}
		return Plugin_Handled; // Dont allow survivor picking up the weapon
	}

	return Plugin_Continue;
}

public Action:_LHR_Tip_Timer(Handle:timer, any:client)
{
	g_bHaveTipped[client] = false;
}

static GetActiveWeap(const String:sWeapClassName[])
{
	decl String:classname[64], weapon;
	new count;

	for (new i = 0; i < SurvivorCount; i++)
	{
		if (SurvivorIndex[i] <= 0 || !IsClientInGame(SurvivorIndex[i]) || !IsPlayerAlive(SurvivorIndex[i])) continue;

		if ((weapon = GetPlayerWeaponSlot(SurvivorIndex[i], 0)) == NULL || !IsValidEntity(weapon)) continue;

		GetEntityClassname(weapon, classname, 64);
		if (!StrEqual(classname, sWeapClassName)) continue;
		count++;
	}
	return count;
}

public _LHR_OnCvarChange_Limit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	_LHR_GetCvars();
}

static _LHR_GetCvars()
{
	for (new i; i < WEAPONS_LIMIT; i++)
		g_iCvarLimit[i] = GetConVarInt(g_hLimit[i]);
}

stock _LHR_CvarDump()
{
	decl iVal;
	for (new i; i < WEAPONS_LIMIT; i++)
		if ((iVal = GetConVarInt(g_hLimit[i])) != g_iCvarLimit[i])
			DebugLog("%d		|	%d		|	rotoblin_limit_%s", iVal, g_iCvarLimit[i], g_sWeapon_Names[i][CVAR]);
}
