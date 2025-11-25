#include <sourcemod>
#include <convar_class>
#include <sdktools>
#include <shavit>
#include <shavit/replay-file>
#include <shavit/replay-stocks.sp>

#undef REQUIRE_PLUGIN
#include <eventqueuefix>

#pragma newdecls required
#pragma semicolon 1

cp_cache_t g_aSavestates[MAXPLAYERS+1];
frame_cache_t g_aReplayCache[MAXPLAYERS+1];
chatstrings_t g_sChatStrings;
stylestrings_t g_sStyleStrings[STYLE_LIMIT];

bool g_bLate = false;
Handle g_hSavesDB = INVALID_HANDLE;
float g_fTickrate = 0.0;
int g_iStyleCount;
char g_sReplayFolder[PLATFORM_MAX_PATH];
char g_sCurrentMap[128];

bool g_bHasAnySaves[MAXPLAYERS+1];
bool g_bHasCurrentMapSaves[MAXPLAYERS+1];
bool g_bHasSave[MAXPLAYERS+1][STYLE_LIMIT];
float g_fSaveTime[MAXPLAYERS+1][STYLE_LIMIT];
int g_iSaveDate[MAXPLAYERS+1][STYLE_LIMIT];
bool g_bNotified[MAXPLAYERS+1];

ConVar g_cvSaveReplayOverWR = null;

public Plugin myinfo =
{
	name = "[shavit] Savestate",
	author = "olivia",
	description = "Allow saving and loading savestates in shavit's bhoptimer",
	version = "c:",
	url = "https://KawaiiClan.com"
}

public void OnPluginStart()
{
	InitSavesDB(g_hSavesDB);
	g_fTickrate = (1.0 / GetTickInterval());

	RegConsoleCmd("sm_savestate", Command_Savestate, "Save or load a timer state");
	RegConsoleCmd("sm_savestates", Command_Savestate, "Save or load a timer state");
	RegConsoleCmd("sm_savegame", Command_Savestate, "Save or load a timer state");
	RegConsoleCmd("sm_savetimer", Command_Savestate, "Save or load a timer state");
	RegConsoleCmd("sm_load", Command_Savestate, "Save or load a timer state");
	RegConsoleCmd("sm_loadgame", Command_Savestate, "Save or load a timer state");
	RegConsoleCmd("sm_loadtimer", Command_Savestate, "Save or load a timer state");
	
	g_cvSaveReplayOverWR = new Convar("shavit_savestate_savereplayoverwr", "0", "Whether or not to save replay frames if player's time is longer than the WR", 0, true, 0.0, true, 1.0);
	Convar.AutoExecConfig();

	if(g_bLate)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
				OnClientPutInServer(i);
		}

		Shavit_OnChatConfigLoaded();
		Shavit_OnStyleConfigLoaded(-1);
		GetLowercaseMapName(g_sCurrentMap);
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStringsStruct(g_sChatStrings);
}

public void Shavit_OnStyleConfigLoaded(int styles)
{
	if(styles == -1)
		styles = Shavit_GetStyleCount();

	for(int i = 0; i < styles; i++)
		Shavit_GetStyleStrings(i, sStyleName, g_sStyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));

	g_iStyleCount = styles;

	if(!Shavit_GetReplayFolderPath_Stock(g_sReplayFolder))
		SetFailState("Could not load the replay bots' configuration file. Make sure it exists (addons/sourcemod/configs/shavit-replay.cfg) and follows the proper syntax!");

	char sSavedGamesPath[PLATFORM_MAX_PATH];
	FormatEx(sSavedGamesPath, sizeof(sSavedGamesPath), "%s/savedgames", g_sReplayFolder);
	if(!DirExists(sSavedGamesPath) && !CreateDirectory(sSavedGamesPath, 511))
		SetFailState("Failed to create replay folder (%s). Make sure you have file permissions", sSavedGamesPath);
}

public void OnMapStart()
{
	GetLowercaseMapName(g_sCurrentMap);
}

public void OnClientPutInServer(int client)
{
	GetClientSaves(client);
}

public Action InitSavesDB(Handle &DbHNDL)
{
	char sError[255];
	DbHNDL = SQL_Connect("savegame", true, sError, sizeof(sError));
	if(DbHNDL == INVALID_HANDLE)
		SetFailState(sError);

	else
	{
		char sQuery[4096];
		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `saves` (`map` varchar(100) NOT NULL, `auth` int NOT NULL, `style` int NOT NULL, `date` int NOT NULL, `TbTimerEnabled` int NOT NULL, `TfCurrentTime` float NOT NULL, `TbClientPaused` int NOT NULL, `TiJumps` int NOT NULL, `TiStrafes` int NOT NULL, `TiTotalMeasures` int, `TiGoodGains` int, `TfServerTime` int NOT NULL, `TiKeyCombo` int NOT NULL, `TiTimerTrack` int NOT NULL, `TiMeasuredJumps` int, `TiPerfectJumps` int, `TfZoneOffset1` float, `TfZoneOffset2` float, `TfDistanceOffset1` float, `TfDistanceOffset2` float, `TfAvgVelocity` float, `TfMaxVelocity` float, `TfTimescale` float NOT NULL, `TiZoneIncrement` int, `TiFullTicks` int NOT NULL, `TiFractionalTicks` int NOT NULL, `TbPracticeMode` int NOT NULL, `TbJumped` int NOT NULL, `TbCanUseAllKeys` int NOT NULL, `TbOnGround` int NOT NULL, `TiLastButtons` int, `TfLastAngle` float, `TiLandingTick` int, `TiLastMoveType` int, `TfStrafeWarning` float, `TfLastInputVel1` float, `TfLastInputVel2` float, `Tfplayer_speedmod` float, `TfNextFrameTime` float, `TiLastMoveTypeTAS` int, `CfPosition1` float NOT NULL, `CfPosition2` float NOT NULL, `CfPosition3` float NOT NULL, `CfAngles1` float NOT NULL, `CfAngles2` float NOT NULL, `CfAngles3` float NOT NULL, `CfVelocity1` float NOT NULL, `CfVelocity2` float NOT NULL, `CfVelocity3` float NOT NULL, `CiMovetype` int NOT NULL, `CfGravity` float NOT NULL, `CfSpeed` float NOT NULL, `CfStamina` float NOT NULL, `CbDucked` int NOT NULL, `CbDucking` int NOT NULL, `CfDuckTime` float, `CfDuckSpeed` float, `CiFlags` int NOT NULL, `CsTargetname` varchar(64) NOT NULL, `CsClassname` varchar(64) NOT NULL, `CiPreFrames` int NOT NULL, `CbSegmented` int NOT NULL, `CiGroundEntity` int, `CvecLadderNormal1` float, `CvecLadderNormal2` float, `CvecLadderNormal3` float, `Cm_bHasWalkMovedSinceLastJump` int, `Cm_ignoreLadderJumpTime` float, `Cm_lastStandingPos1` float, `Cm_lastStandingPos2` float, `Cm_lastStandingPos3` float, `Cm_ladderSuppressionTimer1` float, `Cm_ladderSuppressionTimer2` float, `Cm_lastLadderNormal1` float, `Cm_lastLadderNormal2` float, `Cm_lastLadderNormal3` float, `Cm_lastLadderPos1` float, `Cm_lastLadderPos2` float, `Cm_lastLadderPos3` float, `Cm_afButtonDisabled` int, `Cm_afButtonForced` int, UNIQUE KEY `unique_index` (`map`,`auth`,`style`)) ENGINE=INNODB;");
		SQL_TQuery(g_hSavesDB, SQL_InitSavesDB, sQuery);
		
		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `saves-events` (`type` varchar(16) NOT NULL, `id` int NOT NULL, `map` varchar(100) NOT NULL, `auth` int NOT NULL, `style` int NOT NULL, `Etarget` varchar(512), `EtargetInput` varchar(512), `EvariantValue` varchar(512), `Edelay` float, `Eactivator` int, `Ecaller` int, `EoutputID` int, `EwaitTime` float, UNIQUE KEY `unique_index` (`type`, `id`, `map`, `auth`,`style`)) ENGINE=INNODB;");
		SQL_TQuery(g_hSavesDB, SQL_InitSavesDB, sQuery);
		
		FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `saves-customdata` (`id` int NOT NULL, `map` varchar(100) NOT NULL, `auth` int NOT NULL, `style` int NOT NULL, `key` varchar(64) NOT NULL, `value` varchar(64) NOT NULL, UNIQUE KEY `unique_index` (`id`, `map`,`auth`,`style`)) ENGINE=INNODB;");
		SQL_TQuery(g_hSavesDB, SQL_InitSavesDB, sQuery);
	}

	return Plugin_Handled;
}

