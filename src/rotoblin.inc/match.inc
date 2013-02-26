/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
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

#if defined _match_
  #endinput
#endif
#define _match_

#define MATCH		8

enum _PATCH
{
	CFGDIR,
	ROTODIR,
	DISABLE,
	SETTINGS,
	RATES,
	MAIN,
	MAP,
	PLUGINS
};

new const String:sMatchCfg[_PATCH][] =
{
	"cfg/",
	"cfgroto/",
	"cfgroto/rotoblin_off.cfg",
	"cfgroto/rotoblin_settings.cfg",
	"cfgroto/rotoblin_rates.cfg",
	"/rotoblin.cfg",
	"/rotoblin_map.cfg",
	"/rotoblin_plugins.cfg"
};

new 		String:sMatchName[48];