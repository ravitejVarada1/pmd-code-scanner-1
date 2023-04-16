({
	closeQA : function(component, event, helper) {
		// refresh the page
		console.log('aura component');
		$A.get('e.force:refreshView').fire();
		$A.get("e.force:closeQuickAction").fire();
	}
})