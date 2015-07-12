/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *  File:			rotoblin.weaponcontrol.sp
 *  Type:			Module
 *  Description:	Replaces tier 2 weapons with tier 1
 *
 *  Copyright (C) 2012-2015  raziEiL <war4291@mail.ru>
 *  Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
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

// --------------------
//       Public
// --------------------
#define WC_TAG "[WeapControl]"

enum WEAPON_STYLE
{
	REPLACE_REMOVE = -1,
	REPLACE_NO_WEAPONS, // Don't replace any tier 2 weapons
	REPLACE_ALL_WEAPONS, // Replace all tier 2 weapons
	REPLACE_ALL_RIFLE,
	REPLACE_ALL_AUTOSHOTGUN
}

enum WEAPON_REPLACEMENT_ATTRIBUTES
{
	WEAPON_CLASSNAME,
	WEAPON_MODEL,
	WEAPON_REPLACECLASSNAME,
	WEAPON_REPLACEMODEL
}

#define WEAPON_REPLACEMENT_TOTAL 2 // Total amount of weapons to replace

// --------------------
//       Private
// --------------------

static	const	String:	WEAPON_REPLACEMENT_ARRAY[WEAPON_REPLACEMENT_TOTAL][WEAPON_REPLACEMENT_ATTRIBUTES][] =
{
	// Assult rifle
	{
		"weapon_rifle_spawn",							// Classname
		"models/w_models/weapons/w_rifle_m16a2.mdl",	// Model
		"weapon_smg_spawn",								// Replacement classname
		"models/w_models/weapons/w_smg_uzi.mdl"			// Replacement model
	},

	// Auto shotgun
	{
		"weapon_autoshotgun_spawn",							// Classname
		"models/w_models/weapons/w_autoshot_m4super.mdl",	// Model
		"weapon_pumpshotgun_spawn",							// Replacement classname
		"models/w_models/weapons/w_shotgun.mdl"				// Replacement model
	}
};

static	const			DEFAULT_WEAPON_COUNT			= 5;
static	const	Float:	REPLACE_DELAY					= 0.1; /* This is for OnEntityCreated, it needs a small delay before being
															    * able to replace the tier 2 weapon. */

static			Handle:	g_hWeaponsArray					= INVALID_HANDLE;
static	const			ARRAY_WEAPON_CELL_SIZE			= 128;
static	const			ARRAY_WEAPON_BLOCK				= 4; /* How many indexes a single weapon takes. Example a weapon takes 4 slots
															  * because first index is classname, then model, origin and rotation. So
															  * thats index 4, 5, 6 and 7 in the array. */

static					g_iDebugChannel					= 0;
static	const	String:	DEBUG_CHANNEL_NAME[]			= "WeaponControl";
static bool:g_bSkip;
static Handle:g_hDebugArray;
static Handle:g_hOSF_Style, Handle:g_hSSR_Style, Handle:g_hESR_Style, Handle:g_hFSR_Style, g_iCvarOSF_Style, g_iCvarSSR_Style, g_iCvarESR_Style, g_iCvarFSR_Style;
// **********************************************
//                   Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
_WeaponControl_OnPluginStart()
{
	g_hSSR_Style = CreateConVarEx("replace_startweapons", "0", "How weapons will be replaced in the saferoom. (-1: remove weapons, 0: director settings, 1: replace with their tier 1 analogue, 2: replace only rifles, 3: replace only shotgun)", _, true, -1.0, true, 3.0);
	g_hOSF_Style = CreateConVarEx("replace_outsideweapons", "0", "How weapons will be replaced out of saferooms. (-1: remove weapons, 0: director settings, 1: replace with their tier 1 analogue, 2: replace only rifles, 3: replace only shotguns)", _, true, -1.0, true, 3.0);
	g_hESR_Style = CreateConVarEx("replace_endweapons", "0", "How weapons will be replaced in the end saferoom. (-1: remove weapons, 0: director settings, 1: replace with their tier 1 analogue, 2: replace only rifles, 3: replace only shotgun)", _, true, -1.0, true, 3.0);
	g_hFSR_Style = CreateConVarEx("replace_finaleweapons", "0", "How weapons will be replaced on finals. (-1: remove weapons, 0: director settings, 1: replace with their tier 1 analogue, 2: replace only rifles, 3: replace only shotgun)", _, true, -1.0, true, 3.0);

	g_iDebugChannel = DebugAddChannel(DEBUG_CHANNEL_NAME);
	DebugPrintToAllEx("Module is now setup");
}

/**
 * Plugin is now enabled.
 *
 * @noreturn
 */
