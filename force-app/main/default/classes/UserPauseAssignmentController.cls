/** 
 * Apex Controller for the Pause Assingments LWC.
 * https://cargurus.atlassian.net/browse/BR-4157
 */
public without sharing class UserPauseAssignmentController {

    /**
     * Get default list of Round Robin Users, or filtered by filter criteria
     * and filter value
     */
    @AuraEnabled
    public static List<User> getUsers(String filterCriteria, String filterValue, Id runningUserId){
        System.debug(filterCriteria+' '+filterValue+' '+runningUserId);
        try {
            System.debug('getUsers');
            String queryClause;
            if (filterCriteria == 'name' && String.isNotBlank(filterValue)) {
                queryClause = 'NAME LIKE \'%'+filterValue+'%\'';
            
            } else if (filterCriteria == 'email' && String.isNotBlank(filterValue)) {
                queryClause = 'Email LIKE \'%'+filterValue+'%\'';
            }

            String query = 'SELECT Id, FirstName, LastName, Name, Email, Pause_Assignments__c, IsActive '+
                            'FROM User WHERE IsActive = true '+
                            'AND UserType = \'Standard\'';

            if(queryClause != null) {
                query += ' AND '+queryClause;
            }
            
            query += ' AND Id IN (SELECT User__c FROM Round_Robin_User__c)';

            query += ' ORDER BY LastName ASC';

            List<User> users = Database.query(query);
            for(User u : users) {
                System.debug(u.Name);
            }

            return users;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Find all the subordinate role ids and fetch users belonging to those
     * roles
     */
    @AuraEnabled
    public static List<User> getAllSubRoleUsers() {
        System.debug('getAllSubRoles');
        try {
            Id runningUserRoleId = UserInfo.getUserRoleId();    
            Set<Id> subRoleIds = getAllSubRoleIds(new Set<Id>{runningUserRoleId});

            System.debug(subRoleIds);

            return [SELECT Id, FirstName, LastName, Name, Email, Pause_Assignments__c, IsActive
                    FROM User 
                    WHERE IsActive = true AND UserRoleId IN :subRoleIds 
                    AND Id IN (SELECT User__c FROM Round_Robin_User__c) ORDER BY LastName ASC];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Helps find the subordinate role ids
     */
    public static Set<Id> getAllSubRoleIds(Set<Id> roleIds) {
        Set<Id> subRoleIds = new Set<Id>();
        for (UserRole ur : [SELECT Id FROM UserRole WHERE ParentRoleId IN :roleIds AND ParentRoleId != null]) {
            subRoleIds.add(ur.Id);
        }

        if(subRoleIds.size() > 0) {
            subRoleIds.addAll(getAllSubRoleIds(subRoleIds));
        }

        return subRoleIds;
    }

    /**
     * Assumes the running user is a manager and attempts to find
     * all users that report to the running user
     */
    @AuraEnabled
    public static List<User> getUsersForManager() {
        try {
            Id runningUserId = UserInfo.getUserId(); 
            return getUsersForManager(runningUserId);   
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Query returns all users that report directly to the manager (running user)
     * or inrectly report to the running user
     */
    public static List<User> getUsersForManager(Id managerId) {
        return [SELECT Id, FirstName, LastName, Name, Email, Pause_Assignments__c, IsActive 
                FROM User 
                WHERE IsActive = true AND 
                (ManagerId = :managerId OR 
                Manager.ManagerId = :managerId OR 
                Manager.Manager.Manager.Id = :managerId OR
                Manager.Manager.Manager.Manager.Id = :managerId)
                AND Id IN (SELECT User__c FROM Round_Robin_User__c)
                ORDER BY LastName ASC];
    }

    /**
     * Save/Update user to set Pause Assigments = true. Examines territory by role of the user
     * and group membership to determine if pausing would lead to all users in the territory role
     * combination or group to be paused. If all users are potentailly paused, throws an error 
     * and attempts to describe which territories or groups would be affected.
     */
    @AuraEnabled
    public static string updateUsers(Object data){
        try {

            List<User> usersToUpdate = (List<User>)JSON.deserialize(
                JSON.serialize(data), 
                List<User>.class
            );

            Map<String, Map<String, Map<String, Set<Id>>>> toPauseUsers = getRoundRobinGroupsForDraftUsers(usersToUpdate);
            checkAllUsersPaused(toPauseUsers);

            update usersToUpdate;
            
            return 'Success: Users Updated';

        } catch (AuraHandledException ahe) {
            throw ahe;

        } catch (DMLException dmle) {
            AuraHandledException ahe = new AuraHandledException(dmle.getMessage());
            ahe.setMessage(dmle.getMessage());
            throw ahe;

        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        } 
    }

    /**
     * For the users that are being paused, find their territory memberships along with their territory roles, if the
     * round robin user record specifies a group, then find the group names and organize into a collection
     */
    public static Map<String, Map<String, Map<String, Set<Id>>>> getRoundRobinGroupsForDraftUsers(List<User> toPauseUsers) {

        Map<String, Map<String, Map<String, Set<Id>>>> retTtyGpMaps = new Map<String, Map<String, Map<String, Set<Id>>>>();
        Map<Id, User> usersToPauseMap = new Map<Id, User>(toPauseUsers);
        
        //Territory Name => Territory role => set (users ids)
        Map<String, Map<String, Set<Id>>> ttyUserMap = new Map<String, Map<String, Set<Id>>>();

        //Since no group roles, 'ALL' => Group Name => set (users ids)
        Map<String, Map<String, Set<Id>>> gpUserMap = new Map<String, Map<String, Set<Id>>>();

        retTtyGpMaps.put('Territory', ttyUserMap);
        retTtyGpMaps.put('Group', gpUserMap);

        if(toPauseUsers.size() == 0) {
            return retTtyGpMaps;
        }

        for(Round_Robin_User__c rrUser : [SELECT Id, Territory_Name__c, Territory_Role_Name__c, Round_Robin_Group__c, 
            User__c, User__r.Name
            FROM Round_Robin_User__c WHERE User__c IN :usersToPauseMap.keySet()]) 
        {
            
            Id rrUserId = rrUser.User__c;
            if(usersToPauseMap.containsKey(rrUserId) && !usersToPauseMap.get(rrUserId).Pause_Assignments__c) {
                continue;
            }

            String ttyName = rrUser.Territory_Name__c;
            String ttyRoleName = rrUser.Territory_Role_Name__c;
            String gpName = rrUser.Round_Robin_Group__c;

            System.debug(ttyName);
            System.debug(rrUser.User__r.Name);

            if(ttyName != null) {
                if(!ttyUserMap.containsKey(ttyName)) {
                    ttyUserMap.put(ttyName, 
                        new Map<String, Set<Id>> {
                            ttyRoleName => new Set<Id>{rrUserId}
                        }
                    );
                } else {
                    ttyUserMap.get(ttyName).get(ttyRoleName).add(rrUserId);
                }
            } else if(gpName != null) {
                System.debug('GP Name Not NULL');
                if(!gpUserMap.containsKey('ALL')) {
                    gpUserMap.put('ALL', 
                        new Map<String, Set<Id>> {
                            gpName => new Set<Id>{rrUserId}
                        }
                    );
                } else {
                    gpUserMap.get('ALL').get(gpName).add(rrUserId);
                }
            }
        }
        
        return retTtyGpMaps;
    }

    /**
     * Determines from the collection passed, is all users in the territories/groups specified in the collection 
     * would be paused.
     */
    public static void checkAllUsersPaused(Map<String, Map<String, Map<String, Set<Id>>>> ttyGPMaps) {
        Map<String, Map<String, Set<Id>>> ttyUsers = ttyGPMaps.get('Territory');
        Map<String, Map<String, Set<Id>>> allGpUsers = ttyGPMaps.get('Group');
        
        System.debug(ttyUsers.size());
        System.debug(allGpUsers.size());

        String allPausedError = 'Pause unsuccessful, all users would be paused in the following Territories/Groups: ';
        Boolean isAllPaused = false;
        if(ttyUsers.size() > 0) {
            Map<String, Map<String, Integer>> ttyUnpausedNumMap = checkAllUsersPausedTerritories(ttyUsers);
            for(String ttyName : ttyUnpausedNumMap.keySet()) {
                Map<String, Integer> ttyRoleNumUnpaused = ttyUnpausedNumMap.get(ttyName);
                for(String roleName : ttyRoleNumUnpaused.keySet()) {
                    Integer numUnpaused = ttyRoleNumUnpaused.get(roleName);
                    if(numUnpaused == 0) {
                        isAllPaused = true;
                        allPausedError += 'Territory Name: '+ttyName+' & Role: '+roleName+' ; ';
                    }
                }
            }
        }

        if(allGpUsers.size() > 0) {
            Map<String, Set<Id>> gpUsers = allGpUsers.get('ALL');
            System.debug(gpUsers);
            Map<String, Integer> gpUnpausedNumMap = checkAllUsersPausedGroups(gpUsers);
            for(String gpName : gpUnpausedNumMap.keySet()) {
                Integer numUnpaused = gpUnpausedNumMap.get(gpName);
                if(numUnpaused == 0) {
                    isAllPaused = true;
                    allPausedError += 'Group Name: '+gpName+' ; ';
                }
            }
        }

        if(isAllPaused == true) {
            AuraHandledException ahe = new AuraHandledException(allPausedError);
            ahe.setMessage(allPausedError);
            throw new AuraHandledException(allPausedError);
        }
    }

    /**
     * Query territory users by the territory names and roles, find unpaused users.
     */
    public static Map<String, Map<String, Integer>> checkAllUsersPausedTerritories(Map<String, Map<String, Set<Id>>> ttyUsers) {

        Set<String> ttyRoleNames = new Set<String>();
        for(String ttyName : ttyUsers.keySet()) {
            ttyRoleNames.addAll(ttyUsers.get(ttyName).keySet());
        }
        System.debug(ttyRoleNames);

        //Territory Name => Role in territory => num unpaused users 
        Map<String, Map<String, Integer>> ttyUnpausedNumMap = new Map<String, Map<String, Integer>>();

        Integer ttyUnpausedCount = 0;
        
        List<UserTerritory2Association> ut2as;
        if(Test.isRunningTest()) {
	        ut2as = [SELECT Territory2.Name, UserId, User.Pause_Assignments__c, RoleInTerritory2
                FROM UserTerritory2Association WHERE Territory2.Name IN :ttyUsers.keySet()
                AND RoleInTerritory2 IN :ttyRoleNames
                AND User.Pause_Assignments__c = false
                ORDER BY Territory2.Name];
        } else {
            ut2as = [SELECT Territory2.Name, UserId, User.Pause_Assignments__c, RoleInTerritory2
                FROM UserTerritory2Association WHERE Territory2.Name IN :ttyUsers.keySet()
                AND RoleInTerritory2 IN :ttyRoleNames
                AND User.Pause_Assignments__c = false
                AND Territory2.Territory2Model.State = 'Active'
                ORDER BY Territory2.Name];
        }

        for(UserTerritory2Association uta : ut2as) {
            String ttyName = uta.Territory2.Name;
            String ttyRole = uta.RoleInTerritory2;

            if(!ttyUnpausedNumMap.containsKey(ttyName)) {
                ttyUnpausedNumMap.put(ttyName, new Map<String, Integer>{ttyRole => 0});
            }

            Set<Id> ttyUserIds = ttyUsers.get(ttyName).get(ttyRole);
            if(ttyUserIds != null && ttyUserIds.contains(uta.UserId)) {
                continue;
            } 

            if(!uta.User.Pause_Assignments__c) {
                ttyUnpausedNumMap.get(ttyName).put(ttyRole, ttyUnpausedCount++);
            }
        }

        return ttyUnpausedNumMap;
    }

    /**
     * Query group membership by group names of to be paused users, see if there are any unpaused users
     * and set the number of unpaused in a collection
     */
    public static Map<String, Integer> checkAllUsersPausedGroups(Map<String, Set<Id>> gpUsers) {

        //Group Name => Number of Unpaused users
        Map<String, Integer> gpUnpausedNumMap = new Map<String, Integer>();

        if(gpUsers.size() > 0) {
            Map<Id, Boolean> gpUserPauseMap = getGroupUserDetailMap(gpUsers);

            Integer gpUnpausedCount = 0;

            for(GroupMember gpm : [SELECT UserOrGroupId, Group.DeveloperName FROM GroupMember 
                WHERE Group.DeveloperName IN :gpUsers.keySet() ORDER BY Group.Name])
            {
                String gpName = gpm.Group.DeveloperName;
                System.debug(gpName);
                Id userId = gpm.UserOrGroupId;

                if(!gpUnpausedNumMap.containsKey(gpName)) {
                    gpUnpausedNumMap.put(gpName, 0);
                }

                Set<Id> gpUserIds = gpUsers.get(gpName);
                SYstem.debug(gpUserIds);
                if(gpUserIds != null && gpUserIds.contains(gpm.UserOrGroupId)) {
                    continue;
                } 

                if(gpUserPauseMap.containsKey(userId) && !gpUserPauseMap.get(userId)) {
                    System.debug('found unpaused users');
                    gpUnpausedNumMap.put(gpName, gpUnpausedCount++);
                }
            }
        }

        return gpUnpausedNumMap;
    }

    /**
     * Get group members of all the groups in the collection of Group Names to Users
     */
    public static Map<Id, Boolean> getGroupUserDetailMap(Map<String, Set<Id>> gpUsers) {
        Map<Id, Boolean> gpUserIsPausedMap = new Map<Id, Boolean>();
        
        for(User u : [SELECT Id, Pause_Assignments__c FROM User 
            WHERE Id IN (SELECT UserOrGroupId FROM GroupMember WHERE Group.DeveloperName IN :gpUsers.keySet())]) 
        {
            gpUserIsPausedMap.put(u.Id, u.Pause_Assignments__c);
        }
        
        return gpUserIsPausedMap;
    }

    /**
     * Refresh user data that is visible in the component
     */
    @AuraEnabled
    public static List<User> refreshUserData(Object data){
        System.debug('refresh user data');
        try {
            List<User> users = (List<User>)JSON.deserialize(
                JSON.serialize(data), 
                List<User>.class
            );
            Map<Id, User> userMap = new Map<Id, User>(users);

            return [SELECT Id, FirstName, LastName, Name, Email, Pause_Assignments__c, IsActive 
                    FROM User WHERE Id IN: userMap.keySet()];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
