/*
 * ============================================================================
 *
 *  Rotoblin
 *
 *	File:			eventmanager.inc
 *	Type:			Helper
 *	Description:	Handles public events for all the modules.
 *
 *	Copyright (C) 2010  Mr. Zero <mrzerodk@gmail.com>
 *
 *	This program is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
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

// Don't let the script be included more than once.
#if defined _helper_eventmgr
  #endinput
#endif
#define _helper_eventmgr

// --------------------
//       Public
// --------------------

/*
 * Event types
 * This defines which events is availble for modules to hook.
 */
enum EVENT_TYPE
{
	EVENT_ONSURVIVORMOVES,
}

new				Handle:g_hEventForwards[_:EVENT_TYPE];

// **********************************************
//					  Forwards
// **********************************************

/**
 * Plugin is starting.
 *
 * @noreturn
 */
_H_EventManager_OnPluginStart()
{
	// Create private forwards.
	g_hEventForwards[0] = CreateForward(ET_Ignore, Param_Float, Param_Float); // args: Float:LowestFlow, Float:HighestFlow
}

// **********************************************
//                 Public API
// **********************************************

/**
 * Adds a function to the forward of selected event type.
 * 
 * @param type			The type of event to forward.
 * @param func			The function to add.
 * @return				True on success, false otherwise.
 */
stock bool:HookPublicEvent(const EVENT_TYPE:type, Function:func)
{
	new Handle:fwd = GetEventForward(type);
	if (fwd == INVALID_HANDLE) return false; // Invalid selection

	return AddToForward(fwd, INVALID_HANDLE, func);
}

/**
 * Removes a function from the forward of selected event type.
 * 
 * @param type			The type of event to forward.
 * @param func			The function to remove.
 * @return				True on success, false otherwise.
 */
stock bool:UnhookPublicEvent(const EVENT_TYPE:type, Function:func)
{
	new Handle:fwd = GetEventForward(type);
	if (fwd == INVALID_HANDLE) return false; // Invalid selection

	return RemoveFromForward(fwd, INVALID_HANDLE, func);
}

// **********************************************
//                 Private API
// **********************************************

/**
 * Gets the right forward with matching event.
 * 
 * @param type		    The type of event.
 * @return				Handle of the forward, otherwise invalid handle.
 */
static Handle:GetEventForward(const EVENT_TYPE:type)
{
	for (new i; i < _:EVENT_TYPE; i++)
	{
		if (EVENT_TYPE:i == type) return g_hEventForwards[i];
	}
	return INVALID_HANDLE;
}