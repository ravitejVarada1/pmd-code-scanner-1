({
    doInit: function (component, event, helper) {
        var recordTypeId = component.get( "v.pageReference" ).state.recordTypeId;
        component.set("v.setMeOnInit", recordTypeId);
      },
      reInit : function(component, event, helper) {
        $A.get('e.force:refreshView').fire();
    }
           
})