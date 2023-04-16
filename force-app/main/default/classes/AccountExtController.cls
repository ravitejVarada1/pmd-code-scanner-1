public with sharing class AccountExtController {
	private Id accountId;
	public AccountExtController(ApexPages.StandardController stdController) {
		accountId = stdController.getId();
	}
	public PageReference onSubmit() {
		if (AccountId != null) {
			SBAA.ApprovalAPI.submit(accountId, SBAA__Approval__c.Accountapproval__c);
		}
		return new PageReference('/' + accountId);
	}
	public PageReference onRecall() {
		if (accountId != null) {
			SBAA.ApprovalAPI.recall(accountId, SBAA__Approval__c.Accountapproval__c);
		}
		return new PageReference('/' + accountId);
	}
}