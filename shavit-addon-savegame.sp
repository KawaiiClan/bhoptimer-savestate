#include <sourcemod>
#include <sdktools>
#include <shavit>
#include <shavit/replay-file>
#include <shavit/replay-stocks.sp>

#pragma newdecls required
#pragma semicolon 1

cp_cache_t g_aSavestates[MAXPLAYERS+1];
chatstrings_t g_sChatStrings;
stylestrings_t g_sStyleStrings[STYLE_LIMIT];

bool g_bLate = false;

Handle g_hSavesDB = INVALID_HANDLE;

float g_fTickrate = 0.0;
int g_iStyleCount;
bool g_bHasAnySaves[MAXPLAYERS+1];
bool g_bHasSave[MAXPLAYERS+1][STYLE_LIMIT];
bool g_bNotified[MAXPLAYERS+1];
char g_sCurrentMap[255];
char g_sReplayFolder[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "[shavit] Save Game",
	author = "olivia",
	description = "Allow saving and loading savestates in shavit's bhoptimer",
	version = "c:",
	url = "https://KawaiiClan.com"
}

public void OnPluginStart()
{
	g_fTickrate = (1.0 / GetTickInterval());
	
	RegAdminCmd("sm_savegame", Command_SaveGame, ADMFLAG_GENERIC, "Save your timer state to load later");
	RegAdminCmd("sm_loadgame", Command_LoadGame, ADMFLAG_GENERIC, "Load your saved timer state");
	/*RegConsoleCmd("sm_savetimer", Command_SaveGame, "Save your timer state to load later");
	RegConsoleCmd("sm_savestate", Command_SaveGame, "Save your timer state to load later");
	RegConsoleCmd("sm_saves", Command_LoadGame, "Save your timer state to load later");
	RegConsoleCmd("sm_savestates", Command_SaveGame, "Save your timer state to load later");
	RegConsoleCmd("sm_loadtimer", Command_LoadGame, "Load your saved timer state");
	RegConsoleCmd("sm_restore", Command_LoadGame, "Load your saved timer state");
	RegConsoleCmd("sm_restoregame", Command_LoadGame, "Load your saved timer state");
	RegConsoleCmd("sm_restoretimer", Command_LoadGame, "Load your saved timer state");*/
	
	InitSavesDB(g_hSavesDB);
	
	if(g_bLate)
	{
		GetLowercaseMapName(g_sCurrentMap);
		
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
		
		Shavit_OnChatConfigLoaded();
		Shavit_OnStyleConfigLoaded(-1);
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
	{
		styles = Shavit_GetStyleCount();
	}

	for(int i = 0; i < styles; i++)
	{
		Shavit_GetStyleStrings(i, sStyleName, g_sStyleStrings[i].sStyleName, sizeof(stylestrings_t::sStyleName));
	}

	g_iStyleCount = styles;
	
	if(!Shavit_GetReplayFolderPath_Stock(g_sReplayFolder))
	{
		SetFailState("Could not load the replay bots' configuration file. Make sure it exists (addons/sourcemod/configs/shavit-replay.cfg) and follows the proper syntax!");
	}
	
	char sSavedGamesPath[PLATFORM_MAX_PATH];
	FormatEx(sSavedGamesPath, sizeof(sSavedGamesPath), "%s/savedgames", g_sReplayFolder);
	if(!DirExists(sSavedGamesPath) && !CreateDirectory(sSavedGamesPath, 511))
	{
		SetFailState("Failed to create replay folder (%s). Make sure you have file permissions", sSavedGamesPath);
	}
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
	char Error[255];
	
	DbHNDL = SQL_Connect("savegame", true, Error, sizeof(Error));
	if(DbHNDL == INVALID_HANDLE)
	{
		SetFailState(Error);
	}
	else
	{
		char Query[8196];
		Format(Query, sizeof(Query), "CREATE TABLE IF NOT EXISTS `saves` (`map` varchar(100) NOT NULL, `auth` int NOT NULL, `style` int NOT NULL, `TbTimerEnabled` int NOT NULL, `TfCurrentTime` float NOT NULL, `TbClientPaused` int NOT NULL, `TiJumps` int NOT NULL, `TiStrafes` int NOT NULL, `TiTotalMeasures` int, `TiGoodGains` int, `TfServerTime` int NOT NULL, `TiKeyCombo` int NOT NULL, `TiTimerTrack` int NOT NULL, `TiMeasuredJumps` int, `TiPerfectJumps` int, `TfZoneOffset1` float, `TfZoneOffset2` float, `TfDistanceOffset1` float, `TfDistanceOffset2` float, `TfAvgVelocity` float, `TfMaxVelocity` float, `TfTimescale` float NOT NULL, `TiZoneIncrement` int, `TiFullTicks` int NOT NULL, `TiFractionalTicks` int NOT NULL, `TbPracticeMode` int NOT NULL, `TbJumped` int NOT NULL, `TbCanUseAllKeys` int NOT NULL, `TbOnGround` int NOT NULL, `TiLastButtons` int, `TfLastAngle` float, `TiLandingTick` int, `TiLastMoveType` int, `TfStrafeWarning` float, `TfLastInputVel1` float, `TfLastInputVel2` float, `Tfplayer_speedmod` float, `TfNextFrameTime` float, `TiLastMoveTypeTAS` int, `CfPosition1` float NOT NULL, `CfPosition2` float NOT NULL, `CfPosition3` float NOT NULL, `CfAngles1` float NOT NULL, `CfAngles2` float NOT NULL, `CfAngles3` float NOT NULL, `CfVelocity1` float NOT NULL, `CfVelocity2` float NOT NULL, `CfVelocity3` float NOT NULL, `CiMovetype` int NOT NULL, `CfGravity` float NOT NULL, `CfSpeed` float NOT NULL, `CfStamina` float NOT NULL, `CbDucked` int NOT NULL, `CbDucking` int NOT NULL, `CfDuckTime` float, `CfDuckSpeed` float, `CiFlags` int NOT NULL, `CsTargetname` varchar(64) NOT NULL, `CsClassname` varchar(64) NOT NULL, `CiPreFrames` int NOT NULL, `CbSegmented` int NOT NULL, `CiGroundEntity` int, `CvecLadderNormal1` float, `CvecLadderNormal2` float, `CvecLadderNormal3` float, `Cm_bHasWalkMovedSinceLastJump` int, `Cm_ignoreLadderJumpTime` float, `Cm_lastStandingPos1` float, `Cm_lastStandingPos2` float, `Cm_lastStandingPos3` float, `Cm_ladderSuppressionTimer1` float, `Cm_ladderSuppressionTimer2` float, `Cm_lastLadderNormal1` float, `Cm_lastLadderNormal2` float, `Cm_lastLadderNormal3` float, `Cm_lastLadderPos1` float, `Cm_lastLadderPos2` float, `Cm_lastLadderPos3` float, `Cm_afButtonDisabled` int, `Cm_afButtonForced` int, UNIQUE KEY `unique_index` (`map`,`auth`,`style`)) ENGINE=INNODB;");
		SQL_TQuery(g_hSavesDB, SQL_ErrorCheckCallBack, Query);
	}
	
	return Plugin_Handled;
}

void GetClientSaves(int client)
{
	char Query[255];
	
	Format(Query, sizeof(Query), "SELECT `style` FROM `saves` WHERE auth = %i AND map = '%s';", GetSteamAccountID(client), g_sCurrentMap);
	
	SQL_TQuery(g_hSavesDB, SQL_GetClientSaves, Query, client);
}

public void SQL_GetClientSaves(Handle owner, Handle hndl, const char[] error, int client)
{
	g_bHasAnySaves[client] = false;
	g_bNotified[client] = false;
	for(int i = 0; i <= g_iStyleCount; i++)
	{
		g_bHasSave[client][i] = false;
	}
	
	if(SQL_GetRowCount(hndl) != 0)
	{
		g_bHasAnySaves[client] = true;
		while(SQL_FetchRow(hndl))
		{
			int iStyle = SQL_FetchInt(hndl, 0);
			g_bHasSave[client][iStyle] = true;
		}
	}
}

public void Shavit_OnRestart(int client, int track)
{
	if(g_bHasAnySaves[client] && !g_bNotified[client])
	{
		Shavit_PrintToChat(client, "You have a saved game on this map! Load it with %s!loadgame", g_sChatStrings.sVariable);
		g_bNotified[client] = true;
	}
}

public Action Command_SaveGame(int client, int args)
{
	if(client == 0)
	{
		ReplyToCommand(client, "This command may only be performed in game");
		return Plugin_Handled;
	}

	if(Shavit_GetClientTrack(client) != 0)
	{
		Shavit_PrintToChat(client, "Did %sNOT %ssave your game. This feature is for the %smain %strack only", g_sChatStrings.sWarning, g_sChatStrings.sText, g_sChatStrings.sVariable, g_sChatStrings.sText);
		return Plugin_Handled;
	}
	
	if(!Shavit_CanPause(client) || Shavit_IsPaused(client))
	{
		int iStyle = Shavit_GetBhopStyle(client);
		
		if(g_bHasSave[client][iStyle])
		{
			OpenOverwriteSaveMenu(client, iStyle);
		}
		else
		{
			SaveGame(client, iStyle);
		}
	}
	else
	{
		Shavit_PrintToChat(client, "Did %sNOT %ssave your game. Your timer must be %spaused%s, or pause conditions must be met! (alive, not moving, uncrouched, etc.)", g_sChatStrings.sWarning, g_sChatStrings.sText, g_sChatStrings.sVariable, g_sChatStrings.sText);
	}
	return Plugin_Handled;
}

public void SaveGame(int client, int style)
{
	if(style != Shavit_GetBhopStyle(client) || Shavit_GetClientTrack(client) != 0)
		return;
	
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "%s/savedgames/%s_%i_%i.replay", g_sReplayFolder, g_sCurrentMap, style, GetSteamAccountID(client));
	
	File file = null;
	if(!(file = OpenFile(sPath, "wb+")))
	{
		LogError("Failed to open savegame replay file for writing. ('%s')", sPath);
	}
	
	ArrayList ReplayFrames = Shavit_GetReplayData(client);
	
	Shavit_SaveCheckpointCache(client, client, g_aSavestates[client], -1, sizeof(g_aSavestates[client]));
	Shavit_ClearCheckpoints(client);
	
	float fZoneOffset[2];
	fZoneOffset[0] = g_aSavestates[client].aSnapshot.fZoneOffset[0];
	fZoneOffset[1] = g_aSavestates[client].aSnapshot.fZoneOffset[1];
	
	int iSize = Shavit_GetClientFrameCount(client);
	
	WriteReplayHeader(file, style, 0, g_aSavestates[client].aSnapshot.fCurrentTime, GetSteamAccountID(client), g_aSavestates[client].iPreFrames, 0, fZoneOffset, iSize, g_fTickrate, g_sCurrentMap);
	WriteReplayFrames(ReplayFrames, iSize, file, null);
	delete file;
	delete ReplayFrames;
	
	Shavit_StopTimer(client, true);
	
	char Query[8000];
	Format(Query, sizeof(Query), "REPLACE INTO `saves` (`map`, `auth`, `style`, `TbTimerEnabled`, `TfCurrentTime`, `TbClientPaused`, `TiJumps`, `TiStrafes`, `TiTotalMeasures`, `TiGoodGains`, `TfServerTime`, `TiKeyCombo`, `TiTimerTrack`, `TiMeasuredJumps`, `TiPerfectJumps`, `TfZoneOffset1`, `TfZoneOffset2`, `TfDistanceOffset1`, `TfDistanceOffset2`, `TfAvgVelocity`, `TfMaxVelocity`, `TfTimescale`, `TiZoneIncrement`, `TiFullTicks`, `TiFractionalTicks`, `TbPracticeMode`, `TbJumped`, `TbCanUseAllKeys`, `TbOnGround`, `TiLastButtons`, `TfLastAngle`, `TiLandingTick`, `TiLastMoveType`, `TfStrafeWarning`, `TfLastInputVel1`, `TfLastInputVel2`, `Tfplayer_speedmod`, `TfNextFrameTime`, `TiLastMoveTypeTAS`, `CfPosition1`, `CfPosition2`, `CfPosition3`, `CfAngles1`, `CfAngles2`, `CfAngles3`, `CfVelocity1`, `CfVelocity2`, `CfVelocity3`, `CiMovetype`, `CfGravity`, `CfSpeed`, `CfStamina`, `CbDucked`, `CbDucking`, `CfDuckTime`, `CfDuckSpeed`, `CiFlags`, `CsTargetname`, `CsClassname`, `CiPreFrames`, `CbSegmented`, `CiGroundEntity`, `CvecLadderNormal1`, `CvecLadderNormal2`, `CvecLadderNormal3`, `Cm_bHasWalkMovedSinceLastJump`, `Cm_ignoreLadderJumpTime`, `Cm_lastStandingPos1`, `Cm_lastStandingPos2`, `Cm_lastStandingPos3`, `Cm_ladderSuppressionTimer1`, `Cm_ladderSuppressionTimer2`,  `Cm_lastLadderNormal1`, `Cm_lastLadderNormal2`, `Cm_lastLadderNormal3`, `Cm_lastLadderPos1`, `Cm_lastLadderPos2`, `Cm_lastLadderPos3`, `Cm_afButtonDisabled`, `Cm_afButtonForced`) VALUES ('%s', '%i', '%i', '%i', '%f', '%i', '%i', '%i', '%i', '%i', '%f', '%i', '%i', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%i', '%f', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%f', '%f', '%f', '%i', '%i', '%f', '%f', '%i', '%s', '%s', '%i', '%i', '%i', '%f', '%f', '%f', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i');",
														g_sCurrentMap, GetSteamAccountID(client), g_aSavestates[client].aSnapshot.bsStyle, view_as<int>(g_aSavestates[client].aSnapshot.bTimerEnabled), g_aSavestates[client].aSnapshot.fCurrentTime, view_as<int>(g_aSavestates[client].aSnapshot.bClientPaused), g_aSavestates[client].aSnapshot.iJumps,
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
														g_aSavestates[client].m_afButtonDisabled, g_aSavestates[client].m_afButtonForced
														);
	
	SQL_TQuery(g_hSavesDB, SQL_SaveGame, Query, client);
}

