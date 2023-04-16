global with sharing class QuoteCalculatorCallback implements SBQQ.CalculateCallback {
    
    global void callback(String quoteJSON){
        SBQQ.ServiceRouter.save('SBQQ.QuoteAPI.QuoteSaver', quoteJSON);
        System.debug('@quoteJSON ' + JSON.serializePretty(quoteJSON));
    }
}