public void SQL_InitSavesDB(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
		SetFailState("Database initialization query failed! %s", error);
}

public void SQL_GeneralCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
		LogError("Query failed! %s", error);
}

void GetClientSaves(int client)
{
	char sQuery[255];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `map`, `style`, `TfCurrentTime`, `date` FROM `saves` WHERE auth = %i;", GetSteamAccountID(client), g_sCurrentMap);
	SQL_TQuery(g_hSavesDB, SQL_GetClientSaves, sQuery, client);
}

public void SQL_GetClientSaves(Handle owner, Handle hndl, const char[] error, int client)
{
	g_bHasAnySaves[client] = false;
	g_bHasCurrentMapSaves[client] = false;
	g_bNotified[client] = false;
	for(int i = 0; i <= g_iStyleCount; i++)
	{
		g_bHasSave[client][i] = false;
		g_fSaveTime[client][i] = 0.0;
	}

	if(SQL_GetRowCount(hndl) != 0)
	{
		g_bHasAnySaves[client] = true;

		char sMap[255];
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sMap, sizeof(sMap));
			int iStyle = SQL_FetchInt(hndl, 1);

			if(StrEqual(sMap, g_sCurrentMap))
			{
				g_bHasCurrentMapSaves[client] = true;
				g_bHasSave[client][iStyle] = true;
				g_fSaveTime[client][iStyle] = SQL_FetchFloat(hndl, 2);
				g_iSaveDate[client][iStyle] = SQL_FetchInt(hndl, 3);
			}
		}
	}
}

public void Shavit_OnRestart(int client, int track)
{
	if(g_bHasCurrentMapSaves[client] && !g_bNotified[client])
	{
		Shavit_PrintToChat(client, "You have a saved game on this map! Load it with %s!savestate", g_sChatStrings.sVariable);
		g_bNotified[client] = true;
	}
}

public Action Command_Savestate(int client, int args)
{
	if(client != 0)
		OpenSavestateMenu(client);
	return Plugin_Handled;
}

void OpenSavestateMenu(int client)
{
	Menu menu = new Menu(OpenSavestateMenuHandler);
	menu.SetTitle("Savestates Menu\n ");

	menu.AddItem("save", "Save Current Timer", Shavit_GetTimerStatus(client) == Timer_Stopped ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("load", "Load Timer Save\n ", g_bHasCurrentMapSaves[client] ? ITEMDRAW_DEFAULT: ITEMDRAW_DISABLED);
	menu.AddItem("view", "View All Saves", g_bHasAnySaves[client] ? ITEMDRAW_DEFAULT: ITEMDRAW_DISABLED);

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenSavestateMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char s[8];
		menu.GetItem(param2, s, sizeof(s));

		if(StrEqual(s, "save"))
		{
			if(Shavit_GetClientTrack(param1) != 0)
			{
				Shavit_PrintToChat(param1, "Did %sNOT %ssave your game. This feature is for the %smain %strack only", g_sChatStrings.sWarning, g_sChatStrings.sText, g_sChatStrings.sVariable, g_sChatStrings.sText);
				OpenSavestateMenu(param1);
			}
			else if(!Shavit_CanPause(param1) || Shavit_IsPaused(param1))
			{
				int iStyle = Shavit_GetBhopStyle(param1);

				if(g_bHasSave[param1][iStyle])
					OpenOverwriteSaveMenu(param1, iStyle);

				else
					SaveGame(param1, iStyle);
			}
			else
			{
				Shavit_PrintToChat(param1, "Did %sNOT %ssave your game. Your timer must be %spaused%s, or pause conditions must be met! (alive, not moving, uncrouched, etc.)", g_sChatStrings.sWarning, g_sChatStrings.sText, g_sChatStrings.sVariable, g_sChatStrings.sText);
				OpenSavestateMenu(param1);
			}
		}
		else if(StrEqual(s, "load"))
		{
			OpenLoadGameMenu(param1);
		}
		else if(StrEqual(s, "view"))
		{
			OpenViewSavesMenu(param1);
		}
		else
		{
			Shavit_PrintToChat(param1, "Invalid selection, please try again");
			OpenSavestateMenu(param1);
		}
	}
	return Plugin_Handled;
}

