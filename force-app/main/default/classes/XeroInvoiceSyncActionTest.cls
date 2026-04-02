/**
 * @author Cosimo
 * @description Unit tests for XeroInvoiceSyncAction using reusable HttpCalloutMock implementations in XeroHttpMocks.
 */
@IsTest
private class XeroInvoiceSyncActionTest {

    @testSetup 
    static void setup() {
        Account acc = new Account(Name='Test Account for Xero Invoices');
        insert acc;       
    }

    /**
     * @description Happy path: two invoices returned, queueable enqueued and performs upsert by Invoice_Number__c.
     */
    @IsTest
    static void testRun_Success_Upsert() {
        // Prepare Account records with Xero_Id__c values that match the Contact.ContactID values in the Success mock
        Account acc1 = new Account(Name = 'Acme One', Xero_Id__c = 'XERO-ACC-001');
        Account acc2 = new Account(Name = 'Acme Two', Xero_Id__c = 'XERO-ACC-002');
        insert new List<Account>{ acc1, acc2 };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());

        XeroInvoiceSyncAction.Request r = new XeroInvoiceSyncAction.Request();
        r.overrideLastModifiedUtc = '2025-01-01T00:00:00';

        List<XeroInvoiceSyncAction.Result> results =
            XeroInvoiceSyncAction.run(new List<XeroInvoiceSyncAction.Request>{ r });

        // Run the enqueued queueable
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        XeroInvoiceSyncAction.Result res = results[0];
        System.assertEquals('2025-01-01T00:00:00', res.lastModifiedUsed, 'Timestamp should echo input override');
        System.assert(res.messages != null && res.messages.contains('Xero invoice sync enqueued for processing.'),
            'Should acknowledge enqueue');

        // Spot-check records exist after queueable ran (by Invoice_Number__c if present)
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Invoice_Number__c')) {
            List<Invoice__c> created = [
                SELECT Id, Invoice_Number__c, Account__c
                FROM Invoice__c
                WHERE Invoice_Number__c IN ('INV-001','INV-002')
                ORDER BY Invoice_Number__c
            ];
            System.assertEquals(2, created.size(), 'Two Invoice__c records should exist by Invoice_Number__c');

            Map<String, Id> invNumToAccount = new Map<String, Id>{
                'INV-001' => acc1.Id,
                'INV-002' => acc2.Id
            };

            for (Invoice__c invRec : created) {
                System.assertNotEquals(null, invRec.Account__c, 'Account__c should be populated from Xero_Id__c mapping');
                System.assertEquals(invNumToAccount.get(invRec.Invoice_Number__c), invRec.Account__c,
                    'Account__c should match the Account resolved by Xero_Id__c');
            }
        } else {
            List<Invoice__c> created = [SELECT Id, Name, Account__c FROM Invoice__c WHERE Name IN ('INV-001','INV-002')];
            System.assertEquals(2, created.size(), 'Two Invoice__c records should exist (fallback Name)');
            System.assertEquals(true, created[0].Account__c != null && created[1].Account__c != null,
                'Account__c should be populated from Xero_Id__c mapping');
        }
    }

    /**
     * @description Error path: invoices endpoint returns non-200; queueable should log an error.
     */
    @IsTest
    static void testRun_CalloutError() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());

        XeroInvoiceSyncAction.Request r = new XeroInvoiceSyncAction.Request();
        r.overrideLastModifiedUtc = '2025-01-01T00:00:00';

        List<XeroInvoiceSyncAction.Result> results =
            XeroInvoiceSyncAction.run(new List<XeroInvoiceSyncAction.Request>{ r });

        // Execute the queueable within the test context
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        XeroInvoiceSyncAction.Result res = results[0];
        System.assert(res.messages != null && res.messages.contains('Xero invoice sync enqueued for processing.'),
                      'Ack message should be present');

        // Verify an Error_Log__c was created by the queueable
        List<Error_Log__c> errs = [SELECT Id, Error_Message__c, Type__c FROM Error_Log__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assertEquals(true, errs.size() > 0, 'An error log should be inserted by queueable');
        System.assert(errs[0].Error_Message__c != null && errs[0].Error_Message__c.startsWith('Xero Invoice Sync:'),
                      'Error message should be prefixed as expected');
        System.assertEquals('Apex', errs[0].Type__c, 'Type should be Apex');
    }

    /**
     * @description No invoices case: mock returns empty list; queueable runs and no DML or error logs occur.
     */
    @IsTest
    static void testRun_NoInvoices() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());

        List<XeroInvoiceSyncAction.Result> results =
            XeroInvoiceSyncAction.run(new List<XeroInvoiceSyncAction.Request>{ new XeroInvoiceSyncAction.Request() });

        // Execute enqueued job
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One result expected');
        XeroInvoiceSyncAction.Result res = results[0];
        System.assert(res.messages != null && res.messages.contains('Xero invoice sync enqueued for processing.'), 'Ack message present');

        // Ensure the queueable did not insert error logs when there are simply no invoices
        Integer errorCount = [SELECT COUNT() FROM Error_Log__c];
        System.assertEquals(0, errorCount, 'No error logs should be inserted for empty payload');
    }
}