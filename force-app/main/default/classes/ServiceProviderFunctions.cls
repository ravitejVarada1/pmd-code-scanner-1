// Jira: BR-725 
public class ServiceProviderFunctions {


    // updating the Used_Inventory_Avg__c,Used_Inventory_Avg_Daily_Numbers__c field and Used_Inventory_Avg_Last_Updated__c if Used_Inventory_Avg_Last_Updated__c is not equal to todays date
    public static void updateAverageInventory(Service_Provider__c[] sps) {

        Service_Provider__c[] updateSPs = new List<Service_Provider__c>();

        // logic to update the Used_Inventory_Avg__c ,Used_Inventory_Avg_Daily_Numbers__c and  Used_Inventory_Avg_Last_Updated__c field on service provider record
        for (Service_Provider__c sp : sps) {
            // skip the current loop value if inventory avg last date is todays date
            if (sp.Used_Inventory_Avg_Last_Updated__c == Date.today()) { continue; }
            
            // temporary variable to hold Total Used Inventory Units
            Integer currentInv = 0;

            if (sp.Total_Used_Inventory_Units__c != null) { 
                currentInv = Integer.valueOf(sp.Total_Used_Inventory_Units__c); 
            }

            if (sp.Used_Inventory_Avg_Daily_Numbers__c == null) { 
                sp.Used_Inventory_Avg_Daily_Numbers__c = ''; 
            }
            sp.Used_Inventory_Avg_Daily_Numbers__c = String.valueOf(currentInv)+';'+sp.Used_Inventory_Avg_Daily_Numbers__c;
            
            Integer invTotal = 0;
            Integer invDays = 0;

            String[] invStrings = sp.Used_Inventory_Avg_Daily_Numbers__c.split(';');
            
            //removing the data from the invStrings list if size exceeds 180
            while (invStrings.size() > 180) {
                invStrings.remove(180);
            }

            sp.Used_Inventory_Avg_Daily_Numbers__c = String.join(invStrings, ';');
            //logic to count total inventory and inventory days
            for (String s : invStrings) {
                if (s.isNumeric() && Integer.valueOf(s) > 0) {
                    invTotal += Integer.valueOf(s);
                    invDays++;
                }
            }

            sp.Used_Inventory_Avg__c = 0;
            if (invDays > 0) { sp.Used_Inventory_Avg__c = invTotal/invDays; }
            sp.Used_Inventory_Avg_Last_Updated__c = Date.today();
            updateSPs.add(sp);
        }
        //updating the Service Provider record list if not empty
        if (!updateSPs.isEmpty()) {
            update updateSPs;
        }
    }

}