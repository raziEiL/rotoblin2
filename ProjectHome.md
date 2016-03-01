# Rotoblin 2 a new competitive Left 4 Dead plugin/config #

Latest [l4downtown](https://bitbucket.org/disawar1/left4downtown/downloads) version, see also additional [plugins](https://bitbucket.org/disawar1/l4d-competitive-plugins/overview)

_**Have you found a bug? [report](https://code.google.com/p/rotoblin2/issues/entry)**_

### R2 CompMod 1.2.1 is Released (6-May-2013) ###

#### Changelog: ####

  * HotFix (7 May) Fixed some grammar errors.

  * Due to the fact that the `l4dscores` [Issue 5](https://code.google.com/p/rotoblin2/issues/detail?id=5) was the primary cause of the memory failure We decided to replace it with Anti-Scramble module.
  * The main futures of Anti-Scramble (can be configured rotoblin\_settings.cfg)
    * Unscramble the teams after a map change (or force changed by server administrator)
    * Unscramble the teams after a campaign change
    * Unscramble the teams after a match change
    * Spectators always stay spectators
    * Forbids players to change their teams until players loads.
    * Convars: `rotoblin_anti_scrable_notify` (enable/disable notification). `rotoblin_allow_anti_scrable` (enable/disable anti-scramble).
    * Commands: !keepteams (keep the current team's line-up).
  * Some of convars of R2 might work incorrectly after a server had become empty.
  * All configs were updated
  * `Rotoblin 2` match renamed `R2 CompMod`
  * Fixed missing throwable on finale maps.
  * Fixed the bug when witches did't spawn on some configs.
  * An access to some rotoblin functions is available now.
    * `rotoblin_despawn_infected`		// Despawn common infected who is too far behind the survivors.
    * `rotoblin_remove_start_commons`	// Removes all common infected near a saferoom and returns them when one of survivors leaves a saferoom.
  * Added `r2comp_api` include with useful natives and forwards for developers.
  * Added `r2compmod_test` plugin with the usage examples of `r2comp_api` include.
  * Added missing `l4d_lib` include file.

---


## About ##
> What is a Rotoblin 2? Rotoblin 2 or R2 CompMod is a fresh competitive mod based on the last Rotoblin version (Feb 2011). New plugin is to bring back a "new life" to the old game. The main point of the plugin is balancing the Left 4 Dead multiplayer gameplay.

## Plugin Requires ##
**MM 1.9, SM 1.4.6, SDKHooks 2.2.0 (It guarantees a full functionality of the mod. Earlier versions may work incorrectly. If you do not do this, the plugin will exhibit buggy behavior!) or later versions.**

## Roles, Contribution and Credits ##
  * **raziEiL:** _Programming, Level design, Mapping, Stripper._
  * **Alma:** _Idea to make a map modification, Mapping._
  * **Electr0:** _Providing a tool for mapping, Mapping._
  * **Scratchy** (RU: Царапка): _Localization, Plugins ideas, Testing._
  * **Credits:** Credit for the original plugin goes to Rotoblin Team. We're grateful to the Confogl Team for some usefull codes, ProMod for some 'map expolits blocked' and other [authors](https://code.google.com/p/rotoblin2/wiki/Plugins) for optional plugins.

## Сompetitive Configs/Short Description ##
Run match with _"!match", "!match pulse", "!forcematch"_, or similar commands.
Pause the game with _"!pause", "!unpause"_ commands.

  * **R2 CompMod** (ex. Rotoblin 2) - A default fresh rotoblin config. One molotov allowed, but tank burn duration is reduced. For mix games or middle skill/public players (RUP disabled)
  * **Pulse** - Is the Most hardcore and balanced match! SMG dmg inctesed to 15%, sniper/buckshot dmg reduced.
  * **Classic** - Many ofR2features disabled. The worst of configs because it is less balanced but classic one.
  * **Items** - Pills removed at start point. molotov/pipe-bomb/pills hidden on map. Tanks spawn always closer to the middle of map.
  * **Hunters** - Only hunters. Max ponuce dmg increseded. Bh allowed for infected. 1v1,2v2,3v3,4v4 confings inculded
  * **Deadman** - The one man against hunters, tanks and witches. It is not difficult to become a dead man...
also see ConfigsTable

## Main Features ##
Some properties depend on the convars and chosen configs being used.

  * Broken Rotoblin modules were fixed and unneeded ones were removed.
  * Stripper modification: many expolit/shortcuts of maps fixes.
  * Almost all expolits of Survivors/Infected were fixed.
  * Some L4D Engine bugs were fixed (like a bug when the ammo piles using doesn't provide a full ammo refill for weapons).
  * Autoloader/Plugin manager/Pause features.
  * R-2 doesn't unload, reload, block from being loaded your server plugins.
  * There's a command '!match' to call a vote for the match.
  * New way of water slowdown.
  * Special infected 'Ghost-warp'.
  * Finale spawn radius reduced.
  * All T2 weapons removed and replaced by T1 weapons.
  * Hunting rifles limited by convar.
  * There's more flexibility for converting medkids into pain pills.
  * All Items/Bosses spawn in the same places on both rounds.
  * All hordes (boomer and natural) are 25 common infected.
  * Now there is a Tank and Witch on Crash Course campaigns.
  * Tank has fire immunity for 5 seconds after spawn.
  * No tanks spawn after rescue vehicle approaching.
  * Tank punch-fix (allows the tank to punch survivors off an edge that otherwise would have incapacitated them on the spot).
  * Updated the tank HUD. New information added .
  * The Tank AI dies if there was forced stuck by infected team.
  * The hunter max pounce bonus damage has increased in "Hunters" configs.
  * Survivors can't hear jumps of infected ghosts.
  * Special infected are no longer slowed down by survivor gunfire.
  * Special infected cannot be killed by M2 (excluding boomer).
  * Bunny-hop tricks are blocked.
  * Shotgun/SMG ammo reduce.
  * Pills heal over time.
  * There're not any hunting rifles in saferooms.
  * Witch more aggressive.
  * v1.1
  * Option to kick player or block 'illegal' client settings.
  * A new spawning logic for item will be available.
  * Witch spawn mehtod on the round2 was improved.
  * There is a limit on the amount of witches on each map.
  * Set the limit on each kind of T1 weapons.
  * "Shove Penalties" variables were extended.
  * The double pistol can be forbidden.
  * Incapped Survivors aren't able to do harm to other Survirors
  * Some weapon attributes can be changed (dmg/dmg to Tank).
  * Fixed the bug when bots had disappeared after switch match from 1v1 to 4v4 etc.
  * Tank and Witch damage announcement added.
  * Added 1v1 statistics
  * Stripper: Some of the weapon spawn spots are changed.
  * The cooldown before choose team menu (M) can be used is removed. It isn't necessary to type commands such us "!inf", "!surv" etc.
  * The match mode automatically resets and map changes when server becomes empty.
  * The Common infected near the initial saferoom removes
  * Player's Lerp can be changed during ReadyUP active only.
and more...