_WC_OnPluginEnabled()
{
	g_hWeaponsArray = CreateArray(ARRAY_WEAPON_CELL_SIZE);
	g_hDebugArray = CreateArray(ARRAY_WEAPON_CELL_SIZE);
	if (g_hWeaponsArray == INVALID_HANDLE)
	{
		ThrowError("Failed to create weapons array");
	}

	HookEvent("round_start", _WC_RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", _WC_RoundEnd_Event, EventHookMode_PostNoCopy);

	HookConVarChange(g_hOSF_Style, _WC_WeaponStyleOSF_CvarChange);
	HookConVarChange(g_hSSR_Style, _WC_WeaponStyleSSR_CvarChange);
	HookConVarChange(g_hESR_Style, _WC_WeaponStyleESR_CvarChange);
	HookConVarChange(g_hFSR_Style, _WC_WeaponStyleFSR_CvarChange);
	Update_WC_ConVars();

	DebugPrintToAllEx("Module is now loaded");
}

/**
 * Plugin is now disabled.
 *
 * @noreturn
 */
_WC_OnPluginDisabled()
{
	UnhookEvent("round_start", _WC_RoundStart_Event, EventHookMode_PostNoCopy);
	UnhookEvent("round_end", _WC_RoundEnd_Event, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hOSF_Style, _WC_WeaponStyleOSF_CvarChange);
	UnhookConVarChange(g_hSSR_Style, _WC_WeaponStyleSSR_CvarChange);
	UnhookConVarChange(g_hESR_Style, _WC_WeaponStyleESR_CvarChange);
	UnhookConVarChange(g_hFSR_Style, _WC_WeaponStyleFSR_CvarChange);

	CloseHandle(g_hWeaponsArray);
	g_hWeaponsArray = INVALID_HANDLE;
	CloseHandle(g_hDebugArray);
	DebugPrintToAllEx("Module is now unloaded");
}

/**
 * Map is ending.
 *
 * @noreturn
 */
_WC_OnMapEnd()
{
	g_bSkip = false;
	DebugPrintToAllEx("Map end");
}

/**
 * Called when round start event is fired.
 *
 * @param event			INVALID_HANDLE (post no copy data hook).
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _WC_RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	DebugPrintToAllEx("Round start - Will replace weapons");

	ClearArray(g_hWeaponsArray); // Clear weapons array from last round
	CreateTimer(0.6, _WC_t_RoundStartDelay);
}

public Action:_WC_t_RoundStartDelay(Handle:timer)
{
	if (g_hWeaponsArray == INVALID_HANDLE) return;

	ClearArray(g_hDebugArray);

	// Replace all tier 2 weapons that are already spawned
	for (new i = 0; i < WEAPON_REPLACEMENT_TOTAL; i++)
	{
		ReplaceAll(WEAPON_REPLACEMENT_ARRAY[i][WEAPON_CLASSNAME],
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_MODEL],
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACECLASSNAME],
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACEMODEL],
			DEFAULT_WEAPON_COUNT);
	}
	for (new i = 0; i < WEAPONS_LIMIT; i++){
		if (i == WEAPINDEX_AUTO || i == WEAPINDEX_RIFLE) continue;
		ReplaceAll(g_sWeapon_Names[i][CLASS], "", "", "", 0);
	}

	g_bSkip = true;

	//R2COMP_LOG
	decl Float:temp[3], String:tempStr[64], String:tempStr2[64];
	new len = GetArraySize(g_hDebugArray);
	for (new saferoom = 1; saferoom <= 4; saferoom++){

		DebugLog("%s %s", WC_TAG, saferoom == 1 ? "Start saferoom" : saferoom == 2 ? "Outside saferoom"  : saferoom == 4 ? "Finale saferoom" : "End saferoom");
		DebugLog("%s {", WC_TAG);
		for (new i = 0; i < len; i += 4){

			if (GetArrayCell(g_hDebugArray, i + 2) == saferoom){

				GetArrayArray(g_hDebugArray, i + 1, temp, 3);
				GetArrayString(g_hDebugArray, i + 3, tempStr, 64);
				GetArrayString(g_hDebugArray, i, tempStr2, 64);
				DebugLog("%s %s (%.1f %.1f %.1f) [Action: %s]", WC_TAG, tempStr2, temp[0], temp[1], temp[2], tempStr);
			}
		}
		DebugLog("%s }", WC_TAG);
	}
}

/**
 * Called when round end event is fired.
 *
 * @param event			INVALID_HANDLE (post no copy data hook).
 * @param name			String containing the name of the event.
 * @param dontBroadcast	True if event was not broadcast to clients, false otherwise.
 * @noreturn
 */
public _WC_RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	DebugPrintToAllEx("Round end");
	g_bSkip = false;

	if (GetArraySize(g_hWeaponsArray) > 0) // If weapons array is not empty
	{
		RestoreAllTier2(); // Restore all tier 2 weapons from array
		ClearArray(g_hWeaponsArray); // Clear array
	}
}