public void SaveGame(int client, int style)
{
	if(style != Shavit_GetBhopStyle(client) || Shavit_GetClientTrack(client) != 0)
		return;

	if(Shavit_GetTimerStatus(client) == Timer_Paused)
		Shavit_ResumeTimer(client, true);

	Shavit_SaveCheckpointCache(client, client, g_aSavestates[client], -1, sizeof(g_aSavestates[client]));
	g_aSavestates[client].iPreFrames = Shavit_GetPlayerPreFrames(client); //this is needed until https://github.com/shavitush/bhoptimer/pull/1244 is addressed, but might only be used if we save a replay, idk. i'll leave it here to be safe
	float fZoneOffset[2];
	fZoneOffset[0] = g_aSavestates[client].aSnapshot.fZoneOffset[0];
	fZoneOffset[1] = g_aSavestates[client].aSnapshot.fZoneOffset[1];

	//if there are eventqueuefix events
	if(g_aSavestates[client].aEvents != null && g_aSavestates[client].aOutputWaits != null)
	{
		//clear db
		char sQuery[2048];
		FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `saves-events` WHERE `map` = '%s' AND `auth` = %i AND `style` = %i;", g_sCurrentMap, GetSteamAccountID(client), style);
		SQL_TQuery(g_hSavesDB, SQL_GeneralCallback, sQuery);

		//events
		for(int i = 0; i < g_aSavestates[client].aEvents.Length; i++)
		{
			event_t e;
			g_aSavestates[client].aEvents.GetArray(i, e);
			FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `saves-events` (`type`, `id`, `map`, `auth`, `style`, `Etarget`, `EtargetInput`, `EvariantValue`, `Edelay`, `Eactivator`, `Ecaller`, `EoutputID`) VALUES ('event', '%i', '%s', '%i', '%i', '%s', '%s', '%s', '%f', '%i', '%i', '%i');", i, g_sCurrentMap, GetSteamAccountID(client), style, e.target, e.targetInput, e.variantValue, e.delay, e.activator, e.caller, e.outputID);
			SQL_TQuery(g_hSavesDB, SQL_GeneralCallback, sQuery);
		}

		//outputwaits
		for(int i = 0; i < g_aSavestates[client].aOutputWaits.Length; i++)
		{
			entity_t e;
			g_aSavestates[client].aOutputWaits.GetArray(i, e);
			FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `saves-events` (`type`, `id`, `map`, `auth`, `style`, `Ecaller`, `EwaitTime`) VALUES ('output', '%i', '%s', '%i', '%i', '%i', '%f');", i, g_sCurrentMap, GetSteamAccountID(client), style, e.caller, e.waitTime);
			SQL_TQuery(g_hSavesDB, SQL_GeneralCallback, sQuery);
		}
	}
	
	//customdata (mpbhops)
	if(g_aSavestates[client].customdata != null)
	{
		//clear db
		char sQuery[1024];
		FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `saves-customdata` WHERE `map` = '%s' AND `auth` = %i AND `style` = %i;", g_sCurrentMap, GetSteamAccountID(client), style);
		SQL_TQuery(g_hSavesDB, SQL_GeneralCallback, sQuery);

		float fPunishTime;
		int iLastBlock;
		if(g_aSavestates[client].customdata.ContainsKey("mpbhops_punishtime"))
			g_aSavestates[client].customdata.GetValue("mpbhops_punishtime", fPunishTime);
		if(g_aSavestates[client].customdata.ContainsKey("mpbhops_lastblock"))
			g_aSavestates[client].customdata.GetValue("mpbhops_lastblock", iLastBlock);

		char sPunishTime[64];
		char sLastBlock[64];
		FloatToString(fPunishTime, sPunishTime, sizeof(sPunishTime));
		IntToString(iLastBlock, sLastBlock, sizeof(sLastBlock));

		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `saves-customdata` (`id`, `map`, `auth`, `style`, `key`, `value`) VALUES ('0', '%s', '%i', '%i', 'mpbhops_punishtime', '%s'), ('1', '%s', '%i', '%i', 'mpbhops_lastblock', '%s');", g_sCurrentMap, GetSteamAccountID(client), style, sPunishTime, g_sCurrentMap, GetSteamAccountID(client), style, sLastBlock);
		SQL_TQuery(g_hSavesDB, SQL_GeneralCallback, sQuery);
	}

	//if time is under wr, save replay frames to file
	if(g_cvSaveReplayOverWR.BoolValue || Shavit_GetWorldRecord(style, 0) == 0.0 || g_aSavestates[client].aSnapshot.fCurrentTime < Shavit_GetWorldRecord(style, 0))
	{
		char sPath[PLATFORM_MAX_PATH];
		FormatEx(sPath, sizeof(sPath), "%s/savedgames/%s_%i_%i.replay", g_sReplayFolder, g_sCurrentMap, style, GetSteamAccountID(client));

		File fFile = null;
		if(!(fFile = OpenFile(sPath, "wb+")))
		{
			LogError("Failed to open savegame replay file for writing. Permissions issue? ('%s')", sPath);
			Shavit_PrintToChat(client, "Did %sNOT%s save your game due to file permissions error, tell an admin to check the logs!", g_sChatStrings.sWarning, g_sChatStrings.sText);
			return;
		}

		ArrayList ReplayFrames = Shavit_GetReplayData(client);
		int iSize = Shavit_GetClientFrameCount(client);

		WriteReplayHeader(fFile, style, 0, g_aSavestates[client].aSnapshot.fCurrentTime, GetSteamAccountID(client), g_aSavestates[client].iPreFrames, 0, fZoneOffset, iSize, g_fTickrate, g_sCurrentMap);
		WriteReplayFrames(ReplayFrames, iSize, fFile, null);
		delete fFile;
		delete ReplayFrames;
	}
	
	char sQuery[8192];
	FormatEx(sQuery, sizeof(sQuery), "REPLACE INTO `saves` (`map`, `auth`, `style`, `date`, `TbTimerEnabled`, `TfCurrentTime`, `TbClientPaused`, `TiJumps`, `TiStrafes`, `TiTotalMeasures`, `TiGoodGains`, `TfServerTime`, `TiKeyCombo`, `TiTimerTrack`, `TiMeasuredJumps`, `TiPerfectJumps`, `TfZoneOffset1`, `TfZoneOffset2`, `TfDistanceOffset1`, `TfDistanceOffset2`, `TfAvgVelocity`, `TfMaxVelocity`, `TfTimescale`, `TiZoneIncrement`, `TiFullTicks`, `TiFractionalTicks`, `TbPracticeMode`, `TbJumped`, `TbCanUseAllKeys`, `TbOnGround`, `TiLastButtons`, `TfLastAngle`, `TiLandingTick`, `TiLastMoveType`, `TfStrafeWarning`, `TfLastInputVel1`, `TfLastInputVel2`, `Tfplayer_speedmod`, `TfNextFrameTime`, `TiLastMoveTypeTAS`, `CfPosition1`, `CfPosition2`, `CfPosition3`, `CfAngles1`, `CfAngles2`, `CfAngles3`, `CfVelocity1`, `CfVelocity2`, `CfVelocity3`, `CiMovetype`, `CfGravity`, `CfSpeed`, `CfStamina`, `CbDucked`, `CbDucking`, `CfDuckTime`, `CfDuckSpeed`, `CiFlags`, `CsTargetname`, `CsClassname`, `CiPreFrames`, `CbSegmented`, `CiGroundEntity`, `CvecLadderNormal1`, `CvecLadderNormal2`, `CvecLadderNormal3`, `Cm_bHasWalkMovedSinceLastJump`, `Cm_ignoreLadderJumpTime`, `Cm_lastStandingPos1`, `Cm_lastStandingPos2`, `Cm_lastStandingPos3`, `Cm_ladderSuppressionTimer1`, `Cm_ladderSuppressionTimer2`,  `Cm_lastLadderNormal1`, `Cm_lastLadderNormal2`, `Cm_lastLadderNormal3`, `Cm_lastLadderPos1`, `Cm_lastLadderPos2`, `Cm_lastLadderPos3`, `Cm_afButtonDisabled`, `Cm_afButtonForced`) VALUES ('%s', '%i', '%i', '%i', '%i', '%f', '%i', '%i', '%i', '%i', '%i', '%f', '%i', '%i', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%f', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%f', '%f', '%f', '%i', '%i', '%f', '%f', '%i', '%s', '%s', '%i', '%i', '%i', '%f', '%f', '%f', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i');",
		g_sCurrentMap, GetSteamAccountID(client), g_aSavestates[client].aSnapshot.bsStyle, GetTime(), view_as<int>(g_aSavestates[client].aSnapshot.bTimerEnabled), g_aSavestates[client].aSnapshot.fCurrentTime, view_as<int>(g_aSavestates[client].aSnapshot.bClientPaused), g_aSavestates[client].aSnapshot.iJumps,
		g_aSavestates[client].aSnapshot.iStrafes, g_aSavestates[client].aSnapshot.iTotalMeasures, g_aSavestates[client].aSnapshot.iGoodGains, g_aSavestates[client].aSnapshot.fServerTime, g_aSavestates[client].aSnapshot.iKeyCombo, g_aSavestates[client].aSnapshot.iTimerTrack, 
		g_aSavestates[client].aSnapshot.iMeasuredJumps, g_aSavestates[client].aSnapshot.iPerfectJumps, g_aSavestates[client].aSnapshot.fZoneOffset[0], g_aSavestates[client].aSnapshot.fZoneOffset[1], 
		g_aSavestates[client].aSnapshot.fDistanceOffset[0], g_aSavestates[client].aSnapshot.fDistanceOffset[1], g_aSavestates[client].aSnapshot.fAvgVelocity, 
		g_aSavestates[client].aSnapshot.fMaxVelocity, g_aSavestates[client].aSnapshot.fTimescale, g_aSavestates[client].aSnapshot.iZoneIncrement, g_aSavestates[client].aSnapshot.iFullTicks, g_aSavestates[client].aSnapshot.iFractionalTicks, view_as<int>(g_aSavestates[client].aSnapshot.bPracticeMode), 
		view_as<int>(g_aSavestates[client].aSnapshot.bJumped), view_as<int>(g_aSavestates[client].aSnapshot.bCanUseAllKeys), view_as<int>(g_aSavestates[client].aSnapshot.bOnGround), g_aSavestates[client].aSnapshot.iLastButtons, g_aSavestates[client].aSnapshot.fLastAngle, 
		g_aSavestates[client].aSnapshot.iLandingTick, g_aSavestates[client].aSnapshot.iLastMoveType, g_aSavestates[client].aSnapshot.fStrafeWarning, 
		g_aSavestates[client].aSnapshot.fLastInputVel[0], g_aSavestates[client].aSnapshot.fLastInputVel[1],  g_aSavestates[client].aSnapshot.fplayer_speedmod, 
		g_aSavestates[client].aSnapshot.fNextFrameTime, g_aSavestates[client].aSnapshot.iLastMoveTypeTAS, 
		
		g_aSavestates[client].fPosition[0], g_aSavestates[client].fPosition[1], g_aSavestates[client].fPosition[2], 
		g_aSavestates[client].fAngles[0], g_aSavestates[client].fAngles[1], g_aSavestates[client].fAngles[2], 
		g_aSavestates[client].fVelocity[0], g_aSavestates[client].fVelocity[1], g_aSavestates[client].fVelocity[2], 
		g_aSavestates[client].iMoveType, g_aSavestates[client].fGravity, g_aSavestates[client].fSpeed, g_aSavestates[client].fStamina, 
		view_as<int>(g_aSavestates[client].bDucked), view_as<int>(g_aSavestates[client].bDucking), g_aSavestates[client].fDucktime, g_aSavestates[client].fDuckSpeed, 
		g_aSavestates[client].iFlags, g_aSavestates[client].sTargetname, g_aSavestates[client].sClassname, 
		g_aSavestates[client].iPreFrames, view_as<int>(g_aSavestates[client].bSegmented), g_aSavestates[client].iGroundEntity, 
		g_aSavestates[client].vecLadderNormal[0], g_aSavestates[client].vecLadderNormal[1], g_aSavestates[client].vecLadderNormal[2], 
		view_as<int>(g_aSavestates[client].m_bHasWalkMovedSinceLastJump), g_aSavestates[client].m_ignoreLadderJumpTime, 
		g_aSavestates[client].m_lastStandingPos[0], g_aSavestates[client].m_lastStandingPos[1], g_aSavestates[client].m_lastStandingPos[2], 
		g_aSavestates[client].m_ladderSurpressionTimer[0], g_aSavestates[client].m_ladderSurpressionTimer[1], 
		g_aSavestates[client].m_lastLadderNormal[0], g_aSavestates[client].m_lastLadderNormal[1], g_aSavestates[client].m_lastLadderNormal[2], 
		g_aSavestates[client].m_lastLadderPos[0], g_aSavestates[client].m_lastLadderPos[1], g_aSavestates[client].m_lastLadderPos[2], 
		g_aSavestates[client].m_afButtonDisabled, g_aSavestates[client].m_afButtonForced);
	SQL_TQuery(g_hSavesDB, SQL_SaveGame, sQuery, client);
}

