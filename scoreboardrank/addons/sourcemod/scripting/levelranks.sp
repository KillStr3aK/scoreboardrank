#include <sourcemod>
#include <clientprefs>
#include <multicolors>
#include <sdkhooks>
#include <nexd>

#define PLUGIN_NEV	"Scoreboard Custom Levels"
#define PLUGIN_LERIAS	"(3_9)"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0"
#define PLUGIN_URL	"https://github.com/KillStr3aK"
#define MAX_RANKS 128
#pragma tabsize 0

int m_iOffset = -1;
int m_iRank[MAXPLAYERS+1];

char m_cFilePath[PLATFORM_MAX_PATH];
char m_cPrefix[128];

Handle m_hLevelCookie = INVALID_HANDLE;
ConVar g_hSaveClients;
ConVar g_hChatPrefix;

enum struct LevelRanks
{
	char MenuName[32];
	int Flag;
	int LevelIndex;

	bool EquipRank(int client)
	{
		if(IsValidClient(client))
		{
			if(g_hSaveClients.BoolValue)
			{
				SetClientCookie(client, m_hLevelCookie, IntToStr(this.LevelIndex));	
			}

			m_iRank[client] = this.LevelIndex;
			return true;
		}

		return false;
	}

	char GetRankName()
	{
		return this.MenuName;
	}

	void SetRankName(const char newname[sizeof(LevelRanks::MenuName)])
	{
		this.MenuName = newname;
	}

	int GetRankIndex()
	{
		return this.LevelIndex;
	}

	void SetRankIndex(int newindex)
	{
		this.LevelIndex = newindex;
	}

	int GetRankFlag()
	{
		return this.Flag;
	}

	void SetRankFlag(int newflag)
	{
		this.Flag = newflag;
	}
}

LevelRanks g_eRank[MAX_RANKS];
int g_iLevelRanks = 0;

public Plugin myinfo = 
{
	name = PLUGIN_NEV,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_LERIAS,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ScoreboardCustomRanks");
	CreateNative("SCR_GetRank", Native_GetRank);
	
	return APLRes_Success;
}

public Native_GetRank(Handle plugin, int params)
{
	return m_iRank[GetNativeCell(1)];
}

public void OnPluginStart()
{
	m_iOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking")
	BuildPath(Path_SM, m_cFilePath, sizeof(m_cFilePath), "configs/level_ranks.cfg");

	RegConsoleCmd("sm_ranks", Command_LevelRanks);

	m_hLevelCookie = RegClientCookie("levelrank_index", "Image index for the level", CookieAccess_Private);
	g_hSaveClients = CreateConVar("level_ranks_save", "1", "Save player preferences?");
	g_hChatPrefix = CreateConVar("level_ranks_chat_prefix", "{default}[{red}Level-Ranks{default}]", "Chat prefix in messages");

	for (int i = MaxClients; i > 0; --i)
    {
        if (!AreClientCookiesCached(i))
        {
            continue;
        }
        
        OnClientCookiesCached(i);
    }
}

public void OnConfigsExecuted()
{
	g_hChatPrefix.GetString(m_cPrefix, sizeof(m_cPrefix));
}

public void OnClientCookiesCached(int client) 
{
	char Index[8];
	GetClientCookie(client, m_hLevelCookie, Index, sizeof(Index));
	m_iRank[client] = StringToInt(Index);
}

public Action Command_LevelRanks(int client, int args)
{
	if(!IsValidClient(client)) return Plugin_Handled;
	RankMenu(view_as<Jatekos>(client));
    return Plugin_Handled; 
}

public void RankMenu(Jatekos jatekos)
{
	char m_cMenuLine[128];

	Menu menu = CreateMenu(IconList);
	menu.SetTitle("Level Ranks");
	menu.AddItem("clear", "Clear", m_iRank[jatekos.index]!=0?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	for(int i = 1; i <= g_iLevelRanks; ++i)
	{
		if(m_iRank[jatekos.index] == g_eRank[i].GetRankIndex()) {
			Format(m_cMenuLine, sizeof(m_cMenuLine), "%s [ EQUIPPED ]", g_eRank[i].GetRankName());
			menu.AddItem(IntToStr(i), m_cMenuLine, ITEMDRAW_DISABLED);
		} else {
			menu.AddItem(IntToStr(i), g_eRank[i].GetRankName(), (g_eRank[i].GetRankFlag()!=-1)?(CheckCommandAccess(jatekos.index, "", g_eRank[i].GetRankFlag())?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED):ITEMDRAW_DEFAULT);
		}
	}

	menu.Display(jatekos.index, MENU_TIME_FOREVER);
}

public int IconList(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		if(StrEqual(info, "clear")) {
			m_iRank[client] = 0;
			CPrintToChat(client, "%s You've cleared your rank", m_cPrefix);
		} else {
			if(g_eRank[StringToInt(info)].EquipRank(client))
			{
				CPrintToChat(client, "%s You've equipped the {green}%s {default}rank!", m_cPrefix, g_eRank[StringToInt(info)].GetRankName());
			} else {
				CPrintToChat(client, "%s {red}Failed to equip the rank", m_cPrefix);
			}
		}

		RankMenu(Jatekos(client));
	} else if(mAction == MenuAction_End) delete menu;
}

public void LevelRanksReset() 
{ 
	g_iLevelRanks = 0;
}

public void OnMapStart()
{
	LevelRanksReset();
	char sBuffer[PLATFORM_MAX_PATH];

	SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost);

	KeyValues kv = CreateKeyValues("LevelRanks");
    FileToKeyValues(kv, m_cFilePath);
    
    if(!KvGotoFirstSubKey(kv)) return;

	char sMenu[sizeof(LevelRanks::MenuName)];
    do
	{
		g_iLevelRanks++;
        KvGetString(kv, "name", sMenu, sizeof(sMenu));
		g_eRank[g_iLevelRanks].SetRankName(sMenu);
		g_eRank[g_iLevelRanks].SetRankFlag(KvGetNum(kv, "flag"));
        g_eRank[g_iLevelRanks].SetRankIndex(KvGetNum(kv, "index"));
    } while (KvGotoNextKey(kv));
    kv.Close();

	if(g_iLevelRanks > 0)
	{
		for(int i = 1; i <= g_iLevelRanks; ++i)
		{
			if(g_eRank[i].GetRankIndex() <= 18) continue;
			FormatEx(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/skillgroups/skillgroup%i.svg", g_eRank[i].GetRankIndex());
			AddFileToDownloadsTable(sBuffer);
		}
	}
}

public void OnThinkPost(int ent)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i)) SetEntData(ent, FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking")+(i*4), m_iRank[i]);
	}
}

public void OnPlayerRunCmdPost(int iClient, int iButtons)
{
	static int iOldButtons[MAXPLAYERS+1];

	if(iButtons & IN_SCORE && !(iOldButtons[iClient] & IN_SCORE))
	{
		StartMessageOne("ServerRankRevealAll", iClient, USERMSG_BLOCKHOOKS);
		EndMessage();
	}

	iOldButtons[iClient] = iButtons;
}