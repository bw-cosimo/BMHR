/**
 * Queueable job that performs the Xero invoice sync in a separate transaction
 * to avoid "uncommitted work pending" when Flow has already executed DML.
 */
public with sharing class XeroInvoiceSyncQueue implements Queueable, Database.AllowsCallouts {

    private final String lastModifiedUtc;

    public XeroInvoiceSyncQueue(String lastModifiedUtc) {
        this.lastModifiedUtc = lastModifiedUtc;
    }

    public void execute(QueueableContext qc) {
        List<Error_Log__c> errorLogs = new List<Error_Log__c>();

        try {
            // 1) Call Xero
            XeroClient client = new XeroClient();
            Map<String, Object> raw = client.getInvoicesSinceLastModified(lastModifiedUtc);

            // 2) Wrap response
            XeroInvoiceResponseWrapper wrapped = parseResponseToWrapper(raw);

            // 3) Resolve Accounts by Xero_Id__c and map to sObjects
            Set<String> xeroIds = new Set<String>();
            if (wrapped != null && wrapped.Invoices != null) {
                for (XeroInvoiceResponseWrapper.Invoice inv : wrapped.Invoices) {
                    if (inv != null && inv.Contact != null && String.isNotBlank(inv.Contact.ContactID)) {
                        xeroIds.add(inv.Contact.ContactID);
                    }
                }
            }

            Map<String, Id> xeroIdToAccountId = new Map<String, Id>();
            if (!xeroIds.isEmpty() && Schema.sObjectType.Account.fields.getMap().containsKey('Xero_Id__c')) {
                for (Account foundXeroAccount : [
                    SELECT Id, Xero_Id__c
                    FROM Account
                    WHERE Xero_Id__c IN :xeroIds
                ]) {
                    if (foundXeroAccount.Xero_Id__c != null) {
                        xeroIdToAccountId.put(foundXeroAccount.Xero_Id__c, foundXeroAccount.Id);
                    }
                }
            }

            // 4) Map invoices to sObjects
            List<Invoice__c> toUpsertOrInsert = new List<Invoice__c>();
            if (wrapped != null && wrapped.Invoices != null) {
                for (XeroInvoiceResponseWrapper.Invoice inv : wrapped.Invoices) {
                    Invoice__c mapped = mapInvoice(inv, xeroIdToAccountId);
                    if (mapped != null) {
                        toUpsertOrInsert.add(mapped);
                    }
                }
            }

            if (!toUpsertOrInsert.isEmpty()) {
                // 5) DML with partial success (always upsert by Invoice_Number__c)
                Database.UpsertResult[] dmlResults = Database.upsert(
                    toUpsertOrInsert,
                    Invoice__c.Fields.Invoice_Number__c,
                    false
                );

                Integer success = 0, failed = 0;
                for (Integer i = 0; i < dmlResults.size(); i++) {
                    Database.UpsertResult ur = dmlResults[i];
                    if (ur.isSuccess()) {
                        success++;
                    } else {
                        failed++;
                        for (Database.Error e : ur.getErrors()) {
                            String msg = 'Xero Invoice Sync: Row ' + i + ' failed: ' + e.getStatusCode() + ' - ' + e.getMessage();
                            errorLogs.add(ErrorUtility.build(
                                msg,
                                'Apex',
                                'XeroInvoiceSyncQueue.execute: Some invoices failed DML upsert.'
                            ));
                        }
                    }
                }
            }
        } catch (Exception ex) {
            errorLogs.add(ErrorUtility.build(
                'Xero Invoice Sync: ' + ex.getMessage(),
                'Apex',
                ex.getStackTraceString()
            ));
        }

        if (!errorLogs.isEmpty()) {
            ErrorUtility.insertLogs(errorLogs, false);
        }
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
        if (inv != null
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
            if (Schema.sObjectType.Invoice__c.fields.getMap().containsKey('Fully_Paid_Date__c') && inv.FullyPaidOnDate != null) rec.put('Fully_Paid_Date__c', XeroInvoiceSyncAction.convertUnixTimestamp(inv.FullyPaidOnDate));
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