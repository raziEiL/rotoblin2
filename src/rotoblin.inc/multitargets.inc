/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			multitargets.inc
 *  Type:			include
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
 
_H_MultiTargets_OnPluginStart()
{
	AddMultiTargetFilter("@spectators", MT_mtf_ProcessSpectators, "Spectators", false);
	AddMultiTargetFilter("@spec", MT_mtf_ProcessSpectators, "Spectators", false);
	AddMultiTargetFilter("@infected", MT_mtf_ProcessIndected, "Infected", false);
	AddMultiTargetFilter("@inf", MT_mtf_ProcessIndected, "Infected", false);
	AddMultiTargetFilter("@survivors", MT_mtf_ProcessSurvivors, "Survivors", false);
	AddMultiTargetFilter("@surv", MT_mtf_ProcessSurvivors, "Survivors", false);
}

public bool:MT_mtf_ProcessSpectators(const String:pattern[], Handle:clients)
{
	for (new i; i < SpectateCount; i++)
		PushArrayCell(clients, SpectateIndex[i]);

	return true;
}

public bool:MT_mtf_ProcessIndected(const String:pattern[], Handle:clients)
{
	for (new i; i < InfectedCount; i++)
		PushArrayCell(clients, InfectedIndex[i]);

	return true;
}

public bool:MT_mtf_ProcessSurvivors(const String:pattern[], Handle:clients)
{
	for (new i; i < SurvivorCount; i++)
		PushArrayCell(clients, SurvivorIndex[i]);

	return true;
}