public void SQL_SaveGame(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Save game query failed! %s", error);
		Shavit_PrintToChat(client, "Did %sNOT %ssave your game. Database error, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
		
		Shavit_LoadCheckpointCache(client, g_aSavestates[client], -1, sizeof(g_aSavestates[client]), true);
	}
	else
	{
		GetClientSaves(client);
		Shavit_PrintToChat(client, "Timer saved! Load your save on this map later with %s!loadgame", g_sChatStrings.sVariable);
	}
}

public Action OpenOverwriteSaveMenu(int client, int style)
{
	Panel hPanel = CreatePanel();
	char sDisplay[128];
	
	FormatEx(sDisplay, sizeof(sDisplay), "Found your saved game on %s", g_sCurrentMap);
	hPanel.SetTitle(sDisplay);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Style: %s", g_sStyleStrings[style].sStyleName);
	hPanel.DrawItem(sDisplay, ITEMDRAW_RAWLINE);
	
	hPanel.DrawItem(" ", ITEMDRAW_RAWLINE);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Overwrite?");
	hPanel.DrawItem(sDisplay, ITEMDRAW_RAWLINE);
	
	FormatEx(sDisplay, sizeof(sDisplay), "Yes");
	hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);
	
	FormatEx(sDisplay, sizeof(sDisplay), "No");
	hPanel.DrawItem(sDisplay, ITEMDRAW_CONTROL);
	
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
		{
			CloseHandle(hPanel);
		}
		case MenuAction_Cancel: 
		{
			if(IsValidClient(client))
			{
				EmitSoundToClient(client, "buttons/combine_button7.wav");
			}
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
				}
				case 10:
				{
					if(IsValidClient(client))
						EmitSoundToClient(client, "buttons/combine_button7.wav");
				}
			}
			Shavit_PrintToChat(client, "Did %sNOT %ssave your game. Load your current save with %s!loadgame", g_sChatStrings.sWarning, g_sChatStrings.sText, g_sChatStrings.sVariable);
		}
	}
	CloseHandle(hPanel);
	return Plugin_Handled;
}