public void SQL_SaveGame(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		char sPath[PLATFORM_MAX_PATH];
		FormatEx(sPath, sizeof(sPath), "%s/savedgames/%s_%i_%i.replay", g_sReplayFolder, g_sCurrentMap, Shavit_GetBhopStyle(client), GetSteamAccountID(client));
		if(FileExists(sPath))
			DeleteFile(sPath);

		LogError("SQL_SaveGame() query failed! %s", error);
		Shavit_PrintToChat(client, "Did %sNOT %ssave your game. Database error, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
	}
	else
	{
		Shavit_StopTimer(client, true);
		GetClientSaves(client);
		Shavit_PrintToChat(client, "Timer saved! Load your save on this map later with %s!savestate", g_sChatStrings.sVariable);
	}
}

public Action OpenOverwriteSaveMenu(int client, int style)
{
	Panel hPanel = CreatePanel();
	char sDisplay[128];
	char sTime[32];
	FloatToString(g_fSaveTime[client][style], sTime, sizeof(sTime));

	FormatEx(sDisplay, sizeof(sDisplay), "You already have a saved game on %s", g_sCurrentMap);
	hPanel.SetTitle(sDisplay);

	FormatEx(sDisplay, sizeof(sDisplay), "Style: %s", g_sStyleStrings[style].sStyleName);
	hPanel.DrawItem(sDisplay, ITEMDRAW_RAWLINE);

	FormatEx(sDisplay, sizeof(sDisplay), "Time: %s", FormatToSeconds(sTime));
	hPanel.DrawItem(sDisplay, ITEMDRAW_RAWLINE);

	hPanel.DrawItem(" ", ITEMDRAW_RAWLINE);
	hPanel.DrawItem("Overwrite?", ITEMDRAW_RAWLINE);
	hPanel.DrawItem("Yes", ITEMDRAW_CONTROL);
	hPanel.DrawItem("No", ITEMDRAW_CONTROL);
	hPanel.DrawItem(" ", ITEMDRAW_RAWLINE);

	SetPanelCurrentKey(hPanel, 10);
	hPanel.DrawItem("Exit", ITEMDRAW_CONTROL);

	hPanel.Send(client, OpenOverwriteSaveMenuHandler, MENU_TIME_FOREVER);
	CloseHandle(hPanel);

	return Plugin_Handled;
}

