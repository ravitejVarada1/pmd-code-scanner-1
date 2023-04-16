public class RoundRobinUserHelper {

    private static Map<String, List<Round_Robin_User__c>> rrGroupToUserMap 
        = new Map<String, List<Round_Robin_User__c>>();

    //Map of RR key to get RoundRobin record Id
    private static Map<String, String> rrKeyIdMap = new Map<String, String>();
    
    //returns sorted lists by group name
    public static Map<String, List<Round_Robin_User__c>> getSortedRoundRobinUserMap(Set<String> groupNames) {

        //find all group users by users ids- for now only one level no recursion into groups
        Map<String, Set<Id>> groupToUserIdMap = getAllUsersFromGroups(groupNames);
        Map<String, Set<Id>> rrGroupToUserIdMap = getRRUserIdsByGroup(groupNames);

        deleteOldRRGroupUsers(groupToUserIdMap, rrGroupToUserIdMap); //BR-3750
        
        //find round robin users to create, in a map of group name to set of user ids
        Map<String, Set<Id>> rrUsersToCreate = getRRUsersToCreate(groupToUserIdMap, rrGroupToUserIdMap);

        //create a map of group name to a list of round robin users to create
        Map<String, List<Round_Robin_User__c>> gpNameToNewRRUsersMap = createNewRRUsers(rrUsersToCreate);

        //add/append all the existing RR users to the lists by group name and insert
        addNewRRUsersToMap(gpNameToNewRRUsersMap);

        for (String gpName : rrGroupToUserMap.keySet()) {
            System.debug('Group Name::'+gpName);
            List<Round_Robin_User__c> rrusers = rrGroupToUserMap.get(gpName);
            for (Round_Robin_User__c rru : rrusers) {
                System.debug(rru.User__c+'--'+rru.Round_Robin_Number__c);
            }
        }
        initRoundRobinNumbers();
        //return group maps with sorted lists
        return rrGroupToUserMap;
    }

    //find all group users - for MVP do not recurse into groups
    public static Map<String, Set<Id>> getAllUsersFromGroups(Set<String> groupNames) {
            Map<String, Set<Id>> groupToUserIdMap = new Map<String, Set<Id>>();
            //Map<String, String> nestedGroupNameMap = new Map<String, String>();

            String userSobjPrefix = Schema.SObjectType.User.getKeyPrefix();
            //String groupPrefix = Schema.SObjectType.Group.getKeyPrefix();
            
            for (GroupMember gm : [SELECT Id, Group.DeveloperName, UserOrGroupId FROM GroupMember WHERE
                    Group.DeveloperName IN :groupNames]){

                if (((String)gm.UserOrGroupId).startsWith(userSobjPrefix)){
                    if(!groupToUserIdMap.containsKey(gm.Group.DeveloperName)) {
                        groupToUserIdMap.put(gm.Group.DeveloperName, new Set<Id>());
                    }
                    groupToUserIdMap.get(gm.Group.DeveloperName).add(gm.UserOrGroupId);
                } 
            }
            
            return groupToUserIdMap; 
    }

    //get users who are setup as Round Robin Users, in a map with the group developer
    //name as key
    public static Map<String, Set<Id>> getRRUserIdsByGroup(Set<String> groupNames) {

        Map<String, Set<Id>> rrGroupToUserIdMap = new Map<String, Set<Id>>();

        for (Round_Robin_User__c rrUser : [SELECT Id, Round_Robin_Number__c, User__c, 
                                            User_Paused__c, Round_Robin_Group__c
                                            FROM Round_Robin_User__c WHERE Round_Robin_Group__c IN :groupNames
                                            ORDER BY Round_Robin_Number__c]) {

            if (!rrGroupToUserIdMap.containsKey(rrUser.Round_Robin_Group__c)) {
                rrGroupToUserIdMap.put(rrUser.Round_Robin_Group__c, new Set<Id>());
            }

            rrGroupToUserIdMap.get(rrUser.Round_Robin_Group__c).add(rrUser.User__c);

            //BR-3750 Populate rrKeyIdMap to get RR record Id as value
            String rrKey = rrUser.Round_Robin_Group__c + '-' + rrUser.User__c;
            rrKeyIdMap.put(rrKey,rrUser.Id);


            if (!rrGroupToUserMap.containsKey(rrUser.Round_Robin_Group__c)) {
                rrGroupToUserMap.put(rrUser.Round_Robin_Group__c, new List<Round_Robin_User__c>());
            }

            rrGroupToUserMap.get(rrUser.Round_Robin_Group__c).add(rrUser);
        }
        
        return rrGroupToUserIdMap;
    }

    //figure out which users are not among existing Round Robin Users so we can create them
    public static Map<String, Set<Id>> getRRUsersToCreate(Map<String, Set<Id>> groupToUserIdMap,Map<String, Set<Id>> rrGroupToUserIdMap) {
        
        Map<String, Set<Id>> newRRUsers = new Map<String, Set<Id>>();
        for (String gpName : groupToUserIdMap.keySet()) {

            Set<Id> gpUserIds = groupToUserIdMap.get(gpName);
            Set<Id> rrGpUserIds = rrGroupToUserIdMap.get(gpName);

            if(rrGpUserIds != null) {
                gpUserIds.removeAll(rrGpUserIds);
            }

            if(!gpUserIds.isEmpty()) {
                newRRUsers.put(gpName, new Set<Id>(gpUserIds));
            }
        }
        return newRRUsers;
    }

    /**
     * BR-3750 Delete round robin users who are not part of the given territory anymore
    */
    public static void deleteOldRRGroupUsers (
        Map<String, Set<Id>> groupToUserIdMap, Map<String, Set<Id>> rrGroupToUserIdMap) {

        //Set of User Ids that needs to be deleted
        Set<Id> userIdsToBeRemovedFromRR = new Set<Id> ();

        for (String groupName : rrGroupToUserIdMap.keySet()) {
            
            //Round Robin Group Users Set
            Set<Id> rrGroupUsersSet = rrGroupToUserIdMap.get(groupName);
            //Group Users Set
            Set<Id> groupUsersSet = groupToUserIdMap.get(groupName);

            if (rrGroupUsersSet == null || rrGroupUsersSet.isEmpty()) {
                continue;
            }
            for (String userId : rrGroupUsersSet) {

                if (groupUsersSet != null && groupUsersSet.contains(userId)) {
                    continue;
                } else {
                    /*
                    * The user exists in the Round Robin User table but
                    * does not in the user group anymore. Needs to be deleted.
                    */
                    
                    // Build Round Robin record Key
                    String rrKey = groupName + '-' + userId; 
                    // Round Robin Record Id
                    Id rrId = rrKeyIdMap.get(rrKey);
                    // Add Old RoundRobin Id to the set in order to be deleted
                    userIdsToBeRemovedFromRR.add(rrId);
                    // Remove RoundRobin record from map
                    rrGroupToUserIdMap.get(groupName).remove(userId);
                    // Remove RoundRobin record from static rrGroupToUserMap
                    for (Integer i = rrGroupToUserMap.get(groupName).size() - 1 ; i >= 0 ; i--) {
                        if (rrGroupToUserMap.get(groupName)[i].Id == rrId) {
                            rrGroupToUserMap.get(groupName).remove(i);
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

    //create the new RR users
    public static Map<String, List<Round_Robin_User__c>> createNewRRUsers(Map<String, Set<Id>> rrUsersToCreate) {

        Map<String, List<Round_Robin_User__c>> gpNameToNewRRUsersMap = new Map<String, List<Round_Robin_User__c>>();
        for (String gpName : rrUsersToCreate.keySet()) {
            
            Set<Id> gpNewUserIds = rrUsersToCreate.get(gpName);
            if (gpNewUserIds.isEmpty()) {
                continue;
            }

            List<Round_Robin_User__c> tmpRRList = new List<Round_Robin_User__c>(); 
            for (Id userId : gpNewUserIds) {
                tmpRRList.add(new Round_Robin_User__c(
                    Round_Robin_Group__c = gpName,
                    User__c = userId,
                    Round_Robin_Number__c = 0
                ));
            }

            if (!tmpRRList.isEmpty()) {
                gpNameToNewRRUsersMap.put(gpName, tmpRRList);
            }
        }

        return gpNameToNewRRUsersMap;
    }

    public static void addNewRRUsersToMap(Map<String, List<Round_Robin_User__c>> gpNameToNewRRUsersMap) {
        
        for(String gpName : gpNameToNewRRUsersMap.keySet()) {
            List<Round_Robin_User__c> newRRUsers = gpNameToNewRRUsersMap.get(gpName);
            
            if (rrGroupToUserMap.containsKey(gpName)) {
                newRRUsers.addAll(rrGroupToUserMap.get(gpName));
            }

            rrGroupToUserMap.put(gpName, newRRUsers);
        }
    }

    public static void initRoundRobinNumbers() {
        List<Round_Robin_User__c> rrUsersToUpsert = new List<Round_Robin_User__c>();
        for(String gpName : rrGroupToUserMap.keySet()) {
            List<Round_Robin_User__c> rrUsers = rrGroupToUserMap.get(gpName);
            for(Integer i=0; i < rrUsers.size(); i++) {
                rrUsers.get(i).Round_Robin_Number__c = i;
            }
            rrUsersToUpsert.addAll(rrUsers);
        }
        upsert rrUsersToUpsert;
    }
}