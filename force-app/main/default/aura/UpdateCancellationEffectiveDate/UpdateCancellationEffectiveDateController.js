({
    doInit: function (component, event, helper) {
        const objId = component.get('v.recordId');
        console.log('in AuraCmp, quote id: ', objId);
        
        //console.log('PageReference Attrib: ' + component.get('v.pageReference').state.c__quoteId);        

      },

      closeQA : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
      },
      refreshView: function(component, event) {
        // refresh the view
        $A.get('e.force:refreshView').fire();
    }
})