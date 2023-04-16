public without sharing class RoundRobinTerritoryHelper {

    //Map of territory name to map of role name to list of RR users
    private static Map<String, Map<String, List<Round_Robin_User__c>>> ttyRoleUserMap 
        = new Map<String, Map<String, List<Round_Robin_User__c>>>();

    //Map of RR key to get RoundRobin record Id
    private static Map<String, String> rrKeyIdMap = new Map<String, String>();

    //returns sorted lists by group name
    public static Map<String, Map<String, List<Round_Robin_User__c>>> getSortedRoundRobinUserMap(Set<String> ttyNames, Set<String> ttyRoles) {

        Map<String, Map<String, Set<Id>>> ttyUsersByRoleMap = getAllUsersFromTerritoriesByRole(ttyNames, ttyRoles);

        Map<String, Map<String, Set<Id>>> rrUsersByTtyRoleMap = getRRUsersByTtyAndRole(ttyNames, ttyRoles);
        
        deleteOldRRTTyUsers(ttyUsersByRoleMap, rrUsersByTtyRoleMap); //BR-3750

        Map<String, Map<String, Set<Id>>> rrTtyUsersToCreate = getRRTTyUsersToCreate(ttyUsersByRoleMap, rrUsersByTtyRoleMap);
        
        Map<String, Map<String, List<Round_Robin_User__c>>> newRRTtyUsers = createNewRRUsers(rrTtyUsersToCreate);
        addNewTtyRRUsersToMap(newRRTtyUsers);
        initUpsertRoundRobinNumbers();
        //return group maps with sorted lists
        return ttyRoleUserMap;
    }

    /**
     * Find all territory users and their roles
     */
    public static Map<String, Map<String, Set<Id>>> getAllUsersFromTerritoriesByRole(Set<String> ttyNames, Set<String> ttyRoles) {

        //Territory name to map of role name to set of user ids
        Map<String, Map<String, Set<Id>>> ttyToRoleUserIdMap = new Map<String, Map<String, Set<Id>>>();

        for(UserTerritory2Association uta : [SELECT RoleInTerritory2, Territory2.Name, UserId 
            FROM UserTerritory2Association WHERE Territory2.Name IN :ttyNames
            AND RoleInTerritory2 IN :ttyRoles
            AND Territory2.Territory2Model.State != 'Archived']) {

            if (!ttyToRoleUserIdMap.containsKey(uta.Territory2.Name) ) {
                ttyToRoleUserIdMap.put(uta.Territory2.Name, new Map<String, Set<Id>>());
            }

            if(!ttyToRoleUserIdMap.get(uta.Territory2.Name).containsKey(uta.RoleInTerritory2)) {
                ttyToRoleUserIdMap.get(uta.Territory2.Name).put(uta.RoleInTerritory2, new Set<Id>());
            }
            ttyToRoleUserIdMap.get(uta.Territory2.Name).get(uta.RoleInTerritory2).add(uta.UserId);
        }

        return ttyToRoleUserIdMap;
    }

    /**
     * Get existing users who are setup as Round Robin Users, in a map with the territory name as key
     */
    public static Map<String, Map<String, Set<Id>>> getRRUsersByTtyAndRole(Set<String> ttyNames, Set<String> ttyRoles) {

        Map<String, Map<String, Set<Id>>> rrTtyToRoleUserIdMap = new Map<String, Map<String, Set<Id>>>();

        for (Round_Robin_User__c rrUser : [SELECT Id, Round_Robin_Number__c, User__c, 
                                            User_Paused__c, Territory_Name__c, Territory_Role_Name__c
                                            FROM Round_Robin_User__c WHERE Territory_Name__c IN :ttyNames
                                            AND Territory_Role_Name__c IN :ttyRoles
                                            ORDER BY Round_Robin_Number__c]) {

            //collect the user ids for comparison here
            if (!rrTtyToRoleUserIdMap.containsKey(rrUser.Territory_Name__c)) {
                rrTtyToRoleUserIdMap.put(rrUser.Territory_Name__c, new Map<String, Set<Id>>());
            }

            if (!rrTtyToRoleUserIdMap.get(rrUser.Territory_Name__c).containsKey(rrUser.Territory_Role_Name__c)) {
                rrTtyToRoleUserIdMap.get(rrUser.Territory_Name__c).put(rrUser.Territory_Role_Name__c, new Set<Id>());
            }

            rrTtyToRoleUserIdMap.get(rrUser.Territory_Name__c).get(rrUser.Territory_Role_Name__c).add(rrUser.User__c);

            //BR-3750 Populate rrKeyIdMap to get RR record Id as value
            String rrKey = rrUser.Territory_Name__c + '-' + rrUser.Territory_Role_Name__c + '-' + rrUser.User__c;
            rrKeyIdMap.put(rrKey,rrUser.Id);

            //collect the round robin users here
            if (!ttyRoleUserMap.containsKey(rrUser.Territory_Name__c)) {
                ttyRoleUserMap.put(rrUser.Territory_Name__c, new Map<String, List<Round_Robin_User__c>>());
            }

            if (!ttyRoleUserMap.get(rrUser.Territory_Name__c).containsKey(rrUser.Territory_Role_Name__c)) {
                ttyRoleUserMap.get(rrUser.Territory_Name__c).put(rrUser.Territory_Role_Name__c, 
                    new List<Round_Robin_User__c>());
            }

            ttyRoleUserMap.get(rrUser.Territory_Name__c).get(rrUser.Territory_Role_Name__c).add(rrUser);

        }
        
        return rrTtyToRoleUserIdMap;
    }

    /**
     * Compares the users mapped to the role name and territory name
     * Finds users that are setup in the territory but do not have corresponding 
     * Round Robin Users.
     * Returns a map of the territory name mapped to user's role in the territory
     * to a set of users ids
     */
    public static Map<String, Map<String, Set<Id>>> getRRTTyUsersToCreate(
        Map<String, Map<String, Set<Id>>> ttyRoleUsersMap, Map<String, Map<String, Set<Id>>> rrTtyRoleUsersMap) {
        
        //If creating new Round Robin User records then store the ids in this map
        //map of territory name to map of territory role to set of territory user ids
        Map<String, Map<String, Set<Id>>> newRRTtyUsersToCreate = new Map<String, Map<String, Set<Id>>>();

        for (String ttyName : ttyRoleUsersMap.keySet()) {

            Map<String, Set<Id>> ttyUsersByRole = ttyRoleUsersMap.get(ttyName);
            if (ttyUsersByRole == null || ttyUsersByRole.isEmpty()) {
                continue;
            }

            Map<String, Set<Id>> rrTtyUsersByRole = rrTtyRoleUsersMap.get(ttyName);

            //if no "current" users exist in Round Robin Users for this territory name
            if (rrTtyUsersByRole == null || rrTtyUsersByRole.isEmpty()) {
                newRRTtyUsersToCreate.put(ttyName, ttyUsersByRole);

            } else {
                for (String ttyRole : rrTtyUsersByRole.keySet()) {

                    Set<Id> roleUsers = ttyUsersByRole.get(ttyRole);
                    Set<Id> rrRoleUsers = rrTtyUsersByRole.get(ttyRole);

                    if(rrRoleUsers == null || rrRoleUsers.isEmpty()) {
                        newRRTtyUsersToCreate.put(ttyName, new Map<String, Set<Id>>{
                            ttyRole => roleUsers
                        });
                    } else {
                        roleUsers.removeAll(rrRoleUsers);
                        newRRTtyUsersToCreate.put(ttyName, new Map<String, Set<Id>>{
                            ttyRole => roleUsers
                        });
                    }
                }
            }
        }
        return newRRTtyUsersToCreate;
    }

    
    /**
     * BR-3750 Delete round robin users who are not part of the given territory anymore
    */
    public static void deleteOldRRTTyUsers (
        Map<String, Map<String, Set<Id>>> ttyRoleUsersMap, Map<String, Map<String, Set<Id>>> rrTtyRoleUsersMap) {

        //Set of User Ids that needs to be deleted
        Set<Id> userIdsToBeRemovedFromRR = new Set<Id> ();

        for (String ttyName : rrTtyRoleUsersMap.keySet()) {
            
            //Round Robin User Map By Role
            Map<String, Set<Id>> rrTtyUsersByRole = rrTtyRoleUsersMap.get(ttyName);
            
            //Teritory Users Map by Role
            Map<String, Set<Id>> ttyUsersByRole = ttyRoleUsersMap.get(ttyName);

            if (ttyUsersByRole == null || ttyUsersByRole.isEmpty() ||
              rrTtyUsersByRole == null || rrTtyUsersByRole.isEmpty()) {
                continue;
            }
            
            for (String ttyRole : rrTtyUsersByRole.keySet()) {

                for(Id userId : rrTtyUsersByRole.get(ttyRole)) {

                    Set<Id> ttyUsersByRoleSet = ttyUsersByRole.get(ttyRole);

                    if (ttyUsersByRoleSet != null && ttyUsersByRoleSet.contains(userId)) {
                        continue;
                    } else {
                        /*
                        * The user exists in the Round Robin User table but
                        * does not in the user territory assignation anymore. Needs to be deleted.
                        */
                        
                        // Build Round Robin record Key
                        String rrKey = ttyName + '-' + ttyRole + '-' + userId; 
                        // Round Robin Record Id
                        Id rrId = rrKeyIdMap.get(rrKey);
                        // Add Old RoundRobin Id to the set in order to be deleted
                        userIdsToBeRemovedFromRR.add(rrId);
                        // Remove RoundRobin record from rrTtyRoleUsersMap
                        rrTtyRoleUsersMap.get(ttyName).get(ttyRole).remove(userId);
                        // Remove RoundRobin record from static ttyRoleUserMap
                        for (Integer i = ttyRoleUserMap.get(ttyName).get(ttyRole).size() - 1 ; i >= 0 ; i--) {
                            if (ttyRoleUserMap.get(ttyName).get(ttyRole)[i].Id == rrId) {
                                ttyRoleUserMap.get(ttyName).get(ttyRole).remove(i);
                            }
                        }
                        
                    }
                }
            }
        }

        //Query for old Round Robin users and delete them
        if (!userIdsToBeRemovedFromRR.isEmpty()) {
            List<Round_Robin_User__c> rrUsersToBeDeleted = [
                SELECT Id
                FROM Round_Robin_User__c
                WHERE Id IN :userIdsToBeRemovedFromRR
            ];
            delete rrUsersToBeDeleted;
        }
    }

    /**
     * Create and return round robin users, sets up the territory name, role in territory
     * and return a map of the same
    */
    public static Map<String, Map<String, List<Round_Robin_User__c>>> createNewRRUsers(
            Map<String, Map<String, Set<Id>>> rrTtyUsersToCreate) {

        //map of the tty name to a map of tty user role to list of Round Robin User records
        Map<String, Map<String, List<Round_Robin_User__c>>> ttyNameToRoleRRUsersMap = 
            new Map<String, Map<String, List<Round_Robin_User__c>>>();

        for (String ttyName : rrTtyUsersToCreate.keySet()) {
            
            Map<String, Set<Id>> newUserIdsByRoleMap = rrTtyUsersToCreate.get(ttyName);
            if (newUserIdsByRoleMap.isEmpty()) {
                continue;
            }

            Map<String, List<Round_Robin_User__c>> tmpRRUsersByRoleMap = 
                new Map<String, List<Round_Robin_User__c>>();
            List<Round_Robin_User__c> tmpRRUserList = new List<Round_Robin_User__c>(); 

            for(String roleName : newUserIdsByRoleMap.keySet()) {
                Set<Id> userIds = newUserIdsByRoleMap.get(roleName);
                
                for (Id userId : userIds) {
                    tmpRRUserList.add(new Round_Robin_User__c(
                        Territory_Name__c = ttyName,
                        Territory_Role_Name__c = roleName,
                        User__c = userId,
                        Round_Robin_Number__c = 0
                    ));
                }

                tmpRRUsersByRoleMap.put(roleName, tmpRRUserList);
            }

            ttyNameToRoleRRUsersMap.put(ttyName, tmpRRUsersByRoleMap);
        }

        return ttyNameToRoleRRUsersMap;
    }

    /**
     * Append the list of all the existing Round Robin Users to the list
     * of newly minted round robin users.
     */
    public static void addNewTtyRRUsersToMap(
        Map<String, Map<String, List<Round_Robin_User__c>>> ttyNameToRRUsersByRoleMap) {
        
        for (String ttyName : ttyNameToRRUsersByRoleMap.keySet()) {
            Map<String, List<Round_Robin_User__c>> roleToRRUserMap =  ttyNameToRRUsersByRoleMap.get(ttyName);

            for (String roleName : roleToRRUserMap.keySet()) {
                if (ttyRoleUserMap.get(ttyName) != null && ttyRoleUserMap.get(ttyName).get(roleName) != null) {

                    roleToRRUserMap.get(roleName).addAll(ttyRoleUserMap.get(ttyName).get(roleName));
                }
            }
            ttyRoleUserMap.put(ttyName, roleToRRUserMap);
        }
    }

    /**
     * Upserts all users in the ttyRoleUserMap. Before upsert updates the round
     * resets the round robin numbers to begin from 0. Shouldn't be a problem since we are
     * appending existing users sorted by the number to the list of new users with a 0
     * number.
     */
    public static void initUpsertRoundRobinNumbers() {
        List<Round_Robin_User__c> rrUsersToUpsert = new List<Round_Robin_User__c>();
        for (String ttyName : ttyRoleUserMap.keySet()) {
            Map<String, List<Round_Robin_User__c>> roleRRUsers = ttyRoleUserMap.get(ttyName);
            
            for (String roleName : roleRRUsers.keySet()) {
                List<Round_Robin_User__c> rrUsers = roleRRUsers.get(roleName);
                
                for (Integer i=0; i < rrUsers.size(); i++) {
                    rrUsers.get(i).Round_Robin_Number__c = i;
                }
                rrUsersToUpsert.addAll(rrUsers);
            }
        }
        upsert rrUsersToUpsert;
    }
}