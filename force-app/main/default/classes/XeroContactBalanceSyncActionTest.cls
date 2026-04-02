/**
 * @author Cosimo
 * @description Unit tests for XeroContactBalanceSyncAction using reusable HttpCalloutMock implementations in XeroHttpMocks.
 */
@IsTest
private class XeroContactBalanceSyncActionTest {

    @testSetup 
    static void setup() {
        Account acc1 = new Account(Name='Test Account 1', Xero_Id__c = '220ddca8-3144-4085-9a88-2d72c5133734');
        Account acc2 = new Account(Name='Test Account 2', Xero_Id__c = '88192a99-cbc5-4a66-bf1a-2f9fea2d36d0');
        insert new List<Account>{ acc1, acc2 };       
    }

    /**
     * @description Happy path: two contacts returned, queueable enqueued and updates Account.CurrencyIsoCode.
     */
    @IsTest
    static void testRun_Success_UpdateCurrency() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());

        XeroContactBalanceSyncAction.Request r = new XeroContactBalanceSyncAction.Request();
        r.accountXeroIds = new List<String>{ '220ddca8-3144-4085-9a88-2d72c5133734', '88192a99-cbc5-4a66-bf1a-2f9fea2d36d0' };

        List<XeroContactBalanceSyncAction.Result> results =
            XeroContactBalanceSyncAction.run(new List<XeroContactBalanceSyncAction.Request>{ r });

        // Run the enqueued queueable
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        XeroContactBalanceSyncAction.Result res = results[0];
        System.assert(res.messages != null && res.messages.contains('Enqueued 1 batch(es) for 2 Xero IDs.'),
            'Should acknowledge batch enqueue');

        // Verify Accounts were updated
        List<Account> updated = [SELECT Id, CurrencyIsoCode, Xero_Id__c FROM Account WHERE Xero_Id__c IN ('220ddca8-3144-4085-9a88-2d72c5133734', '88192a99-cbc5-4a66-bf1a-2f9fea2d36d0')];
        System.assertEquals(2, updated.size(), 'Two Accounts should be found');

        Map<String, String> xeroToCurrency = new Map<String, String>{
            '220ddca8-3144-4085-9a88-2d72c5133734' => 'USD',
            '88192a99-cbc5-4a66-bf1a-2f9fea2d36d0' => 'EUR'
        };

        for (Account acc : updated) {
            System.assertEquals(xeroToCurrency.get(acc.Xero_Id__c), acc.CurrencyIsoCode, 'CurrencyIsoCode should match DefaultCurrency from Xero');
        }
    }

    /**
     * @description Batching test: 12 IDs should create 2 batches.
     */
    @IsTest
    static void testRun_Batching() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());

        XeroContactBalanceSyncAction.Request r = new XeroContactBalanceSyncAction.Request();
        // 12 IDs should create 2 batches (10 + 2)
        List<String> ids = new List<String>();
        for (Integer i = 0; i < 12; i++) {
            ids.add('id-' + i);
        }
        r.accountXeroIds = ids;

        List<XeroContactBalanceSyncAction.Result> results =
            XeroContactBalanceSyncAction.run(new List<XeroContactBalanceSyncAction.Request>{ r });

        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        XeroContactBalanceSyncAction.Result res = results[0];
        System.assert(res.messages != null && res.messages.contains('Enqueued 2 batch(es) for 12 Xero IDs.'),
            'Should acknowledge 2 batches');
    }

    /**
     * @description Edge case: blank/null IDs should be filtered out.
     */
    @IsTest
    static void testRun_FilterBlanks() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());

        XeroContactBalanceSyncAction.Request r = new XeroContactBalanceSyncAction.Request();
        r.accountXeroIds = new List<String>{ '', 'valid-id-1', null, 'valid-id-2', '' };

        List<XeroContactBalanceSyncAction.Result> results =
            XeroContactBalanceSyncAction.run(new List<XeroContactBalanceSyncAction.Request>{ r });

        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        XeroContactBalanceSyncAction.Result res = results[0];
        System.assert(res.messages != null && res.messages.contains('Enqueued 1 batch(es) for 2 Xero IDs.'),
            'Should acknowledge 2 valid IDs');
    }

    /**
     * @description Error path: no IDs provided.
     */
    @IsTest
    static void testRun_NoIds() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());

        XeroContactBalanceSyncAction.Request r = new XeroContactBalanceSyncAction.Request();
        r.accountXeroIds = new List<String>(); // empty

        List<XeroContactBalanceSyncAction.Result> results =
            XeroContactBalanceSyncAction.run(new List<XeroContactBalanceSyncAction.Request>{ r });

        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        XeroContactBalanceSyncAction.Result res = results[0];
        System.assert(res.messages != null && res.messages.contains('No Xero IDs provided.'),
            'Should acknowledge empty input');
    }
}