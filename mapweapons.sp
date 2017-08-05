#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#pragma newdecls required

#define MAX_WEAPONS 400

Handle g_hSpawnTimer;
Handle g_hDataBase;
Handle g_aSpawnList;
Handle g_aWeaponList[5];
Handle g_aWeaponSlot;
Handle g_aWeaponMDLs;

char g_szMap[128];

float g_fPosition[MAX_WEAPONS][3];
int g_iWeaponType[MAX_WEAPONS];
int g_iWeaponCount;
int g_iLastType;
int g_iLeftCounts;

public Plugin myinfo = 
{
    name        = "Map Weapons",
    author      = "Kyle",
    description = "weapon for each map. inc dbi",
    version     = "1.1a",
    url         = "http://steamcommunity.com/id/_xQy_/"
}

public void OnPluginStart()
{
    InitWeaponList();
    InitDatabase();
    RegAdminCmd("sm_mapweapons", Command_WeaponMenu, ADMFLAG_BAN);
    HookEvent("round_start",     Event_RoundStart,   EventHookMode_Post);
    HookEvent("player_use",      Event_PlayerUsed,   EventHookMode_Post);
}

public void OnMapStart()
{
    g_iWeaponCount = 0;
    GetCurrentMap(g_szMap, 256);
    QueryDataFromDatabase();
}

public void QueryDataFromDatabase()
{
    if(g_hDataBase == INVALID_HANDLE)
        return;

    char m_sQuery[255];
    Format(m_sQuery, 255, "SELECT `weapon`,`x`,`y`,`z` FROM `map_weapon` WHERE `map` = '%s'", g_szMap);
    SQL_TQuery(g_hDataBase, SQLCallback_FetchWeapon, m_sQuery);
}

public void SQLCallback_FetchWeapon(Handle owner, Handle hndl, const char[] error, any unused)
{
    if(hndl == INVALID_HANDLE)
    {
        LogError("Error happened: %s", error);
        return;
    }

    if(!SQL_GetRowCount(hndl))
        return;

    while(SQL_FetchRow(hndl))
    {
        g_iWeaponType[g_iWeaponCount] = SQL_FetchInt(hndl, 0);
        g_fPosition[g_iWeaponCount][0] = SQL_FetchFloat(hndl, 1);
        g_fPosition[g_iWeaponCount][1] = SQL_FetchFloat(hndl, 2);
        g_fPosition[g_iWeaponCount][2] = SQL_FetchFloat(hndl, 3);

        if(++g_iWeaponCount >= MAX_WEAPONS)
            break;
    }
}

public void SQLCallback_UpdateWeapon(Handle owner, Handle hndl, const char[] error, int client)
{
    if(hndl == INVALID_HANDLE)
    {
        LogError("Error happened: %s", error);
        PrintToChat(client, "[\x0EMap Weapons\x01]  同步到数据库失败");
        return;
    }

    PrintToChat(client, "[\x0EMap Weapons\x01]  Update to database successful[%d/%d]", g_iWeaponCount, MAX_WEAPONS);
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    if(!g_iWeaponCount)
        return;

    ResetSpawnListArray();
    if(g_hSpawnTimer != INVALID_HANDLE)
        KillTimer(g_hSpawnTimer);
    g_hSpawnTimer = CreateTimer(0.5, Timer_SpawnWeapon);
    //**   CHANGE THIS SET SPAWN WEAPON COUNTS   **//
    g_iLeftCounts = GetClientCount(true)*3;  // by default, in-game clients * 3
    if(g_iLeftCounts >= g_iWeaponCount)
        g_iLeftCounts = g_iWeaponCount-1;
}

void ResetSpawnListArray()
{
    ClearArray(g_aSpawnList);
    for(int i = 0; i < g_iWeaponCount; ++i)
        PushArrayCell(g_aSpawnList, i);
}

int GetRandomInArray()
{
    int size = GetArraySize(g_aSpawnList);
    if(size < 1)
        return -1;
    int index = GetRandomInt(0, size-1);
    int result = GetArrayCell(g_aSpawnList, index);
    RemoveFromArray(g_aSpawnList, index);
    return result;
}

public Action Timer_SpawnWeapon(Handle timer)
{
    int index;
    while(g_iLeftCounts--)
    {
        if((index = GetRandomInArray()) == -1)
            break;

        char classname[32];
        if(!GetRandomClassByType(g_iWeaponType[index], classname, 32))
            continue;

        CreateWeaponAtPosition(g_fPosition[index], classname);
    }
    
    g_hSpawnTimer = INVALID_HANDLE;
}

