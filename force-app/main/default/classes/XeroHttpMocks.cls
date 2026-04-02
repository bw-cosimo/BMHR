/**
 * @author Cosimo
 * @description Reusable HTTP callout mocks for Xero endpoints (/connections and /Invoices).
 */
@IsTest
public class XeroHttpMocks {

    /**
     * @description Success mock: returns a valid tenant from /connections and two invoices from /Invoices.
     * @param req The incoming HTTP request.
     * @return HttpResponse with 200 and a valid JSON body for each endpoint.
     */
    public class Success implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            if (endpoint == null) {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
                return res;
            }
            res.setStatusCode(200);
            if (endpoint.endsWith('/connections')) {
                res.setBody('[{"tenantId":"11111111-2222-3333-4444-555555555555"}]');
                return res;
            }
            else if (endpoint.contains('/Invoices')) {
                String body = '{ "Invoices": [' +
                    '{' +
                      '"CurrencyCode":"HKD",' +
                      '"UpdatedDateUTC":"/Date(1762921553557+0000)/",' +
                      '"Total":100.50,' +
                      '"TotalTax":0.0,' +
                      '"SubTotal":100.50,' +
                      '"LineItems":[],' +
                      '"LineAmountTypes":"Exclusive",' +
                      '"Status":"AUTHORISED",' +
                      '"DueDateString":"2025-10-08T00:00:00",' +
                      '"DateString":"2025-08-31T00:00:00",' +
                      '"Contact":{"Name":"Acme Ltd","ContactID":"XERO-ACC-001"},' +
                      '"CurrencyRate":1.0,' +
                      '"AmountCredited":0.0,' +
                      '"AmountPaid":0.0,' +
                      '"AmountDue":100.50,' +
                      '"Reference":"Monthly",' +
                      '"InvoiceNumber":"INV-001",' +
                      '"InvoiceID":"11111111-aaaa-bbbb-cccc-000000000001",' +
                      '"Type":"ACCREC"' +
                    '},' +
                    '{' +
                      '"FullyPaidOnDate" : "/Date(1759363200000+0000)/",'+
                      '"CurrencyCode":"HKD",' +
                      '"UpdatedDateUTC":"/Date(1762921553607+0000)/",' +
                      '"Total":200.00,' +
                      '"TotalTax":0.0,' +
                      '"SubTotal":200.00,' +
                      '"LineItems":[],' +
                      '"LineAmountTypes":"Exclusive",' +
                      '"Status":"AUTHORISED",' +
                      '"DueDateString":"2025-10-14T00:00:00",' +
                      '"DateString":"2025-08-31T00:00:00",' +
                      '"Contact":{"Name":"Globex","ContactID":"XERO-ACC-002"},' +
                      '"CurrencyRate":1.0,' +
                      '"AmountCredited":0.0,' +
                      '"AmountPaid":0.0,' +
                      '"AmountDue":200.00,' +
                      '"Reference":"Monthly",' +
                      '"InvoiceNumber":"INV-002",' +
                      '"InvoiceID":"11111111-aaaa-bbbb-cccc-000000000002",' +
                      '"Type":"ACCREC"' +
                    '}' +
                ']}';
                res.setBody(body);
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'GET') {
                res.setBody('{"ContactGroups":[{"ContactGroupID":"group-123","Name":"Test Group"}]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'PUT') {
                res.setBody('{"ContactGroups":[{"ContactGroupID":"new-group-456","Name":"New Group"}]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'POST') {
                res.setBody('{"ContactGroups":[{"ContactGroupID":"group-123","Name":"Test Group"}]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'DELETE') {
                res.setBody('{"Status":"OK"}');
            }
            else if (endpoint.contains('Contacts/?IDs=') && req.getMethod() == 'GET') {
                res.setBody('{"Contacts":[{"ContactID":"220ddca8-3144-4085-9a88-2d72c5133734","DefaultCurrency":"USD","Balances":{"AccountsReceivable":{"Outstanding":7976.27,"Overdue":8776.27},"AccountsPayable":{"Outstanding":0.00,"Overdue":0.00}}},{"ContactID":"88192a99-cbc5-4a66-bf1a-2f9fea2d36d0","DefaultCurrency":"EUR","Balances":{"AccountsReceivable":{"Outstanding":123.45,"Overdue":0.00},"AccountsPayable":{"Outstanding":10.00,"Overdue":0.00}}}]}' +
                    '"pagination":{"page":1,"pageSize":2,"pageCount":1,"itemCount":2}}');
            }
            else if (endpoint.contains('Contacts/') && req.getMethod() == 'GET') {
                res.setBody('{"Contacts":[{"ContactID":"contact-123","Name":"Test Contact",' +
                    '"ContactGroups":[{"ContactGroupID":"group-456"}]}]}');
            }
            else if (endpoint.contains('Contacts') && req.getMethod() == 'PUT') {
                res.setBody('{"Contacts":[{"ContactID":"xero-contact-1","Name":"Test Contact"}]}');
            } 
            else if (endpoint.contains('Contacts') && req.getMethod() == 'POST') {
                res.setBody('{"Contacts":[{"ContactID":"xero-contact-1","Name":"Test Contact"}]}');
            } 
            else {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
            }
            return res;
        }
    }

    /**
     * @description Failure mock for /Invoices: returns 500 from /Invoices while /connections is OK.
     * @param req The incoming HTTP request.
     * @return HttpResponse with 500 for /Invoices.
     */
    public class FailureInvoices implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            if (endpoint == null) {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
                return res;
            }
            if (endpoint.endsWith('/connections')) {
                res.setStatusCode(200);
                res.setBody('[{"tenantId":"11111111-2222-3333-4444-555555555555"}]');
                return res;
            }
            res.setStatusCode(500);
            if (endpoint != null && endpoint.contains('/Invoices')) {
                res.setBody('{"message":"Server error"}');
            }            
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'GET') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'PUT') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'POST') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('Contacts/') && req.getMethod() == 'GET') {
                res.setBody('{"Contacts":[]}');
            }
            else if (endpoint.contains('Contacts') && req.getMethod() == 'PUT') {
                res.setBody('{"Contacts":[]}');
            } else {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
            }
            return res;
        }
    }

    /**
     * @description Empty mock: returns no invoices from /Invoices and valid /connections.
     * @param req The incoming HTTP request.
     * @return HttpResponse with 200 and empty Invoices array.
     */
    public class Empty implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            if (endpoint == null) {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
                return res;
            }
            res.setStatusCode(200);
            if (endpoint.endsWith('/connections')) {
                res.setBody('[{"tenantId":"11111111-2222-3333-4444-555555555555"}]');
            }
            else if (endpoint.contains('/Invoices')) {
                res.setBody('{ "Invoices": [] }');
            }
            else if (endpoint.contains('/CreditNotes')) {
                res.setBody('{ "CreditNotes": [] }');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'GET') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'PUT') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'POST') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('Contacts/') && req.getMethod() == 'GET') {
                res.setBody('{"Contacts":[]}');
            }
            else if (endpoint.contains('Contacts') && req.getMethod() == 'PUT') {
                res.setBody('{"Contacts":[]}');
            }
            else if (endpoint.contains('Contacts') && req.getMethod() == 'POST') {
                res.setBody('{"Contacts":[]}');
            } 
            else {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
            }
            return res;
        }
    }

    /**
     * @description Success mock for CreditNotes: returns valid tenant from /connections and one credit note from /CreditNotes.
     * @param req The incoming HTTP request.
     * @return HttpResponse with 200 and a valid JSON body for each endpoint.
     */
    public class SuccessCreditNotes implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            if (endpoint == null) {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
                return res;
            }
            res.setStatusCode(200);
            if (endpoint.endsWith('/connections')) {
                res.setBody('[{"tenantId":"11111111-2222-3333-4444-555555555555"}]');
                return res;
            }
            else if (endpoint.contains('/CreditNotes')) {
                String body = '{ "CreditNotes": [' +
                    '{' +
                      '"Contact":{"Name":"Test Apply Credit Note","ContactID":"c6c7b870-bb4d-489a-921e-2f0ee4192ff9"},' +
                      '"DateString":"2016-12-16T00:00:00",' +
                      '"Date":"/Date(1481846400000+0000)/",' +
                      '"Status":"PAID",' +
                      '"LineAmountTypes":"Inclusive",' +
                      '"SubTotal":86.96,' +
                      '"TotalTax":13.04,' +
                      '"Total":100.00,' +
                      '"UpdatedDateUTC":"/Date(1290168061547+0000)/",' +
                      '"CurrencyCode":"HKD",' +
                      '"FullyPaidOnDate":"/Date(1481846400000+0000)/",' +
                      '"Type":"ACCRECCREDIT",' +
                      '"CreditNoteID":"aea95d78-ea48-456b-9b08-6bc012600072",' +
                      '"CreditNoteNumber":"CN-0002",' +
                      '"CurrencyRate":1.000000,' +
                      '"RemainingCredit":0.00,' +
                      '"Allocations": [' +
                        '{' +
                          '"AllocationID":"b12335f4-a1e5-4431-aeb4-488e5547558e",' +
                          '"Amount":100.00,' +
                          '"Date":"/Date(1481846400000+0000)/",' +
                          '"Invoice":{' +
                            '"InvoiceID":"87cfa39f-136c-4df9-a70d-bb80d8ddb975",' +
                            '"InvoiceNumber":"INV-0001"' +
                          '}' +
                        '}' +
                      ']' +
                    '}' +
                ']}';
                res.setBody(body);
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'GET') {
                res.setBody('{"ContactGroups":[{"ContactGroupID":"group-123","Name":"Test Group"}]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'PUT') {
                res.setBody('{"ContactGroups":[{"ContactGroupID":"new-group-456","Name":"New Group"}]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'POST') {
                res.setBody('{"ContactGroups":[{"ContactGroupID":"group-123","Name":"Test Group"}]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'DELETE') {
                res.setBody('{"Status":"OK"}');
            }
            else if (endpoint.contains('Contacts/') && req.getMethod() == 'GET') {
                res.setBody('{"Contacts":[{"ContactID":"contact-123","Name":"Test Contact",' +
                    '"ContactGroups":[{"ContactGroupID":"group-456"}]}]}');
            }
            else if (endpoint.contains('Contacts') && req.getMethod() == 'PUT') {
                res.setBody('{"Contacts":[{"ContactID":"xero-contact-1","Name":"Test Contact"}]}');
            } 
            else if (endpoint.contains('Contacts') && req.getMethod() == 'POST') {
                res.setBody('{"Contacts":[{"ContactID":"xero-contact-1","Name":"Test Contact"}]}');
            } 
            else {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
            }
            return res;
        }
    }

    /**
     * @description Failure mock for /CreditNotes: returns 500 from /CreditNotes while /connections is OK.
     * @param req The incoming HTTP request.
     * @return HttpResponse with 500 for /CreditNotes.
     */
    public class FailureCreditNotes implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();
            if (endpoint == null) {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
                return res;
            }
            if (endpoint.endsWith('/connections')) {
                res.setStatusCode(200);
                res.setBody('[{"tenantId":"11111111-2222-3333-4444-555555555555"}]');
                return res;
            }
            res.setStatusCode(500);
            if (endpoint != null && endpoint.contains('/CreditNotes')) {
                res.setBody('{"message":"Server error"}');
            }            
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'GET') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'PUT') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('ContactGroups') && req.getMethod() == 'POST') {
                res.setBody('{"ContactGroups":[]}');
            }
            else if (endpoint.contains('Contacts/') && req.getMethod() == 'GET') {
                res.setBody('{"Contacts":[]}');
            }
            else if (endpoint.contains('Contacts') && req.getMethod() == 'PUT') {
                res.setBody('{"Contacts":[]}');
            } else {
                res.setStatusCode(404);
                res.setBody('{"message":"Not Found"}');
            }
            return res;
        }
    }
}