public Action Command_LoadGame(int client, int args)
{
	if(!IsValidClient(client))
		ReplyToCommand(client, "This command may only be performed in game");
		
	else if(!g_bHasAnySaves[client])
		Shavit_PrintToChat(client, "No saved games found on this map, try again later");
		
	else if(!IsPlayerAlive(client))
		Shavit_PrintToChat(client, "You must be %salive %sto load a saved game", g_sChatStrings.sVariable, g_sChatStrings.sText);
		
	else
		OpenLoadGameMenu(client);
		
	return Plugin_Handled;
}

void OpenLoadGameMenu(int client)
{
	Menu menu = new Menu(OpenLoadGameMenuHandler);
	menu.SetTitle("Choose a save to load\n ");
	
	int[] styles = new int[g_iStyleCount];
	Shavit_GetOrderedStyles(styles, g_iStyleCount);

	for(int i = 0; i < g_iStyleCount; i++)
	{
		int iStyle = styles[i];
		if(g_bHasSave[client][iStyle])
		{
			char sStyleID[4];
			IntToString(iStyle, sStyleID, sizeof(sStyleID));
			menu.AddItem(sStyleID, g_sStyleStrings[iStyle].sStyleName);
		}
	}
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int OpenLoadGameMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char sStyleID[4];
		menu.GetItem(param2, sStyleID, sizeof(sStyleID));
		int iStyleID = StringToInt(sStyleID);
		
		if(iStyleID > -1 && iStyleID <= g_iStyleCount)
		{
			LoadGame(param1, iStyleID);
		}
		else
		{
			Shavit_PrintToChat(param1, "Invalid style, please try again");
			OpenLoadGameMenu(param1);
		}
	}
	return Plugin_Handled;
}

