/**
 * @description       : Apex class to contain common methods used in co-op program development
 * @author            : Navdeep
 * @group             : SA-297 Co-Op Program Development
**/
public without sharing class CoOpProgramUtils{

    public static Map<String,List<Set<String>>> getOEMSponsorConfiguration(){

        Map<String,List<Set<String>>> programToMakes = new Map<String,List<Set<String>>>();

        for(OEM_Sponsor_Mapping__mdt oemSponsorMapping : [
            SELECT Id, OEM_Sponsor_Program__c, Sponsored_Makes__c FROM OEM_Sponsor_Mapping__mdt
        ]){
            if(!programToMakes.containsKey(oemSponsorMapping.OEM_Sponsor_Program__c)){
                programToMakes.put(oemSponsorMapping.OEM_Sponsor_Program__c,new List<Set<String>>());
            }

            oemSponsorMapping.Sponsored_Makes__c = oemSponsorMapping.Sponsored_Makes__c.toLowerCase();
            oemSponsorMapping.Sponsored_Makes__c = oemSponsorMapping.Sponsored_Makes__c.replaceAll('\\s+', '');

            Set<String> sponsoredMakes = new Set<String>(oemSponsorMapping.Sponsored_Makes__c.split(';'));
            programToMakes.get(oemSponsorMapping.OEM_Sponsor_Program__c).add(sponsoredMakes);
        }
        return programToMakes;
    }

    public static Map<Id,String> getSyncedNewMakesSold(List<Account> validateAccounts){

        Map<Id,String> accIdToNewMakesSolds = new Map<Id,String>();

        for(Service_Provider__c sp : [
            SELECT Id, Account__c, New_Makes_Sold__c 
            FROM Service_Provider__c 
            WHERE (reviewStatus__c=:ConstantsUtil.SP_APPROVED OR reviewStatus__c=:ConstantsUtil.SP_SUBMITTED)
            AND Account__c IN:validateAccounts 
            AND New_Makes_Sold__c!=null
        ]){
            sp.New_Makes_Sold__c = sp.New_Makes_Sold__c.toLowerCase();
            sp.New_Makes_Sold__c = sp.New_Makes_Sold__c.replaceAll('\\s+', '');

            if(!accIdToNewMakesSolds.containsKey(sp.Account__c)){
                accIdToNewMakesSolds.put(sp.Account__c,sp.New_Makes_Sold__c);
            }else{
                String temp = accIdToNewMakesSolds.get(sp.Account__c);
                temp += ','+sp.New_Makes_Sold__c;
                accIdToNewMakesSolds.put(sp.Account__c,temp);
            }
            
        }
        return accIdToNewMakesSolds;
    }

    //SA-295,SA-869
    public static void processCoOpDefaultsAndValidations(Boolean isInsert,List<Account> validateAccounts,List<SBQQ__Quoteline__c> quoteLines,
    Map<Id,SBQQ__Quote__c> quoteMap,Map<Id,String> acctIdToCoOpPrograms,Map<String,Id> coOpProgramToOEMBillAcct,Map<Id,Account> superAccMap,
    Set<Id> cpqAmendmentQuoteIds) {

        Map<Id,String> accIdToNewMakesSolds = getSyncedNewMakesSold(validateAccounts);

        Map<String,List<Set<String>>> programToMakes = getOEMSponsorConfiguration();

        for(SBQQ__Quoteline__c ql : quoteLines){

            //to allow amendment quote creation to add/remove new stores and products
            if(ql.SBQQ__Existing__c && cpqAmendmentQuoteIds.contains(ql.SBQQ__Quote__c)){
                continue;
            }

            if(ql.Fulfillment_Account__c!=null && 
            quoteMap.containsKey(ql.SBQQ__Quote__c) && 
            (isInsert || (!isInsert && ql.SBQQ__Quantity__c > 0))){

                String accountName = superAccMap.containskey(ql.Fulfillment_Account__c) ? superAccMap.get(ql.Fulfillment_Account__c).Name : 'Fulfillment Account';

                String quoteCoOpProgram = quoteMap.get(ql.SBQQ__Quote__c).Co_Op_Program_Opt_in__c;

                if(!acctIdToCoOpPrograms.containsKey(ql.Fulfillment_Account__c)){
                    ql.addError('The selected '+accountName+' has no relation with the Billing Account under the ' + quoteCoOpProgram + ' Co-op Program.');
                }else{

                    String coOpProgramValue = acctIdToCoOpPrograms.get(ql.Fulfillment_Account__c);

                    if(coOpProgramValue.equalsIgnoreCase(quoteCoOpProgram) 
                    && coOpProgramToOEMBillAcct.containsKey(quoteCoOpProgram)){

                        //OEM Makes validation starts
                        if(accIdToNewMakesSolds.containsKey(ql.Fulfillment_Account__c) 
                        && programToMakes.containsKey(quoteCoOpProgram)){

                            Set<String> newMakesList = new Set<String>(accIdToNewMakesSolds.get(ql.Fulfillment_Account__c).split(','));

                            Boolean validateMakes = false;

                            for(Set<String> allowedMakesSet : programToMakes.get(quoteCoOpProgram)){
                                if(allowedMakesSet.containsAll(newMakesList)){
                                    validateMakes = true;
                                    break;
                                }
                            }

                            if(!validateMakes){
                                //throw validation to error out invalid OEM makes against an Account
                                ql.addError('Please check "New Makes Sold" field on the related service providers with this '+accountName+' as it does not satisfy the '+quoteCoOpProgram+' requirements. A separate account needs to be created with the allowed OEM makes.');
                            }
                            //OEM Makes validation ends
                        }

                        ql.Billing_Account__c = coOpProgramToOEMBillAcct.get(quoteCoOpProgram);
                        ql.SBQQ__BillingType__c = ConstantsUtil.OEM_QL_BILLING_TYPE;

                    }else{
                        //throw validation to error out invalid OEM makes against an Account
                        ql.addError('The selected '+accountName+' has no relation with the OEM Account under the ' + quoteCoOpProgram + ' Co-op Program.');
                    }
                }
            }
        }
    }
}