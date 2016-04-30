#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "good_live"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <logdebug>

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

public Plugin myinfo = 
{
	name = "sm_ttt_verify",
	author = PLUGIN_AUTHOR,
	description = "Allows admins to verify all players",
	version = PLUGIN_VERSION,
	url = ""
};

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

public Action Command_Verify(int p_iClient, int p_iArgs){
	if(!IsClientValid(p_iClient)){
		return Plugin_Handled;
	}
	
	if(p_iArgs == 0){
		ShowUnverified(p_iClient);
		return Plugin_Handled;
	}
	
	int p_iTarget;
	
	if(p_iArgs > 1){
		CPrintToChat(p_iClient, "%t", "Too_Much_Arguments");
	}
	char p_sName[64];
	GetCmdArg(1, p_sName, sizeof(p_sName));
	p_iTarget = FindTarget(p_iClient, p_sName);
	
	if(p_iTarget == -1){
		return Plugin_Handled;
	}
	
	if(IsVerified(p_iTarget)){
		char p_sName2[64];
		GetClientName(p_iTarget, p_sName2, sizeof(p_sName2));
		
		char p_sDate[64];
		FormatTime(p_sDate, sizeof(p_sDate), "%D", g_ePlayerInfos[p_iTarget][Timestamp]);
		CPrintToChat(p_iClient, "%t", "Already_Verified", g_ePlayerInfos[p_iTarget][PlayerName], g_ePlayerInfos[p_iTarget][PlayerID], g_ePlayerInfos[p_iTarget][AdminName], g_ePlayerInfos[p_iTarget][AdminID], p_sDate);
		return Plugin_Handled;
	}
	VerifyPlayer(p_iTarget, p_iClient);
	return Plugin_Handled;
}
/************************
		  Events
*************************/

public void OnClientPostAdminCheck(p_iClient){
	if(!g_bDatabaseConnected)
	    return;
	char p_sTest[64];
	GetClientAuthId(p_iClient, AuthId_Steam2, p_sTest, sizeof(p_sTest));
	LogDebug("Client SteamID: %s", p_sTest);
	LogDebug("Loading Info of the joined player");
	if(!LoadPlayerInfos(p_iClient)){
		LogError("Loading of Playerinfos from the database failed");
	}
}

/************************
		Functions
*************************/

public bool IsClientValid(int p_iClient){
	if(IsClientAuthorized(p_iClient) && IsClientInGame(p_iClient) && !IsClientSourceTV(p_iClient)){
		return true;
	}
	return false;
}