public void LoadGame(int client, int style)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client) || !g_bHasSave[client][style])
	{
		return;
	}
	
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "%s/savedgames/%s_%i_%i.replay", g_sReplayFolder, g_sCurrentMap, style, GetSteamAccountID(client));
	
	replay_header_t header;
	frame_cache_t cache;
	
	File file = ReadReplayHeader(sPath, header, style, 0);
	if (file != null)
	{
		if (header.iReplayVersion > REPLAY_FORMAT_SUBVERSION)
		{
			// not going to try and read it
		}
		else if (header.iReplayVersion < 0x03 || (StrEqual(header.sMap, g_sCurrentMap, false) && header.iStyle == style && header.iTrack == 0))
		{
			ReadReplayFrames(file, header, cache);
		}

		delete file;
	}
	
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}
	
	Shavit_ClearCheckpoints(client);
	Shavit_StopTimer(client, true);
	//Shavit_ChangeClientStyle(client, style, true, false, true); //i think this might be a good thing to have here as well? idk.. not sure yet
	Shavit_SetReplayData(client, cache.aFrames);
	
	char Query[2048];
	Format(Query, sizeof(Query), "SELECT `style`, `TbTimerEnabled`, `TfCurrentTime`, `TbClientPaused`, `TiJumps`, `TiStrafes`, `TiTotalMeasures`, `TiGoodGains`, `TfServerTime`, `TiKeyCombo`, `TiTimerTrack`, `TiMeasuredJumps`, `TiPerfectJumps`, `TfZoneOffset1`, `TfZoneOffset2`, `TfDistanceOffset1`, `TfDistanceOffset2`, `TfAvgVelocity`, `TfMaxVelocity`, `TfTimescale`, `TiZoneIncrement`, `TiFullTicks`, `TiFractionalTicks`, `TbPracticeMode`, `TbJumped`, `TbCanUseAllKeys`, `TbOnGround`, `TiLastButtons`, `TfLastAngle`, `TiLandingTick`, `TiLastMoveType`, `TfStrafeWarning`, `TfLastInputVel1`, `TfLastInputVel2`, `Tfplayer_speedmod`, `TfNextFrameTime`, `TiLastMoveTypeTAS`, `CfPosition1`, `CfPosition2`, `CfPosition3`, `CfAngles1`, `CfAngles2`, `CfAngles3`, `CfVelocity1`, `CfVelocity2`, `CfVelocity3`, `CiMovetype`, `CfGravity`, `CfSpeed`, `CfStamina`, `CbDucked`, `CbDucking`, `CfDuckTime`, `CfDuckSpeed`, `CiFlags`, `CsTargetname`, `CsClassname`, `CiPreFrames`, `CbSegmented`, `CiGroundEntity`, `CvecLadderNormal1`, `CvecLadderNormal2`, `CvecLadderNormal3`, `Cm_bHasWalkMovedSinceLastJump`, `Cm_ignoreLadderJumpTime`, `Cm_lastStandingPos1`, `Cm_lastStandingPos2`, `Cm_lastStandingPos3`, `Cm_ladderSuppressionTimer1`, `Cm_ladderSuppressionTimer2`, `Cm_lastLadderNormal1`, `Cm_lastLadderNormal2`, `Cm_lastLadderNormal3`, `Cm_lastLadderPos1`, `Cm_lastLadderPos2`, `Cm_lastLadderPos3`, `Cm_afButtonDisabled`, `Cm_afButtonForced` FROM `saves` WHERE `map` = '%s' AND `auth` = %i AND `style` = %i;", g_sCurrentMap, GetSteamAccountID(client), style);
	SQL_TQuery(g_hSavesDB, SQL_LoadGame, Query, client);
}

