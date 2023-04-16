@isTest
private class QuoteVal_QuoteDataObject_Test {

    @isTest
    static void test1(){
        QuoteVal_QuoteDataObject qdo = new QuoteVal_QuoteDataObject();
        QuoteVal_LocationDataObject ldo = qdo.getLocationData('0014S000007mjo9QAA');
        System.assertEquals(true, ldo != null);
    }

}