public int LoadPlayerInfos(int p_iClient){
	if(!IsClientValid(p_iClient) || g_hDatabase == INVALID_HANDLE){
		return 0;
	}
	
	char p_sPlayerID[21];
	char p_sQuery[256];
	GetClientAuthId(p_iClient, AuthId_Steam2, p_sPlayerID, sizeof(p_sPlayerID));
	DataPack p_pInfos;
	p_pInfos = CreateDataPack();
	p_pInfos.WriteCell(p_iClient);
	p_pInfos.WriteString(p_sPlayerID);
	
	Format(p_sQuery, sizeof(p_sQuery), "SELECT `playerid`, `playername`, `adminid`, `adminname`, `time` FROM `verify` WHERE `playerid` = '%s'", p_sPlayerID);
	
	g_hDatabase.Query(DBLoadInfos_Callback, p_sQuery, p_pInfos);
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
public void ShowUnverified(int p_iClient)
{
	char p_sName[64];
	int p_iCounter;
	Menu menu = new Menu(Unverified_Menu);
	menu.SetTitle("Unverified Player:");
	menu.ExitButton = true;
	for(int i = 1; i <= MaxClients; i++){
		if(IsClientValid(i) && !IsVerified(i) && !IsFakeClient(i)){
			GetClientName(i, p_sName, sizeof(p_sName));
			menu.AddItem(p_sName, p_sName);
			p_iCounter++;
		}
	}
	if(!p_iCounter){
		CPrintToChat(p_iClient, "%t", "Nobody_Unverified");
		delete menu;
	}else{
		menu.Display(p_iClient, 60);
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
		char p_sName[64];
		menu.GetItem(param2, p_sName, sizeof(p_sName));
		int p_iTarget = FindTarget(param1, p_sName, false);
		VerifyPlayer(p_iTarget, param1);
		ShowUnverified(param1);
	}
}

public bool IsVerified(int p_iClient){
	LogDebug("Timestamp: %i", g_ePlayerInfos[p_iClient][Timestamp]);
	if(g_ePlayerInfos[p_iClient][Timestamp] != 0){
		LogDebug("Returning true");
		return true;
	}
	LogDebug("Returning false");
	return false;
}

public void VerifyPlayer(int p_iPlayer, int p_iAdmin){
		char p_sPlayerName[64];
		char p_sAdminName[64];
		char p_sPlayerID[21];
		char p_sAdminID[21];
		char p_sPlayerNameE[sizeof(p_sPlayerName)*2+1];
		char p_sAdminNameE[sizeof(p_sAdminName)*2+1];
		GetClientAuthId(p_iPlayer, AuthId_Steam2, p_sPlayerID, sizeof(p_sPlayerID));
		GetClientAuthId(p_iAdmin, AuthId_Steam2, p_sAdminID, sizeof(p_sAdminID));
		GetClientName(p_iPlayer, p_sPlayerName, sizeof(p_sPlayerName));
		GetClientName(p_iAdmin, p_sAdminName, sizeof(p_sAdminName));
		g_hDatabase.Escape(p_sPlayerName, p_sPlayerNameE, sizeof(p_sPlayerNameE));
		g_hDatabase.Escape(p_sAdminName, p_sAdminNameE, sizeof(p_sAdminNameE));
		
		
		char p_sQuery[256];
		Format(p_sQuery, sizeof(p_sQuery), "INSERT INTO `verify` (`playerid`, `playername`, `adminid`, `adminname`, `time`) VALUES (\"%s\", \"%s\", \"%s\", \"%s\", %i) ON DUPLICATE KEY UPDATE id=id", p_sPlayerID, p_sPlayerNameE, p_sAdminID, p_sAdminNameE, GetTime());
		g_hDatabase.Query(DBQuery_Callback, p_sQuery);
		
		strcopy(g_ePlayerInfos[p_iPlayer][PlayerName], 64, p_sPlayerName);
		strcopy(g_ePlayerInfos[p_iPlayer][PlayerID], 21, p_sPlayerID);
		strcopy(g_ePlayerInfos[p_iPlayer][AdminName], 64, p_sAdminName);
		strcopy(g_ePlayerInfos[p_iPlayer][AdminID], 21, p_sAdminID);
		g_ePlayerInfos[p_iPlayer][Timestamp] = GetTime();
		CPrintToChat(p_iAdmin, "%t", "Verified", p_sPlayerName);
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
	char p_sQuery[512];
	Format(p_sQuery, sizeof(p_sQuery), "CREATE TABLE IF NOT EXISTS `verify` ( `id` INT NOT NULL AUTO_INCREMENT, `playerid` VARCHAR(21) NOT NULL, `playername` VARCHAR(64) CHARACTER SET utf8mb4 NOT NULL, `adminid` VARCHAR(21) NOT NULL, `adminname` VARCHAR(64) CHARACTER SET utf8mb4 NOT NULL,`time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE (`playerid`))");
	g_hDatabase.Query(DBCreateTable_Callback, p_sQuery);
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
	
	int p_iClient = p_pPlayerInfo.ReadCell();
	
	if(!IsClientValid(p_iClient))
		return;
	
	LogDebug("Found Client ID: %i", p_iClient);
	char p_sPlayerID[21];
	p_pPlayerInfo.ReadString(p_sPlayerID, sizeof(p_sPlayerID));
	
	char p_sPlayerName[64];
	GetClientName(p_iClient, p_sPlayerName, sizeof(p_sPlayerName));
	
	int p_iRows = results.RowCount;
	LogDebug("Found %i Rows for client: %i", p_iRows, p_iClient);
	if(!p_iRows){
		LogDebug("Saving Playername: %s SteamID: %s AdminName:  AdminID:  Timestamp: 0", p_sPlayerName, p_sPlayerID);
		strcopy(g_ePlayerInfos[p_iClient][PlayerName], 64, p_sPlayerName );
		strcopy(g_ePlayerInfos[p_iClient][PlayerID], 21, p_sPlayerID );
		strcopy(g_ePlayerInfos[p_iClient][AdminName], 64, "" );
		strcopy(g_ePlayerInfos[p_iClient][AdminID], 21, "" );
		g_ePlayerInfos[p_iClient][Timestamp] = 0;
	}else if(p_iRows == 1){
		results.FetchRow();
		char p_sAdminName[64];
		char p_sAdminID[21];
		int p_iTimestamp = results.FetchInt(4);
		LogDebug("Writing Timestamp: %i", p_iTimestamp);
		results.FetchString(3, p_sAdminName, sizeof(p_sAdminName));
		results.FetchString(2, p_sAdminID, sizeof(p_sAdminID));
		LogDebug("Writing AdminName: %s", p_sAdminName);
		LogDebug("Writing AdminID: %s", p_sAdminID);
		LogDebug("Saving Playername: %s, SteamID: %s, AdminName: %s, AdminID: %s, Timestamp: %i", p_sPlayerName, p_sPlayerID, p_sAdminID, p_sAdminName, p_iTimestamp);
		strcopy(g_ePlayerInfos[p_iClient][PlayerName], 64, p_sPlayerName);
		strcopy(g_ePlayerInfos[p_iClient][PlayerID], 21, p_sPlayerID);
		strcopy(g_ePlayerInfos[p_iClient][AdminName], 64, p_sAdminName);
		strcopy(g_ePlayerInfos[p_iClient][AdminID], 21, p_sAdminID);
		g_ePlayerInfos[p_iClient][Timestamp] = p_iTimestamp;
	}else{
		LogDebug("Multiple Player ID's Found. Whoops. Unloading ...");
		SetFailState("Found multiple PlayerID's. Something went horrible wrong :O");
	}
}