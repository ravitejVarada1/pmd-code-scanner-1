/**
 * @description       : 
 * @author            : 
 * @group             : 
 * @last modified on  :
 * @last modified by  : 
**/
public class CaseTaskCreationProcessor {
    
    public static void createIntegrityCaseTask(List<Case> newCaseList) {
        List<Task> newTaskList = new List<Task>();
        for(Case c: newCaseList){
            
            Task Pendinginvestigationalert = new Task();
            Pendinginvestigationalert.WhatId = c.Id;
            Pendinginvestigationalert.Subject = 'Pending Investigation Alert';
            Pendinginvestigationalert.OwnerId = c.OwnerID;
            newTaskList.add(Pendinginvestigationalert);
            
            Task Research = new Task();
            Research.WhatId = c.Id;
            Research.Subject = 'Research';
            Research.OwnerId = c.OwnerID;
            newTaskList.add(Research);
            
            Task FinalResult = new Task();
            FinalResult.WhatId = c.Id;
            FinalResult.Subject = 'Final Result/How to Resolve';
            FinalResult.OwnerId = c.OwnerID;
            newTaskList.add(FinalResult);
        }
        
        insert newTaskList;
    }

    public static List<Task> createDigitalDealGeoExpansionCaseTasks(List<Case> newCaseList) {

        List<Task> tasksToInsert = new List<Task>();
        List<String> deactivationSubjects = new List<String>{'Digital Deal Deactivation', 'Geo Expansion Deactivation'};
        List<String> activationSubjects = new List<String>{'Digital Deal Activation', 'Geo Expansion Activation'};

        for(Case c : newCaseList) {

            Id caseId = c.Id;
            Id caseOwner = c.OwnerId;

            for(String s : c.Reason == 'Product Activation' ? activationSubjects : deactivationSubjects) {
                tasksToInsert.add(createTask(caseId, caseOwner, s));
            }
        }

        return tasksToInsert;
    }

    private static Task createTask(Id caseId, Id ownerId, String subject) {
        Task tempTask = new Task();
        tempTask.WhatId = caseId;
        tempTask.OwnerId = ownerId;
        tempTask.Subject = subject;
        return tempTask;
    }

}