/**
 * When an entity is created.
 *
 * @param entity		Entity index.
 * @param classname		Classname.
 * @noreturn
 */
_WC_OnEntityCreated(entity, const String:classname[])
{
	if (!g_bSkip) return;

	for (new i = 0; i < WEAPON_REPLACEMENT_TOTAL; i++)
	{
		if (!StrEqual(classname, WEAPON_REPLACEMENT_ARRAY[i][WEAPON_CLASSNAME])) continue;
		new ref = EntIndexToEntRef(entity);

		DebugPrintToAllEx("OnEntityCreated - Late spawned tier 2. Entity %i (ref %i), classname \"%s\", new classname \"%s\"",
			entity,
			ref,
			classname,
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACECLASSNAME]);

		ReplaceTier2_Delayed(ref,
			classname,
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_MODEL],
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACECLASSNAME],
			WEAPON_REPLACEMENT_ARRAY[i][WEAPON_REPLACEMODEL],
			DEFAULT_WEAPON_COUNT,
			REPLACE_DELAY);
	}
	for (new i = 0; i < WEAPONS_LIMIT; i++){
		if (i == WEAPINDEX_AUTO || i == WEAPINDEX_RIFLE || !StrEqual(classname, g_sWeapon_Names[i][CLASS])) continue;
		new ref = EntIndexToEntRef(entity);
		ReplaceTier2_Delayed(ref, g_sWeapon_Names[i][CLASS], "", "", "", 0, REPLACE_DELAY);
	}
}

/**
 * Called when the replace tier 2 timer interval has elapsed.
 *
 * @param timer			Handle to the timer object.
 * @param data			Data passed to CreateTimer() when timer was created.
 * @noreturn
 */
public Action:_WC_ReplaceTier2_Delayed_Timer(Handle:timer, Handle:pack)
{
	decl String:classname[256], String:model[256], String:newClassname[256], String:newModel[256];

	// Read data pack
	ResetPack(pack);
	new entity = EntRefToEntIndex(ReadPackCell(pack));
	ReadPackString(pack, classname, sizeof(classname));
	ReadPackString(pack, model, sizeof(model));
	ReadPackString(pack, newClassname, sizeof(newClassname));
	ReadPackString(pack, newModel, sizeof(newModel));
	new count = ReadPackCell(pack);
	CloseHandle(pack);

	/* Check for entity invalidation */
	new bool:entInvalid = false;
	if (entity < 0 || entity > MAX_EDICTS || !IsValidEntity(entity))
	{
		DebugPrintToAllEx("ERROR: Replaced delayed tier 2 weapon; Entity index invalided! Entity %i, classname \"%s\", new classname \"%s\", count %i", entity, classname, newClassname, count);
		entInvalid = true;
	}
	else
	{
		decl String:buffer[256];
		GetEntityClassname(entity, buffer, sizeof(buffer));
		if (StrEqual(classname, buffer))
		{
			DebugPrintToAllEx("ERROR: Replaced delayed tier 2 weapon; Entity classname invalided! Entity %i, classname \"%s\", new classname \"%s\", count %i", entity, buffer, newClassname, count);
			entInvalid = true;
		}
	}

	if (entInvalid) // Oh no, we lost a tier 2
	{
		DebugPrintToAllEx("ERROR: Replaced delayed tier 2 weapon; Lost a tier 2 weapon! Time to panic, search for all tier 2 weapons of that classname!");
		ReplaceAll(classname, model, newClassname, newModel, count); // Time to panic
		return;
	}

	Replace(entity, classname, model, newClassname, newModel, count); // Replace with tier 1
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Replaces entity index with provided entity classname, with same origin and
 * rotation.
 *
 * @param entityRef		Entity reference to replace.
 * @param classname		Entity's classname.
 * @param model			Entity model path.
 * @param newClassname	Entity replacement classname.
 * @param newModel		Entity replacement model path.
 * @param count			Item count.
 * @param time			How much time before replacing the entity.
 * @noreturn
 */
static ReplaceTier2_Delayed(entityRef, const String:classname[], const String:model[], const String:newClassname[], const String:newModel[], count, const Float:time)
{
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, entityRef);
	WritePackString(pack, classname);
	WritePackString(pack, model);
	WritePackString(pack, newClassname);
	WritePackString(pack, newModel);
	WritePackCell(pack, count);
	CreateTimer(time, _WC_ReplaceTier2_Delayed_Timer, pack);
}