bool GetRandomClassByType(int type, char[] buffer, int maxLen)
{
    if(!(0 <= type <= 4))
        return false;

    int size = GetArraySize(g_aWeaponList[type]);

    if(size < 1)
        return false;

    return (GetArrayString(g_aWeaponList[type], GetRandomInt(0, size-1), buffer, maxLen) > 7);
}

bool CreateWeaponAtPosition(const float fPos[3], const char[] classname)
{
    int iEntity = CreateEntityByName("prop_physics_override");
    
    if(iEntity == -1)
        return false;

    char targetname[32];
    Format(targetname, 32, "%d_tttwpn_%s", iEntity, classname);

    DispatchKeyValue(iEntity, "targetname", targetname);
    DispatchKeyValue(iEntity, "spawnflag", "256");
    DispatchKeyValue(iEntity, "disablereceiveshadows", "1");
    DispatchKeyValue(iEntity, "disableshadows", "1");
    
    char model[128];
    GetModelByClassnamee(classname, model, 128);
    SetEntityModel(iEntity, model);

    DispatchSpawn(iEntity);
    ActivateEntity(iEntity);
    
    SetEntProp(iEntity, Prop_Data, "m_takedamage", 0, 1);
    SetEntProp(iEntity, Prop_Data, "m_spawnflags", 256);
    
    AcceptEntityInput(iEntity, "Wake");
    AcceptEntityInput(iEntity, "EnableMotion");

    TeleportEntity(iEntity, fPos, NULL_VECTOR, NULL_VECTOR);

    SDKHook(iEntity, SDKHook_TouchPost, TouchWeaponPost);

    return true;
}

public void TouchWeaponPost(int entity, int other)
{
    if(!IsValidClient(other) || entity < MaxClients || !IsValidEdict(entity))
        return;

    OnClientWeapon(other, entity, false);
}

public void Event_PlayerUsed(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int entity = GetEventInt(event, "entity");

    if(!IsValidClient(client) || entity < MaxClients || !IsValidEdict(entity))
        return;

    OnClientWeapon(client, entity, true);
}

void OnClientWeapon(int client, int entity, bool drop)
{
    char targetname[32];
    GetEntPropString(entity, Prop_Data, "m_iName", targetname, 32);

    if(StrContains(targetname, "_tttwpn_", false) == -1)
        return;

    char szEnt[16];
    Format(szEnt, 16, "%d_tttwpn_", entity);
    ReplaceString(targetname, 32, szEnt, "", false);

    int slot = FindSlotByClass(targetname);
    if(slot == -1)
        return;

    int weapon = GetPlayerWeaponSlot(client, slot);
    if(IsValidEdict(weapon))
    {
        if(!drop)
            return;

        CS_DropWeapon(client, weapon, true, true);
    }

    GivePlayerItem(client, targetname);
    SDKUnhook(entity, SDKHook_TouchPost, TouchWeaponPost);
    AcceptEntityInput(entity, "Kill");
}

int FindSlotByClass(const char[] classname)
{
    int slot;
    if(!GetTrieValue(g_aWeaponSlot, classname, slot))
        return -1;
    
    return slot;
}

void GetModelByClassnamee(const char[] classname, char[] model, int maxLen)
{
    if(!GetTrieString(g_aWeaponMDLs, classname, model, maxLen))
        strcopy(model, maxLen, "models/weapons/w_rif_ak47_dropped.mdl");
}

public Action Command_WeaponMenu(int client, int args)
{
    Handle menu = CreateMenu(MenuHandler_MainMenu);
    SetMenuTitle(menu, "Map Weapons - Main Menu");

    AddMenuItem(menu, "pist", "Pistol");
    AddMenuItem(menu, "smgs", "SMGs");
    AddMenuItem(menu, "shot", "Heavy");
    AddMenuItem(menu, "rifl", "Rifles");

    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 8);
}

