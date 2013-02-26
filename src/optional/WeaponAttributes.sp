#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <l4d_lib>

public Plugin:myinfo =
{
	name = "[L4D] Weapon Attributes",
	author = "raziEiL [disawar1]",
	description = "Allowing tweaking of some weapons attributes.",
	version = "1.0",
	url = "http://steamcommunity.com/id/raziEiL"
};

#define debug 0

#define TAG					"[WeaponAttr]"

#define WEAPONS_LIMIT		6
#define NULL	-1

// @Credits Verminkin "Celentes" - Thanks for a lot of mathematical calculations to find the right formula.
#define C_PROPORTION(%1,%2) (%1/%2)

enum ATTR_LIMIT
{
	Float:DAMAGE,
	Float:TANKDMG
};

enum WEAP_STRUCTURE
{
	String:sName[24],
	Float:fDmg
};

static const g_aWeapBaseDB[WEAPONS_LIMIT][WEAP_STRUCTURE] =
{
	{ "pistol",			36.0 },
	{ "smg",			20.0 },
	{ "pumpshotgun",	25.0 },
	{ "autoshotgun",	25.0 },
	{ "rifle",			33.0 },
	{ "hunting_rifle",	90.0 }
};

static const String:g_sAttribute[ATTR_LIMIT][] =
{
	"damage",
	"tankdamage"
};

static		Handle:g_hAllowAttr, bool:g_bCvarAllowAttr, Float:g_fWeapAttrDB[WEAPONS_LIMIT][ATTR_LIMIT], bool:g_bLoadLater;

public OnPluginStart()
{
	g_hAllowAttr = CreateConVar("allow_weapon_attributes", "1");

	HookConVarChange(g_hAllowAttr, OnCvarChange_AllowAttr);
	WA_GetCvars();

	RegServerCmd("add_attribute",	CmdWeapAttr);
	RegServerCmd("wipe_attributes",	CmdWipeAttr);
	RegConsoleCmd("sm_attrlist",	CmdAttrList, "Print all the attributes of weapons to console.");

	if (g_bLoadLater && g_bCvarAllowAttr)
		WA_ToogleHook(true);
}

public Action:CmdWeapAttr(args)
{
	if (args != 3){

		PrintToServer("%s weap_attribute <weapon> <attribute> <val>", TAG);
		return Plugin_Handled;
	}

	decl String:sInput[2][64], iWeapIndex;
	GetCmdArg(1, sInput[0], 64);

	if ((iWeapIndex = IsWeapValid(sInput[0])) == NULL){

		PrintToServer("%s Invalid weapon <%s>", TAG, sInput[0]);
		return Plugin_Handled;
	}

	decl iAttr;
	GetCmdArg(2, sInput[1], 64);

	if ((iAttr = IsAttributeValid(sInput[1])) == NULL){

		PrintToServer("%s Invalid attribute type <%s>", TAG, sInput[1]);
		return Plugin_Handled;
	}

	GetCmdArg(3, sInput[1], 64);
	new iDmg = StringToInt(sInput[1]);

	if (iDmg < -1 || g_aWeapBaseDB[iWeapIndex][fDmg] == iDmg){

		PrintToServer("%s Parameter is ignored %d. (-1: damage blocked, 0: wipe attr, >0: damage).", TAG, iDmg);
		return Plugin_Handled;
	}

	g_fWeapAttrDB[iWeapIndex][iAttr] = float(iDmg);

	PrintToServer("%s Tweaking for the %s is added", TAG, sInput[0]);

	return Plugin_Handled;
}

public Action:CmdWipeAttr(agrs)
{
	PrintToServer("%s All attributes wiped", TAG);

	for (new INDEX; INDEX < WEAPONS_LIMIT; INDEX++){

		g_fWeapAttrDB[INDEX][DAMAGE] = 0.0;
		g_fWeapAttrDB[INDEX][TANKDMG] = 0.0;
	}

	return Plugin_Handled;
}

static g_hTempBlock[MAXPLAYERS+1];