public int OpenOverwriteSaveMenuHandler(Handle hPanel, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(hPanel);

		case MenuAction_Cancel: 
		{
			if(IsValidClient(client))
				EmitSoundToClient(client, "buttons/combine_button7.wav");

			CloseHandle(hPanel);
		}
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 1:
				{
					if(IsValidClient(client))
					{
						EmitSoundToClient(client, "buttons/button14.wav");
						SaveGame(client, Shavit_GetBhopStyle(client));
						CloseHandle(hPanel);
						return Plugin_Handled;
					}
				}
				case 2:
				{
					if(IsValidClient(client))
						EmitSoundToClient(client, "buttons/button14.wav");
						OpenSavestateMenu(client);
				}
				case 10:
				{
					if(IsValidClient(client))
						EmitSoundToClient(client, "buttons/combine_button7.wav");
				}
			}
			Shavit_PrintToChat(client, "Did %sNOT %ssave your game. Load your current save with %s!savestate", g_sChatStrings.sWarning, g_sChatStrings.sText, g_sChatStrings.sVariable);
		}
	}
	CloseHandle(hPanel);
	return Plugin_Handled;
}

void OpenLoadGameMenu(int client)
{
	Menu menu = new Menu(OpenLoadGameMenuHandler);
	int[] iOrderedStyles = new int[g_iStyleCount];
	Shavit_GetOrderedStyles(iOrderedStyles, g_iStyleCount);
	int iStyle;
	char sStyleID[4];
	char sTime[32];
	char sDate[32];
	char sDisplay[128];

	FormatEx(sDisplay, sizeof(sDisplay), "%s\nChoose a save to load\n ", g_sCurrentMap);
	menu.SetTitle(sDisplay);

	for(int i = 0; i < g_iStyleCount; i++)
	{
		iStyle = iOrderedStyles[i];
		if(g_bHasSave[client][iStyle])
		{
			IntToString(iStyle, sStyleID, sizeof(sStyleID));
			FloatToString(g_fSaveTime[client][iStyle], sTime, sizeof(sTime));
			FormatTime(sDate, sizeof(sDate), "%d %b %Y", g_iSaveDate[client][iStyle]);
			FormatEx(sDisplay, sizeof(sDisplay), "%s\n    Time: %s (%s)\n ", g_sStyleStrings[iStyle].sStyleName, FormatToSeconds(sTime), sDate);
			menu.AddItem(sStyleID, sDisplay);
		}
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenLoadGameMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(!IsPlayerAlive(param1))
		{
			Shavit_PrintToChat(param1, "You must be %salive %sto load a saved game", g_sChatStrings.sVariable, g_sChatStrings.sText);
			OpenLoadGameMenu(param1);
			return Plugin_Handled;
		}

		char sStyleID[4];
		menu.GetItem(param2, sStyleID, sizeof(sStyleID));
		int iStyleID = StringToInt(sStyleID);

		if(iStyleID > -1 && iStyleID <= g_iStyleCount)
			LoadGame(param1, iStyleID);

		else
		{
			Shavit_PrintToChat(param1, "Invalid style, please try again");
			OpenLoadGameMenu(param1);
		}
	}
	if(action == MenuAction_Cancel)
		if(param2 == MenuCancel_ExitBack)
			OpenSavestateMenu(param1);

	return Plugin_Handled;
}

