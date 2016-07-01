#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <logdebug>

public Plugin myinfo = 
{
	name = "sm_ttt_verify",
	author = PLUGIN_AUTHOR,
	description = "Allows admins to verify all players",
	version = PLUGIN_VERSION,
	url = ""
};

//Global Database Handle
Database g_hDatabase;

//Global enum
enum PlayerInfos {
	String:PlayerName[64],
	String:PlayerID[21],
	String:AdminName[64],
	String:AdminID[21],
	Timestamp
}

int g_ePlayerInfos[MAXPLAYERS + 1][PlayerInfos];

bool g_bDatabaseConnected = false;

Handle g_hOnClientVerified = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hOnClientVerified = CreateGlobalForward("VF_OnClientVerified", ET_Ignore, Param_Cell);
	CreateNative("VF_IsClientVerified", Native_IsClientVerified);
}

public void OnPluginStart()
{
	InitDebugLog("verify_debug", "Verify", ADMFLAG_GENERIC);
	LogDebug("Verify started ...");
	g_bDatabaseConnected = false;
	DBConnect();
	
	RegAdminCmd("sm_verify", Command_Verify, ADMFLAG_GENERIC);
	
	LoadInfosAll();
	
	LoadTranslations("verify.phrases");
	LoadTranslations("common.phrases.txt");
	
	AutoExecConfig(true);
}

/************************
		Commands
*************************/

public Action Command_Verify(int iClient, int iArgs){
	if(!IsClientValid(iClient)){
		return Plugin_Handled;
	}
	
	if(iArgs == 0){
		ShowUnverified(iClient);
		return Plugin_Handled;
	}
	
	int iTarget;
	
	if(iArgs > 1){
		CPrintToChat(iClient, "%t", "Too_Much_Arguments");
	}
	char sName[64];
	GetCmdArg(1, sName, sizeof(sName));
	iTarget = FindTarget(iClient, sName);
	
	if(iTarget == -1){
		return Plugin_Handled;
	}
	
	if(IsVerified(iTarget)){
		char sName2[64];
		GetClientName(iTarget, sName2, sizeof(sName2));
		
		char sDate[64];
		FormatTime(sDate, sizeof(sDate), "%D", g_ePlayerInfos[iTarget][Timestamp]);
		CPrintToChat(iClient, "%t", "Already_Verified", g_ePlayerInfos[iTarget][PlayerName], g_ePlayerInfos[iTarget][PlayerID], g_ePlayerInfos[iTarget][AdminName], g_ePlayerInfos[iTarget][AdminID], sDate);
		return Plugin_Handled;
	}
	VerifyPlayer(iTarget, iClient);
	return Plugin_Handled;
}
/************************
		  Events
*************************/

public void OnClientPostAdminCheck(iClient){
	if(!g_bDatabaseConnected)
	    return;
	char sTest[64];
	GetClientAuthId(iClient, AuthId_Steam2, sTest, sizeof(sTest));
	LogDebug("Client SteamID: %s", sTest);
	LogDebug("Loading Info of the joined player");
	if(!LoadPlayerInfos(iClient)){
		LogError("Loading of Playerinfos from the database failed");
	}
}

/************************
		Functions
*************************/

public bool IsClientValid(int iClient){
	if(IsClientAuthorized(iClient) && IsClientInGame(iClient) && !IsClientSourceTV(iClient)){
		return true;
	}
	return false;
}

public int LoadPlayerInfos(int iClient){
	if(!IsClientValid(iClient) || g_hDatabase == INVALID_HANDLE){
		return 0;
	}
	
	char sPlayerID[21];
	char sQuery[256];
	GetClientAuthId(iClient, AuthId_Steam2, sPlayerID, sizeof(sPlayerID));
	DataPack p_pInfos;
	p_pInfos = CreateDataPack();
	p_pInfos.WriteCell(iClient);
	p_pInfos.WriteString(sPlayerID);
	
	Format(sQuery, sizeof(sQuery), "SELECT `playerid`, `playername`, `adminid`, `adminname`, `time` FROM `verify` WHERE `playerid` = '%s'", sPlayerID);
	
	g_hDatabase.Query(DBLoadInfos_Callback, sQuery, p_pInfos);
	return 1;
}
public void LoadInfosAll(){
	for(int i = 1; i <= MaxClients; i++){
		LogDebug("Checking Infos for %i", i);
		if(IsClientValid(i) && !IsFakeClient(i)){
			LogDebug("Loading Info for %i", i);
			LoadPlayerInfos(i);
		}
	}
}
public void ShowUnverified(int iClient)
{
	char sName[64];
	int iCounter;
	Menu menu = new Menu(Unverified_Menu);
	menu.SetTitle("Unverified Player:");
	menu.ExitButton = true;
	for(int i = 1; i <= MaxClients; i++){
		if(IsClientValid(i) && !IsVerified(i) && !IsFakeClient(i)){
			GetClientName(i, sName, sizeof(sName));
			menu.AddItem(sName, sName);
			iCounter++;
		}
	}
	if(!iCounter){
		CPrintToChat(iClient, "%t", "Nobody_Unverified");
		delete menu;
	}else{
		menu.Display(iClient, 60);
	}
}

