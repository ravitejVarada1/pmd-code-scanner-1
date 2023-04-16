public without sharing class RoundRobinLeadHelper {

    //Map to define Queue based on Country Code
    public static Map<String, String> countryCodeQueueMap = new Map<String, String> {
        'US' => 'RR_IST_US',
        'GB' => 'RR_SDR_GB',
        'CA' => 'RR_SDR_CA'
    };

    
    //Leads from the trigger, expected to have the Account field populated
    public static Map<Id, Lead> leadmap = new Map<Id, Lead>(); 
    public static Map<String, Id> grpNameIdMap = getGrpNameToIdMap();

    public static void roundRobinLeads(List<Lead> leads, String defaultQueue) {

        Map<String, List<Lead>> grpToLeadMap = mapRRQueueToLead(leads, defaultQueue);
        Map<String, List<Round_Robin_User__c>> rrGrpToUserMap = 
            RoundRobinUserHelper.getSortedRoundRobinUserMap(grpToLeadMap.keySet());
        
        //collect round robin user updates post assignment so the next time
        //will be sorted in ascending order
        Map<Id, Round_Robin_User__c> rrUsersToUpdate = new Map<Id, Round_Robin_User__c>();

        for (String grpName : grpToLeadMap.keySet()) {

            if (rrGrpToUserMap.get(grpName) != null) { //sanity check, do not send RR if no members

                RoundRobinUserAssignment rrua = new RoundRobinUserAssignment(grpToLeadMap.get(grpName), 
                    rrGrpToUserMap.get(grpName));

                rrUsersToUpdate.putAll(rrua.roundRobinAssignUser());
            }
        }
        if (!rrUsersToUpdate.isEmpty()) {
            upsert rrUsersToUpdate.values();
        }
    }

    public static Map<String, List<Lead>> mapRRQueueToLead(List<Lead> leads, String defaultQueue) {
        Map<String, List<Lead>> grpToLeadMap = new Map<String, List<Lead>>();
        for (Lead ld : leads) {
            String queueName;
            if (defaultQueue != null) {
                queueName = defaultQueue;
            } else {
                queueName = ld.CountryCode != null ? countryCodeQueueMap.get(ld.CountryCode) : 'UNKNOWN';
            }
            
            if (!grpToLeadMap.containsKey(queueName)) {
                grpToLeadMap.put(queueName, new List<Lead>());
            }
            grpToLeadMap.get(queueName).add(ld);
        }
        return grpToLeadMap;
    }
    
    public static Map<String, Id> getGrpNameToIdMap() {
        Map<String, Id> grpNameToIdMap = new Map<String, Id>();
        for(Group grp : [SELECT Id, DeveloperName FROM Group]) {
            grpNameToIdMap.put(grp.DeveloperName, grp.Id);
        }
        return grpNameToIdMap;
    }

    /*//Until we figure out how to query these more efficiently, use the 
    //Country_Code_Territory__mdt that maps country codes with territory names
    public static Map<String, Set<String>> collectSDRQueueNames() {
        Set<String> ldCountryCodes = getLeadCountryCodes();
        
        //maps country code to set of SDR Queue Names
        Map<String, Set<String>> ccLeadQueueNameMap = new Map<String, Set<String>>();

        for (Country_Code_Territory__mdt cct : [SELECT Country_Code__c, SDR_Queue_Name__c
            FROM Country_Code_Territory__mdt WHERE Country_Code__c IN :ldCountryCodes]) {
           
            if (!ccLeadQueueNameMap.containsKey(cct.Country_Code__c)) {
                ccLeadQueueNameMap.put(cct.Country_Code__c, new Set<String>());
            }

            ccLeadQueueNameMap.get(cct.Country_Code__c).add(cct.SDR_Queue_Name__c);
        }

        return ccLeadQueueNameMap;
    }*/
}