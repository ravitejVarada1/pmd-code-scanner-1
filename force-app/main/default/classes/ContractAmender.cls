/**
* Simple Class to use the ContractAPI to amend a contract
*/
public without sharing class ContractAmender {
    public QuoteModel amend(String contractId) {
        try {
            String quoteJSON = SBQQ.ServiceRouter.load('SBQQ.ContractManipulationAPI.ContractAmender', contractId, null);
            return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
        } catch (Exception e) {
            throw e;
        }
    }
}