/**
 * Stores the entity's classname, model, origin and rotation in the weapons array.
 *
 * @param entity		Entity to store.
 * @param classname		Entity's classname.
 * @param model			Entity's model path.
 * @noreturn
 */
static StoreTier2(entity, const String:model[])
{
	decl Float:origin[3], Float:rotation[3], String:classname[ARRAY_WEAPON_CELL_SIZE];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", rotation);
	GetEntityClassname(entity, classname, ARRAY_WEAPON_CELL_SIZE);

	PushArrayString(g_hWeaponsArray, classname);
	PushArrayString(g_hWeaponsArray, model);
	PushArrayArray(g_hWeaponsArray, origin, 3);
	PushArrayArray(g_hWeaponsArray, rotation, 3);

	DebugPrintToAllEx("Stored tier 2 info; classname \"%s\", model \"%s\", origin %f %f %f, rotation %f %f %f", classname, model, origin[0], origin[1], origin[2], rotation[0], rotation[1], rotation[2]);
}

/**
 * Stores and replaces all entities with same classname with another provided classname, model and item count
 *
 * @param classname		Entity classname to replace.
 * @param model			Entity's model path.
 * @param newClassname	Entity replacement classname.
 * @param newModel		Entity's new model path.
 * @param count			Item count.
 * @noreturn
 */
static ReplaceAll(const String:classname[], const String:model[], const String:newClassname[], const String:newModel[], count)
{
	DebugPrintToAllEx("Replacing all tier 2 weapons; classname \"%s\", new classname \"%s\", count %i", classname, newClassname, count);
	new entity = -1;
	while ((entity = FindEntityByClassnameEx(entity, classname)) != -1)
	{
		Replace(entity, classname, model, newClassname, newModel, count);
	}
}

static Replace(entity, const String:classname[], const String:model[], const String:newClassname[], const String:newModel[], count)
{
	decl Float:vOrg[3];
	GetEntityOrg(entity, vOrg);
	if (IsVectorNull(vOrg)) return;

	decl result, String:temp[64];
	PushArrayString(g_hDebugArray, classname);
	PushArrayArray(g_hDebugArray, vOrg, 3);

	switch (CaseWeaponStyle(GetWeaponStyleByLocation(vOrg), classname))
	{
		case 0:
		{
			for (new i = 1; i <= 3; i++)
				RemoveFromArray(g_hDebugArray, GetArraySize(g_hDebugArray) - i);
		}
		case -1:
		{
			SafelyRemoveEdict(entity);
			PushArrayString(g_hDebugArray, "remove");
		}
		case 1:
		{
			StoreTier2(entity, model);
			PushArrayString(g_hDebugArray, "skip");
		}
		case 2:
		{
			FormatEx(temp, 64, "replace to %s", newClassname);
			PushArrayString(g_hDebugArray, temp);

			StoreTier2(entity, model); // Store tier 2 info in array
			if (!(result = ReplaceEntity(entity, newClassname, newModel, count))) // If failed to replace
			{
				DebugPrintToAllEx("ERROR: Failed to replace tier 2 weapon! Entity %i, classname \"%s\", new classname \"%s\", model \"%s\"", entity, classname, newClassname, newModel);
				ThrowError("Failed to replace tier 2 weapon! Entity %i, classname \"%s\", new classname \"%s\", model \"%s\"", entity, classname, newClassname, newModel);
			}
			DebugPrintToAllEx("Replaced tier 2 weapon; entity %i, classname \"%s\", new entity %i, new classname \"%s\", count %i", entity, classname, result, newClassname, count);
		}
	}
}

static CaseWeaponStyle(WEAPON_STYLE:style, const String:classname[])
{
	if (style != REPLACE_REMOVE && (StrEqual(classname, g_sWeapon_Names[WEAPINDEX_SMG][CLASS]) || StrEqual(classname, g_sWeapon_Names[WEAPINDEX_PUMP][CLASS]) ||
		StrEqual(classname, g_sWeapon_Names[WEAPINDEX_SNIPER][CLASS])))
		return 0;
	switch (style)
	{
		case REPLACE_REMOVE:
			return -1;
		case REPLACE_NO_WEAPONS:
			return 1;
		case REPLACE_ALL_WEAPONS:
			return 2;
		case REPLACE_ALL_RIFLE:
		{
			if (StrEqual(classname, WEAPON_REPLACEMENT_ARRAY[0][WEAPON_CLASSNAME]))
				return 2;
			return 1;
		}
		case REPLACE_ALL_AUTOSHOTGUN:
		{
			if (StrEqual(classname, WEAPON_REPLACEMENT_ARRAY[1][WEAPON_CLASSNAME]))
				return 2;
			return 1;
		}
	}
	return 0;
}