public int Unverified_Menu(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	if (action == MenuAction_Select)
	{
		char sName[64];
		menu.GetItem(param2, sName, sizeof(sName));
		int iTarget = FindTarget(param1, sName, false);
		VerifyPlayer(iTarget, param1);
		ShowUnverified(param1);
	}
}

public bool IsVerified(int iClient){
	LogDebug("Timestamp: %i", g_ePlayerInfos[iClient][Timestamp]);
	if(g_ePlayerInfos[iClient][Timestamp] != 0){
		LogDebug("Returning true");
		return true;
	}
	LogDebug("Returning false");
	return false;
}

public void VerifyPlayer(int iPlayer, int iAdmin){
		char sPlayerName[64];
		char sAdminName[64];
		char sPlayerID[21];
		char sAdminID[21];
		char sPlayerNameE[sizeof(sPlayerName)*2+1];
		char sAdminNameE[sizeof(sAdminName)*2+1];
		GetClientAuthId(iPlayer, AuthId_Steam2, sPlayerID, sizeof(sPlayerID));
		GetClientAuthId(iAdmin, AuthId_Steam2, sAdminID, sizeof(sAdminID));
		GetClientName(iPlayer, sPlayerName, sizeof(sPlayerName));
		GetClientName(iAdmin, sAdminName, sizeof(sAdminName));
		g_hDatabase.Escape(sPlayerName, sPlayerNameE, sizeof(sPlayerNameE));
		g_hDatabase.Escape(sAdminName, sAdminNameE, sizeof(sAdminNameE));
		
		
		char sQuery[256];
		Format(sQuery, sizeof(sQuery), "INSERT INTO `verify` (`playerid`, `playername`, `adminid`, `adminname`, `time`) VALUES (\"%s\", \"%s\", \"%s\", \"%s\", %i) ON DUPLICATE KEY UPDATE id=id", sPlayerID, sPlayerNameE, sAdminID, sAdminNameE, GetTime());
		g_hDatabase.Query(DBQuery_Callback, sQuery);
		
		strcopy(g_ePlayerInfos[iPlayer][PlayerName], 64, sPlayerName);
		strcopy(g_ePlayerInfos[iPlayer][PlayerID], 21, sPlayerID);
		strcopy(g_ePlayerInfos[iPlayer][AdminName], 64, sAdminName);
		strcopy(g_ePlayerInfos[iPlayer][AdminID], 21, sAdminID);
		g_ePlayerInfos[iPlayer][Timestamp] = GetTime();
		CPrintToChat(iAdmin, "%t", "Verified", sPlayerName);
		Call_StartForward(g_hOnClientVerified);
		Call_PushCell(iPlayer);
		Call_Finish();
}

/************************
		Database
*************************/

public void DBConnect(){
	if(!SQL_CheckConfig("verify")){
		LogDebug("Could not find the verify Database entry");
		SetFailState("Couldn't find the database entry 'verify'!");
	}else{
		LogDebug("Trying to connect to the database");
		Database.Connect(DBConnect_Callback, "verify");
	}
}