public void SQL_LoadGame(Handle owner, Handle hndl, const char[] error, any client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Load game query failed! %s", error);
		Shavit_PrintToChat(client, "Could %sNOT %sload your game. Database error, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
	}
	else
	{
		if(SQL_GetRowCount(hndl) < 1)
		{
			Shavit_PrintToChat(client, "Could %sNOT %sload your game. No saved game found on this style, try again or tell an admin!", g_sChatStrings.sWarning, g_sChatStrings.sText);
		}
		else if(SQL_GetRowCount(hndl) > 1) //this shouldn't be able to happen.. but better to catch it here just in case (^:
		{
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
				g_aSavestates[client].iMoveType = view_as<MoveType>(SQL_FetchInt(hndl, 46));
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
			Shavit_PrintToChat(client, "Saved game %sloaded %ssuccessfully!", g_sChatStrings.sVariable, g_sChatStrings.sText);
			Shavit_LoadCheckpointCache(client, g_aSavestates[client], -1, sizeof(g_aSavestates[client]), true);
			Shavit_ChangeClientStyle(client, iStyle, true, false, true);
			DeleteLoadedGame(client, iStyle);
		}
	}
}

void DeleteLoadedGame(int client, int iStyle)
{
	char Query[512];
	Format(Query, sizeof(Query), "DELETE FROM `saves` WHERE auth = %i AND map = '%s' AND style = %i;", GetSteamAccountID(client), g_sCurrentMap, iStyle);
	
	SQL_TQuery(g_hSavesDB, SQL_DeleteLoadedGame, Query, client);
}

public void SQL_DeleteLoadedGame(Handle owner, Handle hndl, const char[] error, int client)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Saved game post-load delete query failed! %s", error);
		Shavit_PrintToChat(client, "[Shavit-SaveGame] %sDatabase error%s, tell an admin to check the logs!", g_sChatStrings.sWarning, g_sChatStrings.sText);
	}
	else
	{
		GetClientSaves(client);
	}
}

public void SQL_ErrorCheckCallBack(Handle owner, Handle hndl, const char[] error, any data)
{
	if(hndl == INVALID_HANDLE)
	{
		LogError("Query failed! %s", error);
	}
}
