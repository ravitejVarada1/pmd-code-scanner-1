/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
*
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* author:         nsingh
* created:        07/22/2022
* created jira:   BR-8810
* ──────────────────────────────────────────────────────────────────────────────────────────────────
*/
public class QuoteCalculatorOperation implements Queueable, Database.AllowsCallouts {
    
    private Id quoteId;

    public QuoteCalculatorOperation(Id quoteId) {
        this.quoteId = quoteId;
    }
    
    public void execute(QueueableContext context) {
        QuoteModel qModel = new QuoteModel();
        String quoteJSON = SBQQ.ServiceRouter.read('SBQQ.QuoteAPI.QuoteReader',quoteId);
        qModel = (QuoteModel)JSON.deserialize(quoteJSON, QuoteModel.class);
        
        QuoteCalculator qCalc = new QuoteCalculator();
        qCalc.calculate(qModel,'QuoteCalculatorCallback');
    }
}