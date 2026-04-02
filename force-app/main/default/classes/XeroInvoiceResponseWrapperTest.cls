@IsTest
private class XeroInvoiceResponseWrapperTest {

    @IsTest
    static void parse_minimal_valid_structure() {
        String jsonStr = '{' +
            '"Invoices": [' +
                '{' +
                    '"CurrencyCode": "USD",' +
                    '"UpdatedDateUTC": "2024-09-23T12:34:56",' +
                    '"Total": 123.45,' +
                    '"TotalTax": 23.45,' +
                    '"SubTotal": 100.00,' +
                    '"LineAmountTypes": "Exclusive",' +
                    '"Status": "AUTHORISED",' +
                    '"FullyPaidOnDate": "/Date(1730937600000)/",' +
                    '"DueDate": "2024-10-10",' +
                    '"DueDateString": "2024-10-10",' +
                    '"InvoiceDate": "2024-09-20",' +
                    '"DateString": "2024-09-20",' +
                    '"Contact": {' +
                        '"HasValidationErrors": false,' +
                        '"Name": "Acme Corp",' +
                        '"ContactID": "001xx000003DHPaAAO"' +
                    '},' +
                    '"HasErrors": false,' +
                    '"HasAttachments": false,' +
                    '"IsDiscounted": false,' +
                    '"CurrencyRate": 1.0,' +
                    '"AmountCredited": 0,' +
                    '"AmountPaid": 0,' +
                    '"AmountDue": 123.45,' +
                    '"Reference": "REF-123",' +
                    '"InvoiceNumber": "INV-001",' +
                    '"InvoiceID": "inv-1",' +
                    '"Type": "ACCREC"' +
                '}' +
            ']' +
        '}';

        XeroInvoiceResponseWrapper wrap = XeroInvoiceResponseWrapper.parse(jsonStr);
        System.assertNotEquals(null, wrap, 'Wrapper should be parsed');
        System.assertNotEquals(null, wrap.Invoices, 'Invoices list should not be null');
        System.assertEquals(1, wrap.Invoices.size(), 'Should parse one invoice');

        XeroInvoiceResponseWrapper.Invoice inv = wrap.Invoices[0];
        System.assertEquals('USD', inv.CurrencyCode);
        System.assertEquals('AUTHORISED', inv.Status);
        System.assertEquals('Exclusive', inv.LineAmountTypes);
        System.assertEquals('INV-001', inv.InvoiceNumber);
        System.assertEquals('ACCREC', inv.Type);
        System.assertEquals('2024-10-10', inv.DueDateString);
        System.assertEquals(123.45, inv.Total);
        System.assertEquals(23.45, inv.TotalTax);
        System.assertEquals(100.00, inv.SubTotal);
        System.assertEquals(123.45, inv.AmountDue);
        System.assertEquals(0, inv.AmountPaid);
        System.assertEquals(0, inv.AmountCredited);

        System.assertNotEquals(null, inv.Contact, 'Contact should be parsed');
        System.assertEquals('Acme Corp', inv.Contact.Name);
        System.assertEquals('001xx000003DHPaAAO', inv.Contact.ContactID);
        System.assertEquals(false, inv.Contact.HasValidationErrors);
    }

    @IsTest
    static void parse_empty_payload() {
        String jsonStr = '{ "Invoices": [] }';
        XeroInvoiceResponseWrapper wrap = XeroInvoiceResponseWrapper.parse(jsonStr);
        System.assertNotEquals(null, wrap, 'Wrapper should not be null even if empty');
        System.assertNotEquals(null, wrap.Invoices, 'Invoices list should be initialized');
        System.assertEquals(0, wrap.Invoices.size(), 'No invoices expected');
    }

    @IsTest
    static void parse_missing_invoices_field() {
        // Missing "Invoices" entirely; JSON still maps, list stays null
        String jsonStr = '{ "someOtherField": 1 }';
        XeroInvoiceResponseWrapper wrap = XeroInvoiceResponseWrapper.parse(jsonStr);
        // Depending on deserialization, Invoices may be null. Assert it is null in this case.
        System.assertEquals(null, wrap.Invoices, 'Invoices should be null if absent in JSON');
    }

    @IsTest
    static void parse_partial_invoice_fields() {
        // Provide only a subset of invoice fields to ensure graceful handling
        String jsonStr = '{ "Invoices": [ { "InvoiceNumber": "INV-002", "Total": 10 } ] }';
        XeroInvoiceResponseWrapper wrap = XeroInvoiceResponseWrapper.parse(jsonStr);
        System.assertNotEquals(null, wrap);
        System.assertEquals(1, wrap.Invoices.size());
        System.assertEquals('INV-002', wrap.Invoices[0].InvoiceNumber);
        System.assertEquals(10, wrap.Invoices[0].Total);
        System.assertEquals(null, wrap.Invoices[0].Contact, 'Contact should be null when not provided');
    }
}