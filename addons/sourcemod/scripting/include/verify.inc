#if defined _VF_included
#endinput
#endif
#define _VF_included

/*
 * Determines if a player is dead and has had their body found.
 *
 * @param client              The client index to lookup.
 */
native bool TTT_GetFoundStatus(int client);

/*
 * Called when a client's role is assigned.
 *
 * @param client            Client index.
 */
forward void TTT_OnClientGetRole(int client);