public void LoadGame(int client, int style)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client) || !g_bHasSave[client][style])
		return;

	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "%s/savedgames/%s_%i_%i.replay", g_sReplayFolder, g_sCurrentMap, style, GetSteamAccountID(client));

	if(FileExists(sPath))
	{
		if(!LoadReplayCache(g_aReplayCache[client], style, 0, sPath, g_sCurrentMap))
		{
			LogError("Saved game replay failed to load! (%s)", sPath);
			Shavit_PrintToChat(client, "Could %sNOT %sload your game. Replay file unable to be loaded, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
			return;
		}
	}

	char sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `style`, `TbTimerEnabled`, `TfCurrentTime`, `TbClientPaused`, `TiJumps`, `TiStrafes`, `TiTotalMeasures`, `TiGoodGains`, `TfServerTime`, `TiKeyCombo`, `TiTimerTrack`, `TiMeasuredJumps`, `TiPerfectJumps`, `TfZoneOffset1`, `TfZoneOffset2`, `TfDistanceOffset1`, `TfDistanceOffset2`, `TfAvgVelocity`, `TfMaxVelocity`, `TfTimescale`, `TiZoneIncrement`, `TiFullTicks`, `TiFractionalTicks`, `TbPracticeMode`, `TbJumped`, `TbCanUseAllKeys`, `TbOnGround`, `TiLastButtons`, `TfLastAngle`, `TiLandingTick`, `TiLastMoveType`, `TfStrafeWarning`, `TfLastInputVel1`, `TfLastInputVel2`, `Tfplayer_speedmod`, `TfNextFrameTime`, `TiLastMoveTypeTAS`, `CfPosition1`, `CfPosition2`, `CfPosition3`, `CfAngles1`, `CfAngles2`, `CfAngles3`, `CfVelocity1`, `CfVelocity2`, `CfVelocity3`, `CiMovetype`, `CfGravity`, `CfSpeed`, `CfStamina`, `CbDucked`, `CbDucking`, `CfDuckTime`, `CfDuckSpeed`, `CiFlags`, `CsTargetname`, `CsClassname`, `CiPreFrames`, `CbSegmented`, `CiGroundEntity`, `CvecLadderNormal1`, `CvecLadderNormal2`, `CvecLadderNormal3`, `Cm_bHasWalkMovedSinceLastJump`, `Cm_ignoreLadderJumpTime`, `Cm_lastStandingPos1`, `Cm_lastStandingPos2`, `Cm_lastStandingPos3`, `Cm_ladderSuppressionTimer1`, `Cm_ladderSuppressionTimer2`, `Cm_lastLadderNormal1`, `Cm_lastLadderNormal2`, `Cm_lastLadderNormal3`, `Cm_lastLadderPos1`, `Cm_lastLadderPos2`, `Cm_lastLadderPos3`, `Cm_afButtonDisabled`, `Cm_afButtonForced` FROM `saves` WHERE `map` = '%s' AND `auth` = %i AND `style` = %i;", g_sCurrentMap, GetSteamAccountID(client), style);
	SQL_TQuery(g_hSavesDB, SQL_LoadGame, sQuery, client);
}

