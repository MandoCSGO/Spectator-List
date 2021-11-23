
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define SPECMODE_NONE 				0
#define SPECMODE_FIRSTPERSON 		4
#define SPECMODE_3RDPERSON 			5
#define SPECMODE_FREELOOK	 		6

#define UPDATE_INTERVAL 0.1
#define PLUGIN_VERSION "1.1.3"

Handle HudHintTimers[MAXPLAYERS+1];
Handle sm_speclist_enabled;
Handle sm_speclist_allowed;
Handle sm_speclist_x;
Handle sm_speclist_y;
Handle sm_speclist_color_red;
Handle sm_speclist_color_green;
Handle sm_speclist_color_blue;
Handle sm_speclist_color_alpha;
float speclist_x;
float speclist_y;
int speclist_color_red;
int speclist_color_green;
int speclist_color_blue;
int speclist_color_alpha;
bool g_Enabled;

public Plugin myinfo =
{
	name = "Spectator List",
	author = "GoD-Tony , hud_text edit by Mando",
	description = "View who is spectating you in CS:GO",
	version = PLUGIN_VERSION,
	url = "https://github.com/MandoCSGO"
}
 
public void OnPluginStart()
{
	sm_speclist_enabled = CreateConVar("sm_speclist_enabled","1","Enables the spectator list for all players by default.");
	sm_speclist_allowed = CreateConVar("sm_speclist_allowed","1","Allows players to enable spectator list manually when disabled by default.");
	sm_speclist_x = CreateConVar("sm_speclist_x","0.03","X-coordinate value for the spectator list.");
	sm_speclist_y = CreateConVar("sm_speclist_y","0.2","Y-coordinate value for the spectator list.");
	sm_speclist_color_red = CreateConVar("sm_speclist_color_red","255","Red color value for the spectator list.");
	sm_speclist_color_green = CreateConVar("sm_speclist_color_green","255","Green color value for the spectator list.");
	sm_speclist_color_blue = CreateConVar("sm_speclist_color_blue","0","Blue color value for the spectator list.");
	sm_speclist_color_alpha = CreateConVar("sm_speclist_color_alpha","150","Alpha value for the spectator list.");
	
	RegConsoleCmd("sm_speclist", Command_SpecList);
	
	HookConVarChange(sm_speclist_enabled, OnConVarChange);
	
	g_Enabled = GetConVarBool(sm_speclist_enabled);
	speclist_x = GetConVarFloat(sm_speclist_x);
	speclist_y = GetConVarFloat(sm_speclist_y);
	speclist_color_red = GetConVarInt(sm_speclist_color_red);
	speclist_color_green = GetConVarInt(sm_speclist_color_green);
	speclist_color_blue = GetConVarInt(sm_speclist_color_blue);
	speclist_color_alpha = GetConVarInt(sm_speclist_color_alpha);
	
	AutoExecConfig(true, "plugin.speclist");
}

public void OnConVarChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	if (hCvar == sm_speclist_enabled)
	{
		g_Enabled = GetConVarBool(sm_speclist_enabled);
		
		if (g_Enabled)
		{
			// Enable timers on all players in game.
			for(int i = 1; i <= MaxClients; i++) 
			{
				if (!IsClientInGame(i))
					continue;
				
				CreateHudHintTimer(i);
			}
		}
		else
		{
			// Kill all of the active timers.
			for(int i = 1; i <= MaxClients; i++) 
				KillHudHintTimer(i);
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (g_Enabled)
		CreateHudHintTimer(client);
}

public void OnClientDisconnect(int client)
{
	if(IsClientInGame(client))
		KillHudHintTimer(client);
}

// Using 'sm_speclist' to toggle the spectator list per player.
public Action Command_SpecList(int client, int args)
{
	if (HudHintTimers[client] != INVALID_HANDLE)
	{
		KillHudHintTimer(client);
		ReplyToCommand(client, "[SM] Spectator list disabled.");
	}
	else if (g_Enabled || GetConVarBool(sm_speclist_allowed))
	{
		CreateHudHintTimer(client);
		ReplyToCommand(client, "[SM] Spectator list enabled.");
	}
	
	return Plugin_Handled;
}


public Action Timer_UpdateHudHint(Handle timer, any client)
{
	int iSpecModeUser = GetEntProp(client, Prop_Send, "m_iObserverMode");
	int iSpecMode, iTarget, iTargetUser;
	bool bDisplayHint = false;
	
	char szText[2048];
	szText[0] = '\0';
	
	// Dealing with a client who is in the game and playing.
	if (IsPlayerAlive(client))
	{
		Format(szText, sizeof(szText), "Spectators:\n\n", iTarget);
		
		for(int i = 1; i <= MaxClients; i++) 
		{
			if (!IsClientInGame(i) || !IsClientObserver(i))
				continue;						
				
			iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			
			// The client isn't spectating any one person, so ignore them.
			if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
				continue;
			
			// Find out who the client is spectating.
			iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			
			// Are they spectating our player?
			if (iTarget == client)
			{
				Format(szText, sizeof(szText), "%s%N\n", szText, i); 
				bDisplayHint = true;
			}
		}
	}
	else if (iSpecModeUser == SPECMODE_FIRSTPERSON || iSpecModeUser == SPECMODE_3RDPERSON)
	{
		// Find out who the User is spectating.
		iTargetUser = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		
		if (iTargetUser > 0)
			Format(szText, sizeof(szText), "Spectating %N:\n\n", iTargetUser);
		
		for(int i = 1; i <= MaxClients; i++) 
		{			
			if (!IsClientInGame(i) || !IsClientObserver(i))
				continue;
				
			iSpecMode = GetEntProp(i, Prop_Send, "m_iObserverMode");
			
			// The client isn't spectating any one person, so ignore them.
			if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
				continue;
			
			// Find out who the client is spectating.
			iTarget = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");
			
			// Are they spectating the same player as User?
			if (iTarget == iTargetUser)
				Format(szText, sizeof(szText), "%s%N\n", szText, i); 
		}
	}
	
	/* We do this to prevent displaying a message
		to a player if no one is spectating them anyway. */
	if (bDisplayHint)
	{
		SetHudTextParams(speclist_x, speclist_y, 3.0, speclist_color_red, speclist_color_green, speclist_color_blue, speclist_color_alpha, 0, 0.0, 0.1, 0.1);
		ShowHudText(client, -1, szText);
		bDisplayHint = false;
	}
	
	return Plugin_Continue;
}

void CreateHudHintTimer(int client)
{
	HudHintTimers[client] = CreateTimer(UPDATE_INTERVAL, Timer_UpdateHudHint, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void KillHudHintTimer(int client)
{
	if (HudHintTimers[client] != INVALID_HANDLE)
	{
		KillTimer(HudHintTimers[client]);
		HudHintTimers[client] = INVALID_HANDLE;
	}
}