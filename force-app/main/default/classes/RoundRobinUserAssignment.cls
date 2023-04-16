/**
 * @description       : 
 * @author            : LZhao
 * @group             : 
 * @last modified on  : 12-07-2021
 * @last modified by  : LZhao
**/
public without sharing class RoundRobinUserAssignment {

    static final String NO_RR_USERS = 'No active and non-paused Round Robin users were found';
    List<SObject> records = new List<SObject>();
    List<Round_Robin_User__c> roundRobinUsers = new List<Round_Robin_User__c>();
    Map<Id, Round_Robin_User__c> assignedRRUsers = new Map<Id, Round_Robin_User__c>();

    Map<String, Map<String, List<SObject>>> recordsByRoleTerr = new Map<String, Map<String, List<SObject>>>();
    Map<String, Map<String, List<Round_Robin_User__c>>> usersByRoleTerr = new Map<String, Map<String, List<Round_Robin_User__c>>>();

    List<Round_Robin_User__c> postProcessedUsers = new List<Round_Robin_User__c>();

    Integer roundRobinUserLstIdx = 0;
    
    /**
     * Still here for backwards compatibility
     */
    public RoundRobinUserAssignment(List<SObject> records, List<Round_Robin_User__c> roundRobinUsers) {
        this.records = records;
        this.roundRobinUsers = roundRobinUsers;
    }

    /**
     * New constructor added to remove burden of processing maps and loops in other classes
     */
    public RoundRobinUserAssignment(Map<String, Map<String, List<SObject>>> recordsByRoleTerr, Map<String, Map<String, List<Round_Robin_User__c>>> usersByRoleTerr) {
        this.recordsByRoleTerr = recordsByRoleTerr;
        this.usersByRoleTerr = usersByRoleTerr;
    }

    
    public List<Round_Robin_User__c> roundRobinAssignUser() {
        try {
            Integer sendToEnd = roundRobinUsers.size();
            for(SObject record : this.records) {
                Round_Robin_User__c roundRobinUser = getNextRRUser();
                record.put('OwnerId',  roundRobinUser.User__c);

                roundRobinUser.Round_Robin_Number__c = sendToEnd++;

                assignedRRUsers.put(roundRobinUser.Id, roundRobinUser);
            }
        } catch (Exception e) {
            System.debug(e.getCause());
            System.debug(e.getMessage());
            System.debug(e.getStackTraceString());
        }

        return assignedRRUsers.values();
    }

    /**
     * Overloads roundRObinAssignUser() to work through consolidated maps of
     * territories to roles to sobjects and users
     */
    public void runRoundRobinAssignUser() {
        
        for(String ttyName : recordsByRoleTerr.keySet()) {
            Map<String, List<SOBject>> recordsByRole = recordsByRoleTerr.get(ttyName);
            Map<String, List<Round_Robin_User__c>> usersByRole = usersByRoleTerr.get(ttyName);

            for(String role : recordsByRole.KeySet()) {
                List<SOBject> records = recordsByRole.get(role);
                List<Round_Robin_User__c> users = usersByRole.get(role);
                this.records = records;
                this.roundRobinUsers = users;
                postProcessedUsers.addAll(roundRobinAssignUser());
            }
        }
        finalize();

    }

    public Round_Robin_User__c getNextRRUser() {

        Round_Robin_User__c nextRoundRobinUser;
        if(roundRobinUserLstIdx == roundRobinUsers.size()) {
            roundRobinUserLstIdx = 0;
        }
            
        nextRoundRobinUser = roundRobinUsers.get(roundRobinUserLstIdx);
        roundRobinUserLstIdx++;

        if(nextRoundRobinUser.User_Paused__c) {
            return getNextRRUser();
        }

        return nextRoundRobinUser;
    }

    public void finalize() {
        upsert postProcessedUsers;
    }

}