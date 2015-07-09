/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			global_forwards.inc
 *  Type:			include
 *  Description:	SDK Tools/L4DDownTown forwards.
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

#if defined _global_forwards_
  #endinput
#endif
#define _global_forwards_

// **********************************************
//                 Forwards
// **********************************************
public Action:OnPlayerRunCmd(client, &buttons)
{
	if (!IsPluginEnabled()) return Plugin_Continue;

	//if (_IEF_OnPlayerRunCmd(client, buttons))
	//	buttons ^= IN_ATTACK2;

	if (_GT_OnPlayerRunCmdTwo(client, buttons))
		buttons &= ~IN_USE;

	if (_GW_OnPlayerRunCmd(client, buttons))
		return Plugin_Handled;

	return Plugin_Continue;
}

// l4d downtown forward
public Action:L4D_OnSpawnTank(const Float:vector[3], const Float:qangle[3])
{
	if (!IsPluginEnabled()) return Plugin_Continue;

	if (_NET_L4D_OnSpawnTank())
		return Plugin_Handled;

	if (_TS_L4D_OnSpawnTank(vector, qangle))
		return Plugin_Handled;

	_MC_L4D_OnSpawnTank();
	_GT_L4D_OnSpawnTank();

	return Plugin_Continue;
}