public void SQL_LoadGame(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("SQL_LoadGame() query failed! %s", error);
		Shavit_PrintToChat(client, "Could %sNOT %sload your game. Database error, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
	}
	else
	{
		if(SQL_GetRowCount(hndl) < 1)
		{
			LogError("SQL_LoadGame() query returned 0 rows!");
			Shavit_PrintToChat(client, "Could %sNOT %sload your game. No saved game found on this style, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
		}
		else if(SQL_GetRowCount(hndl) > 1) //this shouldn't be able to happen.. but better to catch it here just in case (^:
		{
			LogError("SQL_LoadGame() query returned >1 row!");
			Shavit_PrintToChat(client, "Could %sNOT %sload your game. More than one saved game found on this style, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
		}
		else
		{
			int iStyle;
			while(SQL_FetchRow(hndl))
			{
				iStyle = SQL_FetchInt(hndl, 0);
				g_aSavestates[client].aSnapshot.bTimerEnabled = view_as<bool>(SQL_FetchInt(hndl, 1));
				g_aSavestates[client].aSnapshot.fCurrentTime = SQL_FetchFloat(hndl, 2);
				g_aSavestates[client].aSnapshot.bClientPaused = view_as<bool>(SQL_FetchInt(hndl, 3));
				g_aSavestates[client].aSnapshot.iJumps = SQL_FetchInt(hndl, 4);
				g_aSavestates[client].aSnapshot.iStrafes = SQL_FetchInt(hndl, 5);
				g_aSavestates[client].aSnapshot.iTotalMeasures = SQL_FetchInt(hndl, 6);
				g_aSavestates[client].aSnapshot.iGoodGains = SQL_FetchInt(hndl, 7);
				g_aSavestates[client].aSnapshot.fServerTime = SQL_FetchFloat(hndl, 8);
				g_aSavestates[client].aSnapshot.iKeyCombo = SQL_FetchInt(hndl, 9);
				g_aSavestates[client].aSnapshot.iTimerTrack = SQL_FetchInt(hndl, 10);
				g_aSavestates[client].aSnapshot.iMeasuredJumps = SQL_FetchInt(hndl, 11);
				g_aSavestates[client].aSnapshot.iPerfectJumps = SQL_FetchInt(hndl, 12);
				g_aSavestates[client].aSnapshot.fZoneOffset[0] = SQL_FetchFloat(hndl, 13);
				g_aSavestates[client].aSnapshot.fZoneOffset[1] = SQL_FetchFloat(hndl, 14);
				g_aSavestates[client].aSnapshot.fDistanceOffset[0] = SQL_FetchFloat(hndl, 15);
				g_aSavestates[client].aSnapshot.fDistanceOffset[1] = SQL_FetchFloat(hndl, 16);
				g_aSavestates[client].aSnapshot.fAvgVelocity = SQL_FetchFloat(hndl, 17);
				g_aSavestates[client].aSnapshot.fMaxVelocity = SQL_FetchFloat(hndl, 18);
				g_aSavestates[client].aSnapshot.fTimescale = SQL_FetchFloat(hndl, 19);
				g_aSavestates[client].aSnapshot.iZoneIncrement = SQL_FetchInt(hndl, 20);
				g_aSavestates[client].aSnapshot.iFullTicks = SQL_FetchInt(hndl, 21);
				g_aSavestates[client].aSnapshot.iFractionalTicks = SQL_FetchInt(hndl, 22);
				g_aSavestates[client].aSnapshot.bPracticeMode = view_as<bool>(SQL_FetchInt(hndl, 23));
				g_aSavestates[client].aSnapshot.bJumped = view_as<bool>(SQL_FetchInt(hndl, 24));
				g_aSavestates[client].aSnapshot.bCanUseAllKeys = view_as<bool>(SQL_FetchInt(hndl, 25));
				g_aSavestates[client].aSnapshot.bOnGround = view_as<bool>(SQL_FetchInt(hndl, 26));
				g_aSavestates[client].aSnapshot.iLastButtons = SQL_FetchInt(hndl, 27);
				g_aSavestates[client].aSnapshot.fLastAngle = SQL_FetchFloat(hndl, 28);
				g_aSavestates[client].aSnapshot.iLandingTick = SQL_FetchInt(hndl, 29);
				g_aSavestates[client].aSnapshot.iLastMoveType = view_as<MoveType>(SQL_FetchInt(hndl, 30));
				g_aSavestates[client].aSnapshot.fStrafeWarning = SQL_FetchFloat(hndl, 31);
				g_aSavestates[client].aSnapshot.fLastInputVel[0] = SQL_FetchFloat(hndl, 32);
				g_aSavestates[client].aSnapshot.fLastInputVel[1] = SQL_FetchFloat(hndl, 33);
				g_aSavestates[client].aSnapshot.fplayer_speedmod = SQL_FetchFloat(hndl, 34);
				g_aSavestates[client].aSnapshot.fNextFrameTime = SQL_FetchFloat(hndl, 35);
				g_aSavestates[client].aSnapshot.iLastMoveTypeTAS = view_as<MoveType>(SQL_FetchInt(hndl, 36));
				g_aSavestates[client].fPosition[0] = SQL_FetchFloat(hndl, 37);
				g_aSavestates[client].fPosition[1] = SQL_FetchFloat(hndl, 38);
				g_aSavestates[client].fPosition[2] = SQL_FetchFloat(hndl, 39);
				g_aSavestates[client].fAngles[0] = SQL_FetchFloat(hndl, 40);
				g_aSavestates[client].fAngles[1] = SQL_FetchFloat(hndl, 41);
				g_aSavestates[client].fAngles[2] = SQL_FetchFloat(hndl, 42);
				g_aSavestates[client].fVelocity[0] = SQL_FetchFloat(hndl, 43);
				g_aSavestates[client].fVelocity[1] = SQL_FetchFloat(hndl, 44);
				g_aSavestates[client].fVelocity[2] = SQL_FetchFloat(hndl, 45);
				g_aSavestates[client].iMoveType = MOVETYPE_WALK;//view_as<MoveType>(SQL_FetchInt(hndl, 46));
				g_aSavestates[client].fGravity = SQL_FetchFloat(hndl, 47);
				g_aSavestates[client].fSpeed = SQL_FetchFloat(hndl, 48);
				g_aSavestates[client].fStamina = SQL_FetchFloat(hndl, 49);
				g_aSavestates[client].bDucked = view_as<bool>(SQL_FetchInt(hndl, 50));
				g_aSavestates[client].bDucking = view_as<bool>(SQL_FetchInt(hndl, 51));
				g_aSavestates[client].fDucktime = SQL_FetchFloat(hndl, 52);
				g_aSavestates[client].fDuckSpeed = SQL_FetchFloat(hndl, 53);
				g_aSavestates[client].iFlags = SQL_FetchInt(hndl, 54);
				SQL_FetchString(hndl, 55, g_aSavestates[client].sTargetname, sizeof(g_aSavestates[client].sTargetname));
				SQL_FetchString(hndl, 56, g_aSavestates[client].sClassname, sizeof(g_aSavestates[client].sClassname));
				g_aSavestates[client].iPreFrames = SQL_FetchInt(hndl, 57);
				g_aSavestates[client].bSegmented = view_as<bool>(SQL_FetchInt(hndl, 58));
				g_aSavestates[client].iGroundEntity = SQL_FetchInt(hndl, 59);
				g_aSavestates[client].vecLadderNormal[0] = SQL_FetchFloat(hndl, 60);
				g_aSavestates[client].vecLadderNormal[1] = SQL_FetchFloat(hndl, 61);
				g_aSavestates[client].vecLadderNormal[2] = SQL_FetchFloat(hndl, 62);
				g_aSavestates[client].m_bHasWalkMovedSinceLastJump = view_as<bool>(SQL_FetchInt(hndl, 63));
				g_aSavestates[client].m_ignoreLadderJumpTime = SQL_FetchFloat(hndl, 64);
				g_aSavestates[client].m_lastStandingPos[0] = SQL_FetchFloat(hndl, 65);
				g_aSavestates[client].m_lastStandingPos[1] = SQL_FetchFloat(hndl, 66);
				g_aSavestates[client].m_lastStandingPos[2] = SQL_FetchFloat(hndl, 67);
				g_aSavestates[client].m_ladderSurpressionTimer[0] = SQL_FetchFloat(hndl, 68);
				g_aSavestates[client].m_ladderSurpressionTimer[1] = SQL_FetchFloat(hndl, 69);
				g_aSavestates[client].m_lastLadderNormal[0] = SQL_FetchFloat(hndl, 70);
				g_aSavestates[client].m_lastLadderNormal[1] = SQL_FetchFloat(hndl, 71);
				g_aSavestates[client].m_lastLadderNormal[2] = SQL_FetchFloat(hndl, 72);
				g_aSavestates[client].m_lastLadderPos[0] = SQL_FetchFloat(hndl, 73);
				g_aSavestates[client].m_lastLadderPos[1] = SQL_FetchFloat(hndl, 74);
				g_aSavestates[client].m_lastLadderPos[2] = SQL_FetchFloat(hndl, 75);
				g_aSavestates[client].m_afButtonDisabled = SQL_FetchInt(hndl, 76);
				g_aSavestates[client].m_afButtonForced = SQL_FetchInt(hndl, 77);
			}
			g_aSavestates[client].iSteamID = GetSteamAccountID(client);
			g_aSavestates[client].aSnapshot.bsStyle = iStyle;
			Shavit_ClearCheckpoints(client);
			Shavit_StopTimer(client, true);
			if(g_aReplayCache[client].aFrames)
				Shavit_SetReplayData(client, g_aReplayCache[client].aFrames);
			Shavit_SetPlayerPreFrames(client, g_aReplayCache[client].iPreFrames);
			LoadEvents(client, iStyle);
			LoadCustomData(client, iStyle);
			Shavit_LoadCheckpointCache(client, g_aSavestates[client], -1, sizeof(g_aSavestates[client]), true);
			if(Shavit_GetTimerStatus(client) == Timer_Paused)
				Shavit_ResumeTimer(client);
			if(Shavit_GetStyleSettingBool(iStyle, "kzcheckpoints") || Shavit_GetStyleSettingBool(iStyle, "segments"))
				Shavit_SaveCheckpoint(client);
			DeleteLoadedGame(client, iStyle);
			Shavit_PrintToChat(client, "Saved game %sloaded %ssuccessfully and deleted!", g_sChatStrings.sVariable, g_sChatStrings.sText);
		}
	}
}

void LoadEvents(int client, int iStyle)
{
	char sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `type`, `Etarget`, `EtargetInput`, `EvariantValue`, `Edelay`, `Eactivator`, `Ecaller`, `EoutputID`, `EwaitTime` FROM `saves-events` WHERE `map` = '%s' AND `auth` = '%i' AND `style` = '%i' ORDER BY `id` ASC;", g_sCurrentMap, GetSteamAccountID(client), iStyle);
	SQL_TQuery(g_hSavesDB, SQL_LoadEvents, sQuery, client);
}

void SQL_LoadEvents(Handle owner, Handle hndl, const char[] error, int client)
{
	if(SQL_GetRowCount(hndl) != 0)
	{
		g_aSavestates[client].aEvents = new ArrayList(sizeof(event_t));
		g_aSavestates[client].aOutputWaits = new ArrayList(sizeof(entity_t));

		char sType[16];

		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sType, sizeof(sType));
			if(StrEqual(sType, "event"))
			{
				event_t e;
				SQL_FetchString(hndl, 1, e.target, sizeof(e.target));
				SQL_FetchString(hndl, 2, e.targetInput, sizeof(e.targetInput));
				SQL_FetchString(hndl, 3, e.variantValue, sizeof(e.variantValue));
				e.delay = SQL_FetchFloat(hndl, 4);
				e.activator = SQL_FetchInt(hndl, 5);
				e.caller = SQL_FetchInt(hndl, 6);
				e.outputID = SQL_FetchInt(hndl, 7);
				g_aSavestates[client].aEvents.Push(e);
			}
			else if(StrEqual(sType, "output"))
			{
				entity_t e;
				e.caller = SQL_FetchInt(hndl, 6);
				e.waitTime = SQL_FetchFloat(hndl, 8);
				g_aSavestates[client].aOutputWaits.Push(e);
			}
		}
	}
}

