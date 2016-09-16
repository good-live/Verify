#if defined _VF_included
#endinput
#endif
#define _VF_included

/*
 * Determines if a player is verified or not.
 *
 * @param client              The client index to lookup.
 */
native bool VF_IsClientVerified(int client);

/*
 * Called when a client gets verified.
 *
 * @param client            Client index.
 */
forward void VF_OnClientVerified(int client);