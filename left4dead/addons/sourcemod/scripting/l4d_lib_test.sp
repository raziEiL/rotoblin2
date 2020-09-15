#define PLUGIN_VERSION "1.1"

#include <sourcemod>
#include <sdktools>
#include <sm_logger>
#undef REQUIRE_PLUGIN
#include <l4d_lib>

#define LOG_FLAGS	SML_CORE|SML_CLIENT
#define OUT_FLAGS	SML_SERVER|SML_CHAT|SML_CONSOLE
char LOG_TAGS[][] =	 {"CORE", "CLIENT"}; // <- adds new tag here

// Bitwise values definitions for logger
enum (<<= 1)
{
	SML_CORE = 1,
	SML_CLIENT
	// <- adds new bit here
}

public Plugin myinfo =
{
	name = "L4D_LIB TEST",
	author = "raziEiL [disawar1]",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/raziEiL"
}

public OnPluginStart()
{
	SMLoggerInit(SZF(LOG_TAGS), LOG_FLAGS, OUT_FLAGS); // setup logger
	RegAdminCmd("sm_l4d_lib_test", sm_l4d_lib_test, ADMFLAG_ROOT, "sm_l4d_lib_test [target]");
}

public Action sm_l4d_lib_test(int client, int args)
{
	int target;
	char sTemp[36];

	if (args){
		GetCmdArg(1, SZF(sTemp));
		target = StringToInt(sTemp);
		if (!IsValidEntity(target))
			target = 0;
	}
	target = target ? target : client;

	if (target){
		if (IsClient(target)){
			int team = GetClientTeam(target);
			SMLogClient(SML_CLIENT, client, "%d, #%d, %N", target, UID(target), target);
			SMLogClient(SML_CLIENT, client, "IsClient = %d", IsClient(target));
			SMLogClient(SML_CLIENT, client, "IsClientAndInGame = %d", IsClientAndInGame(target));
			SMLogClient(SML_CLIENT, client, "IsInfected = %d", IsInfected(target));
			SMLogClient(SML_CLIENT, client, "IsSurvivor = %d", IsSurvivor(target));
			SMLogClient(SML_CLIENT, client, "IsSpectator = %d", IsSpectator(target));
			SMLogClient(SML_CLIENT, client, "IsInfectedAndInGame = %d", IsInfectedAndInGame(target));
			SMLogClient(SML_CLIENT, client, "IsSurvivorAndInGame = %d", IsSurvivorAndInGame(target));
			SMLogClient(SML_CLIENT, client, "IsSpectatorAndInGame = %d", IsSpectatorAndInGame(target));
			SMLogClient(SML_CLIENT, client, "IsPlayerBussy = %d", IsPlayerBussy(target, team));
			SMLogClient(SML_CLIENT, client, "IsInfectedBussy = %d", IsInfectedBussy(target));
			SMLogClient(SML_CLIENT, client, "IsSurvivorBussy = %d", IsSurvivorBussy(target));
			SMLogClient(SML_CLIENT, client, "IsIncaped = %d", IsIncaped(target));
			SMLogClient(SML_CLIENT, client, "IsHandingFromLedge = %d", IsHandingFromLedge(target));
			SMLogClient(SML_CLIENT, client, "IsInfectedAlive = %d", IsInfectedAlive(target));
			SMLogClient(SML_CLIENT, client, "IsPlayerAlive = %d", IsPlayerAlive(target));
			SMLogClient(SML_CLIENT, client, "IsPlayerGhost = %d", IsPlayerGhost(target));
			SMLogClient(SML_CLIENT, client, "IsPlayerTank = %d", IsPlayerTank(target));
			SMLogClient(SML_CLIENT, client, "GetPlayerClass = %d", GetPlayerClass(target));
			SMLogClient(SML_CLIENT, client, "GetZombieClass = %d", GetZombieClass(target));
			SMLogClient(SML_CLIENT, client, "GetFrustration = %d", GetFrustration(target));
			SMLogClient(SML_CLIENT, client, "GetGhostSpawnState = %d", GetGhostSpawnState(target));
			SMLogClient(SML_CLIENT, client, "GetTempHealth = %f", GetTempHealth(target));
			SMLogClient(SML_CLIENT, client, "IsOnFire = %d", IsOnFire(target));
			SMLogClient(SML_CLIENT, client, "IsOnLadder = %d", IsOnLadder(target));
			if (team == 2){
				SMLogClient(SML_CLIENT, client, "GetSurvivorIndex = %d", GetSurvivorIndex(target));

				sTemp[0] = 0;
				GetCharacterName(target, SZF(sTemp));
				SMLogClient(SML_CLIENT, client, "GetCharacterName = %s", sTemp);

				sTemp[0] = 0;
				GetCharacter(target, SZF(sTemp));
				SMLogClient(SML_CLIENT, client, "GetCharacter = %s", sTemp);
			}
			else if (team == 3){
				sTemp[0] = 0;
				GetInfectedName(target, SZF(sTemp));
				SMLogClient(SML_CLIENT, client, "GetInfectedName = %s", sTemp);
			}
		}
		else {
			GetEntityClassname(target, SZF(sTemp));
			SMLogClient(SML_CLIENT, client, "%d, %s", target, sTemp);
			SMLogClient(SML_CLIENT, client, "GetZombieClass = %d", GetZombieClass(target));

			sTemp[0] = 0;
			GetZombieName(target, SZF(sTemp));
			SMLogClient(SML_CLIENT, client, "GetZombieName = %s", sTemp);
		}
	}
	SMLogTag(SML_CORE, "IsAnyOneConnected = %d", IsAnyOneConnected());
	SMLogTag(SML_CORE, "IsServerEmpty = %d", IsServerEmpty());
	SMLogTag(SML_CORE, "IsFinalMap = %d", IsFinalMap());
	SMLogTag(SML_CORE, "IsNewMission = %d", IsNewMission());
	SMLogTag(SML_CORE, "IsL4DEngine = %d", IsL4DEngine());
	SMLogTag(SML_CORE, "IsL4D2Engine = %d", IsL4DEngine(true));
	return Plugin_Handled;
}