void LoadCustomData(int client, int iStyle)
{
	char sQuery[2048];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `key`, `value` FROM `saves-customdata` WHERE `map` = '%s' AND `auth` = '%i' AND `style` = '%i' ORDER BY `id` ASC;", g_sCurrentMap, GetSteamAccountID(client), iStyle);
	SQL_TQuery(g_hSavesDB, SQL_LoadCustomData, sQuery, client);
}

void SQL_LoadCustomData(Handle owner, Handle hndl, const char[] error, int client)
{
	StringMap cd = new StringMap();
	char sKey[64];
	char sValue[64];

	cd.SetValue("mpbhops_punishtime", 0.0);
	cd.SetValue("mpbhops_lastblock", 0);

	if(SQL_GetRowCount(hndl) != 0)
	{
		while(SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, sKey, sizeof(sKey));
			SQL_FetchString(hndl, 1, sValue, sizeof(sValue));
			if(StrEqual(sKey, "mpbhops_punishtime"))
				cd.SetValue("mpbhops_punishtime", StringToFloat(sValue));
			else if(StrEqual(sKey, "mpbhops_lastblock"))
				cd.SetValue("mpbhops_lastblock", StringToInt(sValue));
		}
	}

	g_aSavestates[client].customdata = cd;
}

void DeleteLoadedGame(int client, int iStyle)
{
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "%s/savedgames/%s_%i_%i.replay", g_sReplayFolder, g_sCurrentMap, iStyle, GetSteamAccountID(client));
	if(FileExists(sPath))
		DeleteFile(sPath);

	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `saves` WHERE auth = %i AND map = '%s' AND style = %i;", GetSteamAccountID(client), g_sCurrentMap, iStyle);
	SQL_TQuery(g_hSavesDB, SQL_DeleteLoadedGame, sQuery, client);

	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `saves-events` WHERE auth = %i AND map = '%s' AND style = %i;", GetSteamAccountID(client), g_sCurrentMap, iStyle);
	SQL_TQuery(g_hSavesDB, SQL_GeneralCallback, sQuery, client);

	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `saves-customdata` WHERE auth = %i AND map = '%s' AND style = %i;", GetSteamAccountID(client), g_sCurrentMap, iStyle);
	SQL_TQuery(g_hSavesDB, SQL_GeneralCallback, sQuery, client);
}

public void SQL_DeleteLoadedGame(Handle owner, Handle hndl, const char[] error, int client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("SQL_DeleteLoadedGame query failed! %s", error);
		Shavit_PrintToChat(client, "[Shavit-SaveGame] %sDatabase error%s, tell an admin to check the logs!", g_sChatStrings.sWarning, g_sChatStrings.sText);
	}
	else
		GetClientSaves(client);
}

void OpenViewSavesMenu(int client)
{
	char sQuery[512];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `map`, `style`, `TfCurrentTime`, `date` FROM `saves` WHERE auth = %i ORDER BY `date` DESC;", GetSteamAccountID(client));
	SQL_TQuery(g_hSavesDB, SQL_OpenViewSavesMenu, sQuery, client);
}

void SQL_OpenViewSavesMenu(Handle owner, Handle hndl, const char[] error, int client)
{
	if(SQL_GetRowCount(hndl) == 0)
	{
		Shavit_PrintToChat(client, "No saves found");
		OpenSavestateMenu(client);
		return;
	}

	Menu menu = new Menu(OpenViewSavesMenuHandler);
	menu.SetTitle("All Savestates (Select to nominate)\n ");

	char sMap[255];
	int iStyle;
	char sStyle[4];
	float fTime;
	char sTime[32];
	int iDate;
	char sDate[32];
	char sDisplay[255];
	while(SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, sMap, sizeof(sMap));
		iStyle = SQL_FetchInt(hndl, 1);
		fTime = SQL_FetchFloat(hndl, 2);
		iDate = SQL_FetchInt(hndl, 3);

		IntToString(iStyle, sStyle, sizeof(sStyle));
		FloatToString(fTime, sTime, sizeof(sTime));
		FormatTime(sDate, sizeof(sDate), "%d %b %Y", iDate);

		FormatEx(sDisplay, sizeof(sDisplay), "%s - %s\n    Time: %s (%s)\n ", sMap, g_sStyleStrings[iStyle].sStyleName, FormatToSeconds(sTime), sDate);
		menu.AddItem(sMap, sDisplay, StrEqual(g_sCurrentMap, sMap) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenViewSavesMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sMap[PLATFORM_MAX_PATH];
		menu.GetItem(param2, sMap, sizeof(sMap));
		FakeClientCommand(param1, "sm_nominate %s", sMap);
	}
	if(action == MenuAction_Cancel)
		if(param2 == MenuCancel_ExitBack)
			OpenSavestateMenu(param1);
	return Plugin_Handled;
}

char[] FormatToSeconds(char time[32])
{
	int iTemp = RoundToFloor(StringToFloat(time));
	int iHours = 0;

	if(iTemp > 3600)
	{
		iHours = iTemp / 3600;
		iTemp %= 3600;
	}

	int iMinutes = 0;

	if(iTemp >= 60)
	{
		iMinutes = iTemp / 60;
		iTemp %= 60;
	}

	float fSeconds = iTemp + StringToFloat(time) - RoundToFloor(StringToFloat(time));

	char result[32];

	if (iHours > 0)
	{
		Format(result, sizeof(result), "%ih %im %.1fs", iHours, iMinutes, fSeconds);
	}
	else if(iMinutes > 0)
	{
		Format(result, sizeof(result), "%im %.1fs", iMinutes, fSeconds);
	}
	else
	{
		Format(result, sizeof(result), "%.1fs", fSeconds);
	}

	return result;
}
