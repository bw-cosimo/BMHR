/**
 * @author Cosimo
 * @description Flow-invocable action to fetch Xero invoices modified since previous midnight (UTC) and insert/upsert Invoice__c records.
 */
public with sharing class XeroInvoiceSyncAction {

    /**
     * @description Optional Flow input to override lastModified and control upsert behavior.
     */
    public class Request {
        @InvocableVariable(label='Override Last Modified (UTC)' description='Optional UTC timestamp yyyy-MM-ddThh:mm:ss. If blank, uses previous midnight UTC.')
        public String overrideLastModifiedUtc;
    }

    /**
     * @description Flow output with counts and messages.
     */
    public class Result {
        @InvocableVariable public Integer successCount;
        @InvocableVariable public Integer errorCount;
        @InvocableVariable public List<String> messages;
        @InvocableVariable public String lastModifiedUsed;
    }

    /**
     * @description Fetch and insert Xero invoices created/modified since previous midnight UTC.
     * @param requests Flow requests; only the first request is used. If none provided, defaults are applied.
     * @return List<Result> containing success/error counts and messages for Flow display.
     */
    @InvocableMethod(label='Sync Xero Invoices Since Previous Midnight' description='Fetch and insert Xero invoices modified since previous midnight (UTC) using Xero API.')
    public static List<Result> run(List<Request> requests) {
        Request req = (requests == null || requests.isEmpty()) ? new Request() : requests[0];

        Result res = new Result();
        res.messages = new List<String>();

        String lastModified = String.isNotBlank(req.overrideLastModifiedUtc)
            ? req.overrideLastModifiedUtc
            : previousMidnightGmt();
        res.lastModifiedUsed = lastModified;

        // Enqueue async processing to isolate callouts from any prior Flow DML
        System.enqueueJob(new XeroInvoiceSyncQueue(lastModified));

        // Return immediate acknowledgement to Flow
        res.successCount = 0;
        res.errorCount = 0;
        res.messages.add('Xero invoice sync enqueued for processing.');
        return new List<Result>{ res };
    }

    /**
     * @description Compute previous midnight in UTC formatted as yyyy-MM-ddThh:mm:ss (for If-Modified-Since).
     * @return String UTC timestamp for previous midnight.
     */
    private static String previousMidnightGmt() {
        Date prior = Date.today().addDays(-1);
        return Datetime.newInstance(prior, Time.newInstance(0, 0, 0, 0))
            .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss');
    }

    /**
     * @description Converts Xero's /Date(1234567890)/ format to standard Date.
     * @return Date standard Date.
     */
    public static Date convertUnixTimestamp(String unixTimestamp) {
        Pattern p = Pattern.compile('/Date\\((\\d+)(?:[+-]\\d+)?\\)/');
        Matcher m = p.matcher(unixTimestamp);

        DateTime standardDateTime;
        Date standardDate;

        if (m.find()) {
            Long millis = Long.valueOf(m.group(1));
            Long seconds = millis / 1000;

            // Convert milliseconds to a Datetime
            standardDateTime = Datetime.newInstance(1970, 1, 1, 0, 0, 0)
                .addSeconds(seconds.intValue());

            // Convert Datetime → Date if needed
            standardDate = standardDateTime.date();
        }
        return standardDate;
    }

    /**
     * @description Convert untyped response into the typed wrapper.
     * @param raw Untyped map from XeroClient.getInvoicesSinceLastModified.
     * @return XeroInvoiceResponseWrapper or null.
     */
    private static XeroInvoiceResponseWrapper parseResponseToWrapper(Map<String, Object> raw) {
        if (raw == null) return null;
        String jsonBody = JSON.serialize(raw);
        return XeroInvoiceResponseWrapper.parse(jsonBody);
    }

    /**
     * @description Map a wrapper Invoice into an Invoice__c record. Uses defensive Schema checks for optional fields.
     * @param inv The Xero wrapper invoice.
     * @return Invoice__c sObject populated from Xero invoice.
     */
    private static Invoice__c mapInvoice(XeroInvoiceResponseWrapper.Invoice inv, Map<String, Id> xeroIdToAccountId) {
        if( inv != null
            && inv.Contact != null
            && String.isNotBlank(inv.Contact.ContactID)
            && xeroIdToAccountId != null
            && xeroIdToAccountId.containsKey(inv.Contact.ContactID)
        ) {
        Invoice__c rec = new Invoice__c();
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Name') && inv.InvoiceNumber != null) rec.put('Name', inv.InvoiceNumber);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Invoice_Number__c') && inv.InvoiceNumber != null) rec.put('Invoice_Number__c', inv.InvoiceNumber);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Issue_Date__c') && inv.DateString != null) rec.put('Issue_Date__c', Date.valueOf(inv.DateString));
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Due_Date__c') && inv.DueDateString != null) rec.put('Due_Date__c', Date.valueOf(inv.DueDateString));
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Amount__c') && inv.Total != null) rec.put('Amount__c', inv.Total);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('CurrencyIsoCode') && inv.CurrencyCode != null) rec.put('CurrencyIsoCode', inv.CurrencyCode);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Amount_Paid__c') && inv.AmountPaid != null) rec.put('Amount_Paid__c', inv.AmountPaid);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Amount_Due__c') && inv.AmountDue != null) rec.put('Amount_Due__c', inv.AmountDue);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Fully_Paid_Date__c') && inv.FullyPaidOnDate != null) rec.put('Fully_Paid_Date__c', convertUnixTimestamp(inv.FullyPaidOnDate));
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Type__c') && inv.Type != null) rec.put('Type__c', inv.Type);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Status__c') && inv.Status != null) rec.put('Status__c', inv.Status);
        if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Account__c')) {
            rec.put('Account__c', xeroIdToAccountId.get(inv.Contact.ContactID));
        }
        return rec;
    }
        return null;
    }
}