static WEAPON_STYLE:GetWeaponStyleByLocation(const Float:vOrg[3])
{
	if (IsEntInStartSafeRoom(vOrg)){

		if (IsItemTranslationFeature()){
			return WEAPON_STYLE:REPLACE_NO_WEAPONS;
		}
		else {
			PushArrayCell(g_hDebugArray, 1);
			return WEAPON_STYLE:g_iCvarSSR_Style;
		}
	}
	else if (IsEntInEndSafeRoom(vOrg)){

		if (g_Public_bIsFinalMap){
			PushArrayCell(g_hDebugArray, 4);
			return WEAPON_STYLE:g_iCvarFSR_Style;
		}
		else {
			PushArrayCell(g_hDebugArray, 3);
			return WEAPON_STYLE:g_iCvarESR_Style;
		}
	}
	PushArrayCell(g_hDebugArray, 2);
	return WEAPON_STYLE:g_iCvarOSF_Style;
}

/**
 * Restores all tier 2 weapons from array.
 *
 * @noreturn
 */
static RestoreAllTier2()
{
	DebugPrintToAllEx("Restoring tier 2 weapons...");
	decl entity, String:classname[ARRAY_WEAPON_CELL_SIZE], String:model[ARRAY_WEAPON_CELL_SIZE], Float:origin[3], Float:rotation[3];

	new MaxTier2Weapons = GetArraySize(g_hWeaponsArray);
	for (new index = 0; index < MaxTier2Weapons; index += ARRAY_WEAPON_BLOCK)
	{
		GetArrayString(g_hWeaponsArray, index, classname, ARRAY_WEAPON_CELL_SIZE);
		GetArrayString(g_hWeaponsArray, index + 1, model, ARRAY_WEAPON_CELL_SIZE);
		GetArrayArray(g_hWeaponsArray, index + 2, origin, 3);
		GetArrayArray(g_hWeaponsArray, index + 3, rotation, 3);

		if (!(entity = CreateEntityByNameEx(classname, model, origin, rotation, DEFAULT_WEAPON_COUNT)))
		{
			ThrowError("Failed to restore tier 2 weapon! Classname \"%s\", model \"%s\", origin %f %f %f, rotation %f %f %f, count %i", classname, model, origin[0], origin[1], origin[2], rotation[0], rotation[1], rotation[2], DEFAULT_WEAPON_COUNT);
		}
		SetEntityRenderMode(entity, RENDER_NONE); // Hide the weapon
		DebugPrintToAllEx("Restored a tier 2 weapon; entity %i, classname \"%s\", model \"%s\", origin %f %f %f, rotation %f %f %f, count %i", entity, classname, model, origin[0], origin[1], origin[2], rotation[0], rotation[1], rotation[2], DEFAULT_WEAPON_COUNT);
	}
	DebugPrintToAllEx("Done restoring tier 2 weapons!");
}


public _WC_WeaponStyleOSF_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateOutSideStyleConVars();
}

public _WC_WeaponStyleSSR_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateStartStyleConVars();
}

public _WC_WeaponStyleESR_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateEndStyleConVars();
}

public _WC_WeaponStyleFSR_CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StrEqual(oldValue, newValue)) return;

	UpdateFinaleStyleConVars();
}

static UpdateOutSideStyleConVars()
{
	g_iCvarOSF_Style = GetConVarInt(g_hOSF_Style);
}

static UpdateStartStyleConVars()
{
	g_iCvarSSR_Style = GetConVarInt(g_hSSR_Style);
}

static UpdateEndStyleConVars()
{
	g_iCvarESR_Style = GetConVarInt(g_hESR_Style);
}

static UpdateFinaleStyleConVars()
{
	g_iCvarFSR_Style = GetConVarInt(g_hFSR_Style);
}

static Update_WC_ConVars()
{
	UpdateOutSideStyleConVars();
	UpdateStartStyleConVars();
	UpdateEndStyleConVars();
	UpdateFinaleStyleConVars();
}

stock _WC_CvarDump()
{
	//decl iVal;
	//if (WEAPON_STYLE:(iVal = GetConVarInt(g_hWeaponStyle_Cvar)) != g_iWeaponStyle)
	//	DebugLog("%d		|	%d		|	rotoblin_weapon_style", iVal, g_iWeaponStyle);
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