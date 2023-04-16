/*
* author:         alaplante
* modifiedBy:     
* created:        11/11/2021
* modified:       
* created jira:   BR-4432
*/


public class CaseCommentTriggerFunctions {

    /**
     * Checks if the user has custom permission to delete internal case comments before allowing.
     */
    public static void checkDeletePermissions(Map<Id,CaseComment> commentMap) {

        // get parent case ids in list
        List<Id> parentCases = returnParentIdList(commentMap);

        // check if user has custom permission to delete internal case comments
        Boolean canDelete = Utilities.checkCustomPermission('Allow_Internal_Case_Comment_Deletion');

        // use parentids to construct case category map
        Map<Id, Case> caseCategoryMap = new Map<Id, Case>([SELECT Id, Origin FROM Case WHERE Id in: parentCases]);

        // loop through comments in trigger execution
        for(CaseComment cc: commentMap.values()) {
          // if parent case origin contains 'internal' and profile is not allowed to delete internal case comments
          if (caseCategoryMap.get(cc.ParentId).Origin.toLowerCase().contains('internal') && !canDelete){
              // throw error that this user is not allowed to delete internal case comments
              cc.adderror('Internal Case comments can only be deleted by those with the "Allow_Internal_Case_Comment_Deletion" custom permission. Please contact your System Administrator if needed.');
          }
        } 
    }

    /**
     * Checks if the user has custom permission to edit internal case comments before allowing.
     */
    public static void checkEditPermissions(Map<Id,CaseComment> commentMap) {

        // get parent case ids in list
        List<Id> parentCases = returnParentIdList(commentMap);

        // check if user has custom permission to edit internal case comments
        Boolean canEdit = Utilities.checkCustomPermission('Allow_Internal_Case_Comment_Editing');

        // use parentids to construct case category map
        Map<Id, Case> caseCategoryMap = new Map<Id, Case>([SELECT Id, Origin FROM Case WHERE Id in: parentCases]);

        // loop through comments in trigger execution
        for(CaseComment cc: commentMap.values()) {
          // if parent case origin contains 'internal' and profile is not allowed to edit internal case comments
          if (caseCategoryMap.get(cc.ParentId).Origin.toLowerCase().contains('internal') && !canEdit){
              // throw error that this user is not allowed to edit internal case comments
              commentMap.get(cc.Id).adderror('Internal Case comments can only be edited by those with the "Allow_Internal_Case_Comment_Editing" custom permission. Please contact your System Administrator if needed.');
          }
        } 
    }

    /**
     * Grabs parent case ids from case comment map and returns in list.
     */

    private static List<Id> returnParentIdList(Map<Id,CaseComment> commentMap) {
        List<Id> parentCaseIds = new List<Id>();
        for (CaseComment cc : commentMap.values()) {
            parentCaseIds.add(cc.ParentId);
        }
        return parentCaseIds;
    }
}