/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  Copyright (C) 2012-2015 raziEiL <war4291@mail.ru>
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

#if defined _match_
  #endinput
#endif
#define _match_

enum strPatch
{
	CFGDIR,
	ROTODIR,
	DISABLE,
	SETTINGS,
	RATES,
	MAIN,
	MAP,
	PLUGINS,
	CVARS
};

new const String:sMatchCfg[strPatch][] =
{
	"cfg/",
	"cfgroto/",
	"cfgroto/rotoblin_off.cfg",
	"cfgroto/rotoblin_settings.cfg",
	"cfgroto/rotoblin_rates.cfg",
	"/rotoblin_main.cfg",
	"/rotoblin_map.cfg",
	"/rotoblin_plugins.cfg",
	"/rotoblin_cvars.cfg"
};

new 		String:sMatchName[48];

public Native_R2comp_GetMatchName(Handle:plugin, numParams)
{
	new iLen = GetNativeCell(2);

	decl String:sBuff[iLen];
	strcopy(sBuff, iLen, sMatchName);
	SetNativeString(1, sBuff, iLen);
}