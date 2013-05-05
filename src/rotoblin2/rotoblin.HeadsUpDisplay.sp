 /*
 * ============================================================================
 *
 *  Original modified Rotoblin module
 *
 *  File:			rotoblin.HeadsUpDisplay.sp
 *  Type:			Module
 *  Description:	...
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

#define TIP	"Use !tankhud to toggle the tank HUD"

static	Handle:g_hTwoTanks, Handle:g_hTankHealth, Handle:g_hVsBonusHealth, bool:g_bCvarTwoTanks, Float:g_fTankHealth = 6000.0,
		bool:g_bShowTankHud[MAXPLAYERS+1], bool:g_bHudEnabled;

_HeadsUpDisplay_OnPluginStart()
{
	g_hTankHealth		= FindConVar("z_tank_health");
	g_hVsBonusHealth	= FindConVar("versus_tank_bonus_health");

	g_hTwoTanks	=	CreateConVarEx("two_tanks", "0");

	RegConsoleCmd("tankhud", HUD_CmdToogleTankHud);
}

public Action:HUD_CmdToogleTankHud(client, args)
{
	if (!client) return Plugin_Handled;

	g_bShowTankHud[client] = !g_bShowTankHud[client];
	PrintToChat(client, "%s Tank HUD is now %s.", MAIN_TAG, g_bShowTankHud[client] ? "enabled" : "disabled");

	return Plugin_Handled;
}

_HUD_OnPluginEnabled()
{
	HookEvent("round_start", HUD_ev_RoundStart, EventHookMode_PostNoCopy);

	HookConVarChange(g_hTwoTanks,			HUD_OnCvarChange_TwoTanks);
	HookConVarChange(g_hTankHealth,			HUD_OnCvarChange_TankHealth);
	HookConVarChange(g_hVsBonusHealth,		HUD_OnCvarChange_TankHealth);
	HUD_GetCvars();
}

_HUD_OnPluginDisable()
{
	UnhookEvent("round_start", HUD_ev_RoundStart, EventHookMode_PostNoCopy);

	UnhookConVarChange(g_hTwoTanks,			HUD_OnCvarChange_TwoTanks);
	UnhookConVarChange(g_hTankHealth,		HUD_OnCvarChange_TankHealth);
	UnhookConVarChange(g_hVsBonusHealth, 	HUD_OnCvarChange_TankHealth);
}

_HUD_OnClientPostAdminCheck(client)
{
	if (IsFakeClient(client)) return;

	if (g_bHudEnabled)
		PrintToChat(client, "%s %s", MAIN_TAG, TIP);
	//else
	//	PrintToChat(client, "%s Use !spechud to toggle the spectate HUD", MAIN_TAG);
}

public HUD_ev_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i; i <= MaxClients; i++)
		g_bShowTankHud[i] = false;
}

_HUD_ev_OnTankSpawn()
{
	if (!g_bHudEnabled){

		CreateTimer(1.0, HUD_t_Timer, _, TIMER_REPEAT);
		g_bHudEnabled = true;

		for (new i = 1; i < MaxClients; i++){

			g_bShowTankHud[i] = true;
			
			if (!IsClientInGame(i) || IsFakeClient(i)) continue;

			if (GetClientTeam(i) != 2)
				PrintToChat(i, "%s %s", MAIN_TAG, TIP);
		}
	}
}

public Action:HUD_t_Timer(Handle:timer)
{
	if (!HUD_DrawTankPanel()){

		g_bHudEnabled = false;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

static bool:HUD_DrawTankPanel()
{
	if (g_bBlackSpot || (IsNativeAvailable(IsGamePaused) && L4DReady_IsGamePaused())) return true;

	new bool:bTankInGame, iTanksIndex[2], iSurvTeamHealth;

	for (new i = 1; i <= MaxClients; i++){

		if (!IsClientInGame(i) || !IsPlayerAlive(i)) continue;

		switch (GetClientTeam(i)){

			case TEAM_SURVIVOR:{

				if (!IsIncapacitated(i) && !IsHandingFromLedge(i))
					iSurvTeamHealth += GetClientHealth(i) + RoundToFloor(GetSuvivorTempHealth(i));
			}
			case TEAM_INFECTED:{

				if (IsPlayerTank(i)){

					if (!bTankInGame)
						iTanksIndex[0] = i;
					else
						iTanksIndex[1] = i;
					bTankInGame = true;
				}
			}
		}
	}
	if (!bTankInGame) return false;

	static Handle:hHUD, Handle:hTankPersonalHud;

	hHUD = CreatePanel();
	hTankPersonalHud = CreatePanel();

	decl String:sBuffer[256];
	DrawPanelText(hHUD, "Rotoblin Tank Spec Hud\n\n-----------------------------");

	if (g_bCvarTwoTanks){

		DrawPanelText(hHUD, " Health :");
		if (IsIncapacitated(iTanksIndex[0]))
			FormatEx(sBuffer, 256, "     Dead (%N)", iTanksIndex[0]);
		else {
			if (IsFakeClient(iTanksIndex[0]))
				FormatEx(sBuffer, 256, "     %d (AI)", GetClientHealth(iTanksIndex[0]));
			else
				FormatEx(sBuffer, 256, "     %d (%N)", GetClientHealth(iTanksIndex[0]), iTanksIndex[0]);
		}
		DrawPanelText(hHUD, sBuffer);

		if (iTanksIndex[1] != 0){

			if (IsIncapacitated(iTanksIndex[1]))
				FormatEx(sBuffer, 256, "     Dead (%N)", iTanksIndex[1]);
			else {
				if (IsFakeClient(iTanksIndex[1]))
					FormatEx(sBuffer, 256, "     %d (AI)", GetClientHealth(iTanksIndex[1]));
				else
					FormatEx(sBuffer, 256, "     %d (%N)", GetClientHealth(iTanksIndex[1]), iTanksIndex[1]);
			}
			DrawPanelText(hHUD, sBuffer);
		}

		DrawPanelText(hHUD, " Frustration :");
		if (IsClientOnFire(iTanksIndex[0]))
			FormatEx(sBuffer, 256, "     On Fire (%N)", iTanksIndex[0]);
		else
			FormatEx(sBuffer, 256, "     %d%% (%N)", GetPrecentFrustration(iTanksIndex[0]), iTanksIndex[0]);
		DrawPanelText(hHUD, sBuffer);

		if (iTanksIndex[1] != 0){

			if (IsClientOnFire(iTanksIndex[1]))
				FormatEx(sBuffer, 256, "     On Fire (%N)", iTanksIndex[1]);
			else
				FormatEx(sBuffer, 256, "     %d%% (%N)", GetPrecentFrustration(iTanksIndex[1]), iTanksIndex[1]);
			DrawPanelText(hHUD, sBuffer);
		}
	}
	else {

		DrawPanelText(hHUD, " In Control :");

		if (IsFakeClient(iTanksIndex[0]))
			FormatEx(sBuffer, 256, "AI");
		else
			FormatEx(sBuffer, 256, "%N", iTanksIndex[0]);

		Format(sBuffer, 256, "     %s", sBuffer);
		DrawPanelText(hHUD, sBuffer);

		DrawPanelText(hHUD, " Health :");
		if (IsIncapacitated(iTanksIndex[0]))
			FormatEx(sBuffer, 256, "     Dead");
		else {
			new iHealth = GetClientHealth(iTanksIndex[0]);
			FormatEx(sBuffer, 256, "     %d (%d%%)", iHealth, RoundToFloor(FloatMul(FloatDiv(float(iHealth), g_fTankHealth), 100.0)));
		}
		DrawPanelText(hHUD, sBuffer);

		DrawPanelText(hHUD, " Frustration :");
		if (IsClientOnFire(iTanksIndex[0]))
			FormatEx(sBuffer, 256, "     On Fire");
		else
			FormatEx(sBuffer, 256, "     %d%%", GetPrecentFrustration(iTanksIndex[0]));
		DrawPanelText(hHUD, sBuffer);
	}

	FormatEx(sBuffer, 256, " \n\n Survivors Health : %d", iSurvTeamHealth);
	DrawPanelText(hHUD, sBuffer);

	// personal tank hud
	FormatEx(sBuffer, 256, " Survivors Health : %d", iSurvTeamHealth);
	DrawPanelText(hTankPersonalHud, sBuffer);

	for (new i; i < InfectedCount; i++){

		if (!g_bShowTankHud[InfectedIndex[i]] || InfectedIndex[i] <= 0  || !IsClientInGame(InfectedIndex[i]) || IsFakeClient(InfectedIndex[i])) continue; // If client is the tank or is a bot, continue

		if (InfectedIndex[i] == iTanksIndex[0] || InfectedIndex[i] == iTanksIndex[1])
			SendPanelToClient(hTankPersonalHud, InfectedIndex[i], HUD_HUD_Handler, 1);
		else
			SendPanelToClient(hHUD, InfectedIndex[i], HUD_HUD_Handler, 1);
	}

	for (new i; i < SpectateCount; i++){

		if (!g_bShowTankHud[SpectateIndex[i]] || SpectateIndex[i] <= 0  || !IsClientInGame(SpectateIndex[i]) || IsFakeClient(SpectateIndex[i])) continue; // If client is the tank or is a bot, continue

		SendPanelToClient(hHUD, SpectateIndex[i], HUD_HUD_Handler, 1);
	}

	CloseHandle(hHUD);
	CloseHandle(hTankPersonalHud);

	return true;
}

public HUD_HUD_Handler(Handle:menu, MenuAction:action, param1, param2)
{

}

public HUD_OnCvarChange_TwoTanks(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (!StrEqual(sOldVal, sNewVal))
		g_bCvarTwoTanks = GetConVarBool(g_hTwoTanks);
}

public HUD_OnCvarChange_TankHealth(Handle:hHandle, const String:sOldVal[], const String:sNewVal[])
{
	if (StrEqual(sOldVal, sNewVal)) return;

	g_fTankHealth = GetConVarFloat(g_hTankHealth) * GetConVarFloat(g_hVsBonusHealth);
}

static HUD_GetCvars()
{
	g_bCvarTwoTanks = GetConVarBool(g_hTwoTanks);
	g_fTankHealth = GetConVarFloat(g_hTankHealth) * GetConVarFloat(g_hVsBonusHealth);
}