public int MenuHandler_MainMenu(Handle menu, MenuAction action, int client, int itemNum)
{
    if(action == MenuAction_Select) 
    {
        char info[32];
        GetMenuItem(menu, itemNum, info, 32);

        if(StrEqual(info, "pist", false))
            ShowPistolMenu(client);
        
        if(StrEqual(info, "smgs", false))
            ShowSMGMenu(client);
        
        if(StrEqual(info, "shot", false))
            ShowShotgunMenu(client);
        
        if(StrEqual(info, "rifl", false))
            ShowRifleMenu(client);
    }
    else if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

void ShowPistolMenu(int client)
{
    Handle menu = CreateMenu(MenuHandler_Select);
    SetMenuTitle(menu, "[Map Weapons]  Pistols"); 
  
    AddMenuItem(menu, "weapon_hkp2000",         "P2000");
    AddMenuItem(menu, "weapon_glock",           "Glock");
    AddMenuItem(menu, "weapon_usp_silencer",    "USP");
    AddMenuItem(menu, "weapon_p250",            "P250");
    AddMenuItem(menu, "weapon_fiveseven",       "FiveSeven");
    AddMenuItem(menu, "weapon_deagle",          "Deagle");
    AddMenuItem(menu, "weapon_tec9",            "Tec9");
    AddMenuItem(menu, "weapon_elite",           "Elite");
    AddMenuItem(menu, "weapon_cz75a",           "CZ75");
    AddMenuItem(menu, "weapon_revolver",        "Revolver");
    
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 15);
    
    g_iLastType = 1;
}

void ShowSMGMenu(int client)
{
    Handle menu = CreateMenu(MenuHandler_Select);
    SetMenuTitle(menu, "[Map Weapons]  SMGs"); 
  
    AddMenuItem(menu, "weapon_mac10",   "MAC10");
    AddMenuItem(menu, "weapon_mp9",     "MP9");
    AddMenuItem(menu, "weapon_mp7",     "MP7");
    AddMenuItem(menu, "weapon_ump45",   "UMP45");
    AddMenuItem(menu, "weapon_bizon",   "PPBIZON");
    AddMenuItem(menu, "weapon_p90",     "P90");
    
    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 15);
    
    g_iLastType = 2;
}

void ShowShotgunMenu(int client)
{
    Handle menu = CreateMenu(MenuHandler_Select);
    SetMenuTitle(menu, "[Map Weapons]  Heavys"); 
  
    AddMenuItem(menu, "weapon_nova",        "NOVA");
    AddMenuItem(menu, "weapon_xm1014",      "XM1014");
    AddMenuItem(menu, "weapon_sawedoff",    "SwadeOff");
    AddMenuItem(menu, "weapon_mag7",        "MAG-7");
    AddMenuItem(menu, "weapon_m249",        "M249");
    AddMenuItem(menu, "weapon_negev",       "Negev");

    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 15);
    
    g_iLastType = 3;
}
 
void ShowRifleMenu(int client)
{
    Handle menu = CreateMenu(MenuHandler_Select);
    SetMenuTitle(menu, "Map Weapons - Rifles"); 
  
    AddMenuItem(menu, "weapon_famas",           "Famas");
    AddMenuItem(menu, "weapon_galilar",         "Galilar");
    AddMenuItem(menu, "weapon_m4a1",            "M4A4");
    AddMenuItem(menu, "weapon_ak47",            "AK47");
    AddMenuItem(menu, "weapon_m4a1_silencer",   "M4A1");
    AddMenuItem(menu, "weapon_sg556",           "SG556");
    AddMenuItem(menu, "weapon_aug",             "AUG");
    AddMenuItem(menu, "weapon_ssg08",           "SSG08");
    AddMenuItem(menu, "weapon_awp",             "AWP");
    AddMenuItem(menu, "weapon_g3sg1",           "G3SG1");
    AddMenuItem(menu, "weapon_scar20",          "SCAR20");

    SetMenuExitButton(menu, true);
    DisplayMenu(menu, client, 15);

    g_iLastType = 4;
}

