@IsTest
private class OpportunityLineItemHandlerTest {

    // Helper to create base data: standard pricebook + opp
    private static Id setupStandardPricebook() {
        return Test.getStandardPricebookId();
    }

    private static Opportunity createOpportunity(Id pricebookId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Pricebook2Id = pricebookId
        );
        insert opp;
        return opp;
    }

    private static PricebookEntry createPbe(Id pricebookId, String productName, String category) {
        Product2 prod = new Product2(
            Name = productName,
            IsActive = true,
            Product_Category__c = category
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        return pbe;
    }

    @IsTest
    static void testSameCategoryAllowed() {
        Id stdPbId = setupStandardPricebook();
        Opportunity opp = createOpportunity(stdPbId);

        PricebookEntry pbeCatA = createPbe(stdPbId, 'Prod A1', 'Payroll Services');

        // Two lines, same category, same opp
        OpportunityLineItem oli1 = new OpportunityLineItem(
            OpportunityId   = opp.Id,
            PricebookEntryId= pbeCatA.Id,
            Quantity        = 1,
            UnitPrice       = 100
        );
        OpportunityLineItem oli2 = new OpportunityLineItem(
            OpportunityId   = opp.Id,
            PricebookEntryId= pbeCatA.Id,
            Quantity        = 2,
            UnitPrice       = 100
        );

        List<OpportunityLineItem> newLines = new List<OpportunityLineItem>{ oli1, oli2 };

        Test.startTest();
        OpportunityLineItemHandler.preventMixedProductCategories(newLines);
        Database.SaveResult[] results = Database.insert(newLines, false);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Expected two save results');
        System.assert(results[0].isSuccess(), 'First line should be allowed');
        System.assert(results[1].isSuccess(), 'Second line with same category should be allowed');
    }

    @IsTest
    static void testDifferentCategoriesBlocked() {
        Id stdPbId = setupStandardPricebook();
        Opportunity opp = createOpportunity(stdPbId);

        PricebookEntry pbeCatA = createPbe(stdPbId, 'Prod A', 'Payroll Technology');
        PricebookEntry pbeCatB = createPbe(stdPbId, 'Prod B', 'HR Services');

        // First line CatA, second line CatB -> second should be blocked
        OpportunityLineItem oli1 = new OpportunityLineItem(
            OpportunityId   = opp.Id,
            PricebookEntryId= pbeCatA.Id,
            Quantity        = 1,
            UnitPrice       = 100
        );
        OpportunityLineItem oli2 = new OpportunityLineItem(
            OpportunityId   = opp.Id,
            PricebookEntryId= pbeCatB.Id,
            Quantity        = 1,
            UnitPrice       = 100
        );

        List<OpportunityLineItem> newLines = new List<OpportunityLineItem>{ oli1, oli2 };

        Test.startTest();
        OpportunityLineItemHandler.preventMixedProductCategories(newLines);
        Database.SaveResult[] results = Database.insert(newLines, false);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Expected two save results');

        // First line should succeed
        System.assert(results[0].isSuccess(), 'First line (CatA) should be allowed');

        // Second line should fail with mixed-category error
        System.assert(!results[1].isSuccess(), 'Second line (CatB) should be blocked');
        System.assertEquals(
            'You can only add products from a single Product Category at the time',
            results[1].getErrors()[0].getMessage(),
            'Error message should match handler logic'
        );
    }

    @IsTest
    static void testNoCategoryBlocked() {
        Id stdPbId = setupStandardPricebook();
        Opportunity opp = createOpportunity(stdPbId);

        // Product with no Product_Category__c (null)
        Product2 prodNoCat = new Product2(
            Name = 'No Cat Product',
            IsActive = true
            // Product_Category__c left null
        );
        insert prodNoCat;

        PricebookEntry pbeNoCat = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prodNoCat.Id,
            UnitPrice    = 50,
            IsActive     = true
        );
        insert pbeNoCat;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId    = opp.Id,
            PricebookEntryId = pbeNoCat.Id,
            Quantity         = 1,
            UnitPrice        = 50
        );

        List<OpportunityLineItem> newLines = new List<OpportunityLineItem>{ oli };

        Test.startTest();
        OpportunityLineItemHandler.preventMixedProductCategories(newLines);
        Database.SaveResult[] results = Database.insert(newLines, false);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one save result');
        System.assert(!results[0].isSuccess(), 'Line with no category should be blocked');
        System.assertEquals(
            'Product has no Product Category, cannot be added to this Opportunity.',
            results[0].getErrors()[0].getMessage(),
            'Error message should match handler logic for missing category'
        );
    }

    @IsTest
    static void testNullAndEmptyInputs() {
        // Just make sure there are no exceptions and branches are covered
        OpportunityLineItemHandler.preventMixedProductCategories(null);
        OpportunityLineItemHandler.preventMixedProductCategories(
            new List<OpportunityLineItem>()
        );

        // If we get here, test passed (no unhandled exceptions)
        System.assert(true, 'Method should safely handle null and empty lists.');
    }
}