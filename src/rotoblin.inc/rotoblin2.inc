/*
 * ============================================================================
 *
 * This file is part of the Rotoblin 2 project.
 *
 *  File:			rotoblin2.inc
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

#if defined _rotoblin2_included
 #endinput
#endif
#define _rotoblin2_included

// Helpers
#include "rotoblin.inc/debug.inc"
#include "rotoblin.inc/cmdmanager.inc"
#include "rotoblin.inc/clientindexes.inc"
#include "rotoblin.inc/tankmanager.inc"
#include "rotoblin.inc/wrappers.inc"
#include "rotoblin.inc/multitargets.inc"
#include "rotoblin.inc/eventmanager.inc"

// Misc
#include "rotoblin.inc/global_forwards.inc"
#include "rotoblin.inc/weapon_attributes.inc"
#include "rotoblin.inc/engine_version.inc"
#include "rotoblin.inc/match.inc"

// Old fixed/updated modules
#include "rotoblin.despawninfected.sp"
#include "rotoblin.ghosttank.sp"
#include "rotoblin.healthcontrol.sp"
#include "rotoblin.infectedexploitfixes.sp"
#include "rotoblin.meleefatigue.sp"
#include "rotoblin.nopropfading.sp"
#include "rotoblin.pause.sp"
#include "rotoblin.reportstatus.sp"
#include "rotoblin.weaponcontrol.sp"
#include "rotoblin.limithuntingrifle.sp"
#include "rotoblin.finalespawn.sp"

// New modules
#include "rotoblin2/rotoblin.AutoLoader.sp"
#include "rotoblin2/rotoblin.Unscramble.sp"
#include "rotoblin2/rotoblin.MapInfo.sp"
#include "rotoblin2/rotoblin.TrackCvars.sp"
#include "rotoblin2/rotoblin.WaterSlowdown.sp"
#include "rotoblin2/rotoblin.NoEscapeTank.sp"
#include "rotoblin2/rotoblin.GhostWarp.sp"
#include "rotoblin2/rotoblin.ExpolitFixes.sp"
#include "rotoblin2/rotoblin.WitchesTracking.sp"
#include "rotoblin2/rotoblin.MobsControl.sp"
#include "rotoblin2/rotoblin.ItemControl.sp"
#include "rotoblin2/rotoblin.PluginManager.sp"
#include "rotoblin2/rotoblin.ReqMatch.sp"
#include "rotoblin2/rotoblin.DynamicHostname.sp"
#include "rotoblin2/rotoblin.HeadsUpDisplay.sp"
#include "rotoblin2/rotoblin.ClientSettings.sp"
#include "rotoblin2/rotoblin.TankSpawns.sp"
#include "rotoblin2/rotoblin.UnprohibitBosses.sp"