public int MenuHandler_Select(Handle menu, MenuAction action, int client, int itemNum)
{
    if(action == MenuAction_Select) 
    {
        if(g_iWeaponCount >= MAX_WEAPONS)
            return;

        char info[32];
        GetMenuItem(menu, itemNum, info, 32);
        PrefAddWeapon(client, info);
    }
    else if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

void PrefAddWeapon(int client, const char[] info)
{
    float cleyepos[3], cleyeangle[3], resultposition[3], normalvector[3];
    GetClientEyePosition(client, cleyepos); 
    GetClientEyeAngles(client, cleyeangle);

    Handle traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, tracerayfilternoplayer, client);

    if(TR_DidHit(traceresulthandle))
    {
        TR_GetEndPosition(resultposition, traceresulthandle);
        TR_GetPlaneNormal(traceresulthandle, normalvector);

        NormalizeVector(normalvector, normalvector);
        ScaleVector(normalvector, 5.0);
        AddVectors(resultposition, normalvector, resultposition);

        g_iWeaponType[g_iWeaponCount] = FindWeaponTypeByClass(info);
        g_fPosition[g_iWeaponCount][0] = resultposition[0];
        g_fPosition[g_iWeaponCount][1] = resultposition[1];
        g_fPosition[g_iWeaponCount][2] = resultposition[2];

        CreateWeaponAtPosition(g_fPosition[g_iWeaponCount], info);

        PrintToChatAll("[\x0EMap Weapons\x01]  \x08Weapon Spawned[\x04%s\x01]", info);

        switch(g_iLastType)
        {
            case 1: ShowPistolMenu(client);
            case 2: ShowSMGMenu(client);
            case 3: ShowShotgunMenu(client);
            case 4: ShowRifleMenu(client);
        }

        g_iWeaponCount++;
        UpdateWeaponToDataBase(g_iWeaponType[g_iWeaponCount-1], g_fPosition[g_iWeaponCount-1], client);
    }
}

int FindWeaponTypeByClass(const char[] info)
{
    char classname[32];
    for(int i = 1; i <= 4; ++i)
    {
        int size = GetArraySize(g_aWeaponList[i]);
        for(int j = 0; j < size; ++j)
        {
            GetArrayString(g_aWeaponList[i], j, classname, 32);
            if(StrEqual(info, classname))
                return i;
        }
    }
    return 0;
}

public bool tracerayfilternoplayer(int entity, int mask, any data)
{    
    return (!IsValidClient(entity)) ? true : false;
}

void UpdateWeaponToDataBase(int weapon, float loc[3], int client)
{
    char m_sQuery[256];
    Format(m_sQuery, 256, "INSERT INTO `map_weapon` (`map`, `weapon`, `x`, `y`, `z`) VALUES ('%s', '%d', '%f', '%f', '%f')", g_szMap, weapon, loc[0], loc[1], loc[2]);
    SQL_TQuery(g_hDataBase, SQLCallback_UpdateWeapon, m_sQuery, client);
}

void InitDatabase()
{
    char m_szErr[128];
    g_hDataBase = SQL_Connect("mapweapons", false, m_szErr, 128);
    if(g_hDataBase == INVALID_HANDLE)
        SetFailState("[Map Weapons] Unable to connect to database (%s)",m_szErr);
}

