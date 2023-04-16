@isTest
private class ServiceProviderFunctions_Test {

    @TestSetup
    static void makeData(){

        Test.startTest();
        Account[] dealerAccts = TestDataFactory.createAccounts(3);
        insert dealerAccts;

        Service_Provider__c[] insertSPs = new List<Service_Provider__c>();
        List<Service_Provider__c> sps = TestDataFactory.createSPForAccount(dealerAccts);
        for (Integer i=0; i< dealerAccts.size(); i++) {
            if (i == 0) {
                sps[i].Service_Provider_Id__c = 11111;
                sps[i].Used_Inventory_Avg_Last_Updated__c = date.today();
                sps[i].Used_Inventory_Avg_Daily_Numbers__c = '5;5;6';
                sps[i].Used_Inventory_Avg__c = 5;
                
            } else if (i == 1) {                
                sps[i].Service_Provider_Id__c = 22222;
                sps[i].Used_Inventory_Avg_Last_Updated__c = date.today().addDays(-1);
                sps[i].Used_Inventory_Avg_Daily_Numbers__c = '1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20;21;22;23;24;25;26;27;28;29;30;31;'+
                        '32;33;34;35;36;37;38;39;40;41;42;43;44;45;46;47;48;49;50;51;52;53;54;55;56;57;58;59;60;61;62;63;64;65;66;67;68;69;70;71;' +
                        '72;73;74;75;76;77;78;79;80;81;82;83;84;85;86;87;88;89;90;91;92;93;94;95;96;97;98;99;100;101;102;103;104;105;106;107;108;' +
                        '109;110;111;112;113;114;115;116;117;118;119;120;121;122;123;124;125;126;127;128;129;130;131;132;133;134;135;136;137;138;' +
                        '139;140;141;142;143;144;145;146;147;148;149;150;151;152;153;154;155;156;157;158;159;160;161;162;163;164;165;166;167;168;' +
                        '169;170;171;172;173;174;175;176;177;178;179;180';
                sps[i].Total_Used_Inventory_Units__c = 180;
            } else {
                sps[i].Service_Provider_Id__c = 33333;
                sps[i].Total_Used_Inventory_Units__c = 10;
            }
            insertSPs.add(sps[i]);
        }
        insert insertSPs;
        Test.stopTest();
    }

    private static testMethod void batchTest() {
        
        Test.startTest();
        Database.executeBatch(new Batch_UpdateUsedInvAverage());
        Test.stopTest();

        Service_Provider__c[] results = [select Id, Used_Inventory_Avg__c, Used_Inventory_Avg_Last_Updated__c, Service_Provider_Id__c from Service_Provider__c];

        for (Service_Provider__c sp : results) {
            system.assert(sp.Used_Inventory_Avg_Last_Updated__c == date.today());
            if (sp.Service_Provider_Id__c == 11111) {
                system.assert(sp.Used_Inventory_Avg__c == 5);
            } else if (sp.Service_Provider_Id__c == 22222) {
                system.assert(sp.Used_Inventory_Avg__c == 90);
            } else {
                system.assert(sp.Used_Inventory_Avg__c == 10);
            }
        }

    }

    private static testMethod void scheduleTest() {

        Test.startTest();
        string cron = '0 0 5 * * ?';
        System.schedule('daily inventory avg calculator', cron, new Batch_UpdateUsedInvAverage());
        Test.stopTest();

    }

    private static testMethod void functionTest() {

        Test.startTest();
        Service_Provider__c[] sps = [SELECT Id, Used_Inventory_Avg_Last_Updated__c, Total_Used_Inventory_Units__c,
                                    Used_Inventory_Avg_Daily_Numbers__c, Used_Inventory_Avg__c
                                    FROM Service_Provider__c WHERE reviewStatus__c != 'DENIED'];
        ServiceProviderFunctions.updateAverageInventory(sps);
        Test.stopTest();

        Service_Provider__c[] results = [select Id, Used_Inventory_Avg__c, Used_Inventory_Avg_Last_Updated__c, Service_Provider_Id__c from Service_Provider__c];

        for (Service_Provider__c sp : results) {
            system.assert(sp.Used_Inventory_Avg_Last_Updated__c == date.today());
            if (sp.Service_Provider_Id__c == 11111) {
                system.assert(sp.Used_Inventory_Avg__c == 5);
            } else if (sp.Service_Provider_Id__c == 22222) {
                system.assert(sp.Used_Inventory_Avg__c == 90);
            } else {
                system.assert(sp.Used_Inventory_Avg__c == 10);
            }
        }
    }

}