public class AmazingAmend {
    @AuraEnabled
    public static String amendContract(String contractIds) {
        system.debug('contractId'+contractIds);
       ContractAmender contractAmender = new ContractAmender();
       QuoteModel quoteModel = contractAmender.amend(contractIds);
        return quoteModel.record.Id;
    }
}