void InitWeaponList()
{
    g_aSpawnList = CreateArray();

    g_aWeaponList[0] = CreateArray(ByteCountToCells(32));
    g_aWeaponList[1] = CreateArray(ByteCountToCells(32));
    g_aWeaponList[2] = CreateArray(ByteCountToCells(32));
    g_aWeaponList[3] = CreateArray(ByteCountToCells(32));
    g_aWeaponList[4] = CreateArray(ByteCountToCells(32));

    // Pistol
    PushArrayString(g_aWeaponList[0],    "weapon_cz75a");
    PushArrayString(g_aWeaponList[0],    "weapon_p250");
    PushArrayString(g_aWeaponList[0],    "weapon_deagle");
    PushArrayString(g_aWeaponList[0],    "weapon_revolver");
    PushArrayString(g_aWeaponList[0],    "weapon_elite");
    PushArrayString(g_aWeaponList[0],    "weapon_glock");
    PushArrayString(g_aWeaponList[0],    "weapon_tec9");
    PushArrayString(g_aWeaponList[0],    "weapon_fiveseven");
    PushArrayString(g_aWeaponList[0],    "weapon_hkp2000");
    PushArrayString(g_aWeaponList[0],    "weapon_usp_silencer");
    PushArrayString(g_aWeaponList[1],    "weapon_cz75a");
    PushArrayString(g_aWeaponList[1],    "weapon_p250");
    PushArrayString(g_aWeaponList[1],    "weapon_deagle");
    PushArrayString(g_aWeaponList[1],    "weapon_revolver");
    PushArrayString(g_aWeaponList[1],    "weapon_elite");
    PushArrayString(g_aWeaponList[1],    "weapon_glock");
    PushArrayString(g_aWeaponList[1],    "weapon_tec9");
    PushArrayString(g_aWeaponList[1],    "weapon_fiveseven");
    PushArrayString(g_aWeaponList[1],    "weapon_hkp2000");
    PushArrayString(g_aWeaponList[1],    "weapon_usp_silencer");

    // Heavy
    PushArrayString(g_aWeaponList[0],    "weapon_nova");
    PushArrayString(g_aWeaponList[0],    "weapon_xm1014");
    PushArrayString(g_aWeaponList[0],    "weapon_m249");
    PushArrayString(g_aWeaponList[0],    "weapon_negev");
    PushArrayString(g_aWeaponList[0],    "weapon_mag7");
    PushArrayString(g_aWeaponList[0],    "weapon_sawedoff");
    PushArrayString(g_aWeaponList[2],    "weapon_nova");
    PushArrayString(g_aWeaponList[2],    "weapon_xm1014");
    PushArrayString(g_aWeaponList[2],    "weapon_m249");
    PushArrayString(g_aWeaponList[2],    "weapon_negev");
    PushArrayString(g_aWeaponList[2],    "weapon_mag7");
    PushArrayString(g_aWeaponList[2],    "weapon_sawedoff");

    // SMG
    PushArrayString(g_aWeaponList[0],    "weapon_ump45");
    PushArrayString(g_aWeaponList[0],    "weapon_p90");
    PushArrayString(g_aWeaponList[0],    "weapon_bizon");
    PushArrayString(g_aWeaponList[0],    "weapon_mp7");
    PushArrayString(g_aWeaponList[0],    "weapon_mp9");
    PushArrayString(g_aWeaponList[0],    "weapon_mac10");
    PushArrayString(g_aWeaponList[3],    "weapon_ump45");
    PushArrayString(g_aWeaponList[3],    "weapon_p90");
    PushArrayString(g_aWeaponList[3],    "weapon_bizon");
    PushArrayString(g_aWeaponList[3],    "weapon_mp7");
    PushArrayString(g_aWeaponList[3],    "weapon_mp9");
    PushArrayString(g_aWeaponList[3],    "weapon_mac10");

    // Rifle
    PushArrayString(g_aWeaponList[0],    "weapon_ssg08");
    PushArrayString(g_aWeaponList[0],    "weapon_awp");
    PushArrayString(g_aWeaponList[0],    "weapon_galilar");
    PushArrayString(g_aWeaponList[0],    "weapon_ak47");
    PushArrayString(g_aWeaponList[0],    "weapon_sg556");
    PushArrayString(g_aWeaponList[0],    "weapon_g3sg1");
    PushArrayString(g_aWeaponList[0],    "weapon_famas");
    PushArrayString(g_aWeaponList[0],    "weapon_m4a1");
    PushArrayString(g_aWeaponList[0],    "weapon_m4a1_silencer");
    PushArrayString(g_aWeaponList[0],    "weapon_aug");
    PushArrayString(g_aWeaponList[0],    "weapon_scar20");
    PushArrayString(g_aWeaponList[4],    "weapon_ssg08");
    PushArrayString(g_aWeaponList[4],    "weapon_awp");
    PushArrayString(g_aWeaponList[4],    "weapon_galilar");
    PushArrayString(g_aWeaponList[4],    "weapon_ak47");
    PushArrayString(g_aWeaponList[4],    "weapon_sg556");
    PushArrayString(g_aWeaponList[4],    "weapon_g3sg1");
    PushArrayString(g_aWeaponList[4],    "weapon_famas");
    PushArrayString(g_aWeaponList[4],    "weapon_m4a1");
    PushArrayString(g_aWeaponList[4],    "weapon_m4a1_silencer");
    PushArrayString(g_aWeaponList[4],    "weapon_aug");
    PushArrayString(g_aWeaponList[4],    "weapon_scar20");
    
    
    // Adt slot
    g_aWeaponSlot = CreateTrie();
    SetTrieValue(g_aWeaponSlot, "weapon_usp_silencer",  1);
    SetTrieValue(g_aWeaponSlot, "weapon_cz75a",         1);
    SetTrieValue(g_aWeaponSlot, "weapon_deagle",        1);
    SetTrieValue(g_aWeaponSlot, "weapon_elite",         1);
    SetTrieValue(g_aWeaponSlot, "weapon_fiveseven",     1);
    SetTrieValue(g_aWeaponSlot, "weapon_glock",         1);
    SetTrieValue(g_aWeaponSlot, "weapon_hkp2000",       1);
    SetTrieValue(g_aWeaponSlot, "weapon_p250",          1);
    SetTrieValue(g_aWeaponSlot, "weapon_revolver",      1);
    SetTrieValue(g_aWeaponSlot, "weapon_tec9",          1);
    SetTrieValue(g_aWeaponSlot, "weapon_ak47",          0);
    SetTrieValue(g_aWeaponSlot, "weapon_aug",           0);
    SetTrieValue(g_aWeaponSlot, "weapon_famas",         0);
    SetTrieValue(g_aWeaponSlot, "weapon_galilar",       0);
    SetTrieValue(g_aWeaponSlot, "weapon_m4a1",          0);
    SetTrieValue(g_aWeaponSlot, "weapon_m4a1_silencer", 0);
    SetTrieValue(g_aWeaponSlot, "weapon_sg556",         0);
    SetTrieValue(g_aWeaponSlot, "weapon_mag7",          0);
    SetTrieValue(g_aWeaponSlot, "weapon_nova",          0);
    SetTrieValue(g_aWeaponSlot, "weapon_sawedoff",      0);
    SetTrieValue(g_aWeaponSlot, "weapon_xm1014",        0);
    SetTrieValue(g_aWeaponSlot, "weapon_bizon",         0);
    SetTrieValue(g_aWeaponSlot, "weapon_mac10",         0);
    SetTrieValue(g_aWeaponSlot, "weapon_mp7",           0);
    SetTrieValue(g_aWeaponSlot, "weapon_mp9",           0);
    SetTrieValue(g_aWeaponSlot, "weapon_p90",           0);
    SetTrieValue(g_aWeaponSlot, "weapon_ump45",         0);
    SetTrieValue(g_aWeaponSlot, "weapon_awp",           0);
    SetTrieValue(g_aWeaponSlot, "weapon_g3sg1",         0);
    SetTrieValue(g_aWeaponSlot, "weapon_scar20",        0);
    SetTrieValue(g_aWeaponSlot, "weapon_ssg08",         0);
    SetTrieValue(g_aWeaponSlot, "weapon_m249",          0);
    SetTrieValue(g_aWeaponSlot, "weapon_negev",         0);
    
    
    // Adt model
    g_aWeaponMDLs = CreateTrie();
    SetTrieString(g_aWeaponMDLs, "weapon_m249",          "models/weapons/w_mach_m249_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_negev",         "models/weapons/w_mach_negev_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_usp_silencer",  "models/weapons/w_pist_223_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_cz75a",         "models/weapons/w_pist_cz_75_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_deagle",        "models/weapons/w_pist_deagle_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_elite",         "models/weapons/w_pist_elite_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_fiveseven",     "models/weapons/w_pist_fiveseven_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_glock",         "models/weapons/w_pist_glock18_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_hkp2000",       "models/weapons/w_pist_hkp2000_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_p250",          "models/weapons/w_pist_p250_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_revolver",      "models/weapons/w_pist_revolver_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_tec9",          "models/weapons/w_pist_tec9_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_ak47",          "models/weapons/w_rif_ak47_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_aug",           "models/weapons/w_rif_aug_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_famas",         "models/weapons/w_rif_famas_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_galilar",       "models/weapons/w_rif_galilar_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_m4a1",          "models/weapons/w_rif_m4a1_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_m4a1_silencer", "models/weapons/w_rif_m4a1_s_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_sg556",         "models/weapons/w_rif_sg556_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_mag7",          "models/weapons/w_shot_mag7_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_nova",          "models/weapons/w_shot_nova_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_sawedoff",      "models/weapons/w_shot_sawedoff_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_xm1014",        "models/weapons/w_shot_xm1014_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_bizon",         "models/weapons/w_smg_bizon_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_mac10",         "models/weapons/w_smg_mac10_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_mp7",           "models/weapons/w_smg_mp7_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_mp9",           "models/weapons/w_smg_mp9_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_p90",           "models/weapons/w_smg_p90_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_ump45",         "models/weapons/w_smg_ump45_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_awp",           "models/weapons/w_snip_awp_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_g3sg1",         "models/weapons/w_snip_g3sg1_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_scar20",        "models/weapons/w_snip_scar20_dropped.mdl");
    SetTrieString(g_aWeaponMDLs, "weapon_ssg08",         "models/weapons/w_snip_ssg08_dropped.mdl");
}

bool IsValidClient(int client)
{
	if(client > MaxClients || client < 1)
		return false;

	if(!IsClientInGame(client))
		return false;
	
	if(IsFakeClient(client))
		return false;

	return true;
}