public void DBConnect_Callback(Database db, const char[] error, any data)
{
	if(db == null){
		LogDebug("Database Connection Failed: %s . Unloading ...", error);
		SetFailState("Database connection failed!: %s", error);
		return;
	}
	
	LogDebug("Database Connect was succesfull");
	g_bDatabaseConnected = true;
	g_hDatabase = db;
	g_hDatabase.SetCharset("utf8mb4");
	LogDebug("Trying to Create Tables");
	char sQuery[512];
	Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `verify` ( `id` INT NOT NULL AUTO_INCREMENT, `playerid` VARCHAR(21) NOT NULL, `playername` VARCHAR(64) CHARACTER SET utf8mb4 NOT NULL, `adminid` VARCHAR(21) NOT NULL, `adminname` VARCHAR(64) CHARACTER SET utf8mb4 NOT NULL,`time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE (`playerid`))");
	g_hDatabase.Query(DBCreateTable_Callback, sQuery);
}

public void DBCreateTable_Callback(Database db, DBResultSet results, const char[] error, any data){
	if(strlen(error) > 0 || results == INVALID_HANDLE){
		LogDebug("Table Creation failed: %s .Unloading ...", error);
		SetFailState("Table creation failed: %s", error);
	}
	LogDebug("Table Creation succesfull");
}

public void DBQuery_Callback(Database db, DBResultSet results, const char[] error, any data){
	if(strlen(error) > 0 || results == INVALID_HANDLE){
		LogDebug("Database Query failed: %s. Unloading ...", error);
		SetFailState("DB Query failed: %s", error);
	}
	LogDebug("Database Query succesfull.");
}

public void DBLoadInfos_Callback(Database db, DBResultSet results, const char[] error, any data){
	if(strlen(error) > 0 || results == INVALID_HANDLE){
		LogDebug("Load Info failed: %s. Unloading ...", error);
		SetFailState("DB LoadInfos failed: %s", error);
	}
	
	DataPack p_pPlayerInfo = view_as<DataPack>(data);
	
	p_pPlayerInfo.Reset();
	
	int iClient = p_pPlayerInfo.ReadCell();
	
	if(!IsClientValid(iClient))
		return;
	
	LogDebug("Found Client ID: %i", iClient);
	char sPlayerID[21];
	p_pPlayerInfo.ReadString(sPlayerID, sizeof(sPlayerID));
	
	char sPlayerName[64];
	GetClientName(iClient, sPlayerName, sizeof(sPlayerName));
	
	int iRows = results.RowCount;
	LogDebug("Found %i Rows for client: %i", iRows, iClient);
	if(!iRows){
		LogDebug("Saving Playername: %s SteamID: %s AdminName:  AdminID:  Timestamp: 0", sPlayerName, sPlayerID);
		strcopy(g_ePlayerInfos[iClient][PlayerName], 64, sPlayerName );
		strcopy(g_ePlayerInfos[iClient][PlayerID], 21, sPlayerID );
		strcopy(g_ePlayerInfos[iClient][AdminName], 64, "" );
		strcopy(g_ePlayerInfos[iClient][AdminID], 21, "" );
		g_ePlayerInfos[iClient][Timestamp] = 0;
	}else if(iRows == 1){
		results.FetchRow();
		char sAdminName[64];
		char sAdminID[21];
		int iTimestamp = results.FetchInt(4);
		LogDebug("Writing Timestamp: %i", iTimestamp);
		results.FetchString(3, sAdminName, sizeof(sAdminName));
		results.FetchString(2, sAdminID, sizeof(sAdminID));
		LogDebug("Writing AdminName: %s", sAdminName);
		LogDebug("Writing AdminID: %s", sAdminID);
		LogDebug("Saving Playername: %s, SteamID: %s, AdminName: %s, AdminID: %s, Timestamp: %i", sPlayerName, sPlayerID, sAdminID, sAdminName, iTimestamp);
		strcopy(g_ePlayerInfos[iClient][PlayerName], 64, sPlayerName);
		strcopy(g_ePlayerInfos[iClient][PlayerID], 21, sPlayerID);
		strcopy(g_ePlayerInfos[iClient][AdminName], 64, sAdminName);
		strcopy(g_ePlayerInfos[iClient][AdminID], 21, sAdminID);
		g_ePlayerInfos[iClient][Timestamp] = iTimestamp;
	}else{
		LogDebug("Multiple Player ID's Found. Whoops. Unloading ...");
		SetFailState("Found multiple PlayerID's. Something went horrible wrong :O");
	}
}

public int Native_IsClientVerified(Handle plugin, int numParams){
	int client = GetNativeCell(1);
	
	if (IsClientValid(client))
		return IsVerified(client);
		
	return 0;
}