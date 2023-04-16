({
    doInit: function (component, event, helper) {
        let objId = component.get('v.recordId'); 
    },
    
    closeQA : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
    },
    refreshView: function(component, event) {
        // refresh the view
        $A.get('e.force:refreshView').fire();
    }
})