public Action:CmdAttrList(client, agrs)
{
	if (g_hTempBlock[client]) return Plugin_Handled;

	if (client)
		PrintToChat(client, "%s Printed to console.", TAG);

	PrintToConsole(client, "\n%s #		| damage/diff	| tankdmg/diff	| weapon", TAG);
	PrintToConsole(client, "%s ---------------------------------------------------", TAG);

	for (new INDEX; INDEX < WEAPONS_LIMIT; INDEX++)
		PrintToConsole(client, "%s 0%d.	| %.0f	(%.0f)	| %.0f	(%.0f)	| %s", TAG, INDEX + 1, g_fWeapAttrDB[INDEX][DAMAGE],
		(g_fWeapAttrDB[INDEX][DAMAGE] ? (g_fWeapAttrDB[INDEX][DAMAGE] - g_aWeapBaseDB[INDEX][fDmg]) : 0.0),
		g_fWeapAttrDB[INDEX][TANKDMG],
		(g_fWeapAttrDB[INDEX][TANKDMG] ? (g_fWeapAttrDB[INDEX][TANKDMG] - g_aWeapBaseDB[INDEX][fDmg]) : 0.0),
		g_aWeapBaseDB[INDEX][sName]);

	if (!client || GetUserFlagBits(client)) return Plugin_Handled;

	g_hTempBlock[client] = true;
	CreateTimer(10.0, WA_t_Unlock, client);

	return Plugin_Handled;
}

public Action:WA_t_Unlock(Handle:timer, any:client)
{
	g_hTempBlock[client] = false;
}

public OnClientPutInServer(client)
{
	if (g_bCvarAllowAttr && client)
		SDKHook(client, SDKHook_OnTakeDamage, WA_SDKh_OnTakeDamage);
}

public Action:WA_SDKh_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (damageType & DMG_BULLET && IsClient(victim) && GetClientTeam(victim) == 3){

		decl String:sClassName[24], iWeapIndex;
		GetClientWeapon(attacker, sClassName, 24);

		if ((iWeapIndex = IsWeapValid(sClassName[7])) == NULL){

			#if debug
				PrintToChatAll("invalid weap %s", sClassName);
			#endif

			return Plugin_Continue;
		}

		decl Float:fNewDmg;
		if ((fNewDmg = g_fWeapAttrDB[iWeapIndex][IsPlayerTank(victim) ? TANKDMG : DAMAGE]) == 0){

			#if debug
				PrintToChatAll("attr not registered for %s", sClassName);
			#endif

			return Plugin_Continue;
		}

		if (fNewDmg == NULL) return Plugin_Handled;

		#if debug
			new Float:fOldDmg = damage;
		#endif

		damage *= C_PROPORTION(fNewDmg, g_aWeapBaseDB[iWeapIndex][fDmg]);

		#if debug
			PrintToChatAll("dmg %.1f, new dmg %.1f", fOldDmg, damage);
		#endif

		if (damage > 0)
			return Plugin_Changed;

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

IsWeapValid(const String:sWeapon[])
{
	for (new INDEX; INDEX < WEAPONS_LIMIT; INDEX++)
		if (StrEqual(sWeapon, g_aWeapBaseDB[INDEX][sName])) return INDEX;

	return NULL;
}

IsAttributeValid(const String:sAttribute[])
{
	for (new INDEX; INDEX < _:ATTR_LIMIT; INDEX++)
		if (StrEqual(sAttribute, g_sAttribute[INDEX])) return INDEX;

	return NULL;
}

WA_ToogleHook(bool:bHook)
{
	for (new i = 1; i <= MaxClients; i++){

		if (!IsClientInGame(i)) continue;

		if (bHook)
			SDKHook(i, SDKHook_OnTakeDamage, WA_SDKh_OnTakeDamage);
		else
			SDKUnhook(i, SDKHook_OnTakeDamage, WA_SDKh_OnTakeDamage);
	}
}

public OnCvarChange_AllowAttr(Handle:convar_hndl, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	WA_GetCvars();

	if (!StringToInt(oldValue))
		WA_ToogleHook(true);
	else if (!g_bCvarAllowAttr)
		WA_ToogleHook(false);
}

WA_GetCvars()
{
	g_bCvarAllowAttr = GetConVarBool(g_hAllowAttr);
}
