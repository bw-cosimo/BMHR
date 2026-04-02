/**
 * Queueable job that performs the Xero credit note sync in a separate transaction
 * to avoid "uncommitted work pending" when Flow has already executed DML.
 */
public with sharing class XeroCreditNoteSyncQueue implements Queueable, Database.AllowsCallouts {

    private final String lastModifiedUtc;

    public XeroCreditNoteSyncQueue(String lastModifiedUtc) {
        this.lastModifiedUtc = lastModifiedUtc;
    }

    public void execute(QueueableContext qc) {
        List<Error_Log__c> errorLogs = new List<Error_Log__c>();

        try {
            // 1) Call Xero
            XeroClient client = new XeroClient();
            Map<String, Object> raw = client.getCreditNotesSinceLastModified(lastModifiedUtc);

            // 2) Wrap response
            XeroCreditNoteResponseWrapper wrapped = parseResponseToWrapper(raw);

            // 3) Resolve Accounts by Xero_Id__c and map to sObjects
            Set<String> xeroIds = new Set<String>();
            if (wrapped != null && wrapped.CreditNotes != null) {
                for (XeroCreditNoteResponseWrapper.CreditNote cn : wrapped.CreditNotes) {
                    if (cn != null && cn.Contact != null && String.isNotBlank(cn.Contact.ContactID)) {
                        xeroIds.add(cn.Contact.ContactID);
                    }
                }
            }

            Map<String, Id> xeroIdToAccountId = new Map<String, Id>();
            if (!xeroIds.isEmpty()) {
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

            // 4) Map credit notes to sObjects
            List<Credit_Note__c> toUpsertOrInsertCreditNotes = new List<Credit_Note__c>();
            // Maintain wrapper credit notes in same order for correlation with upsert results
            List<XeroCreditNoteResponseWrapper.CreditNote> creditNotesInSameOrder = new List<XeroCreditNoteResponseWrapper.CreditNote>();
            if (wrapped != null && wrapped.CreditNotes != null) {
                for (XeroCreditNoteResponseWrapper.CreditNote cn : wrapped.CreditNotes) {
                    Credit_Note__c mapped = mapCreditNote(cn, xeroIdToAccountId);
                    if (mapped != null) {
                        toUpsertOrInsertCreditNotes.add(mapped);
                        creditNotesInSameOrder.add(cn);
                    }
                }
            }

            // Track only successful credit notes for allocation processing
            Set<String> succeededCreditNoteIds = new Set<String>(); // Xero CreditNoteIDs that upserted OK
            Map<String, Id> creditNoteIdToSalesforceId = new Map<String, Id>(); // Xero CreditNoteID -> SF Id

            if (!toUpsertOrInsertCreditNotes.isEmpty()) {
                // 5) DML with partial success (always upsert by Credit_Note_ID__c)
                Database.UpsertResult[] dmlResults = Database.upsert(
                    toUpsertOrInsertCreditNotes,
                    Credit_Note__c.Fields.Credit_Note_ID__c,
                    false
                );

                Integer success = 0, failed = 0;
                for (Integer i = 0; i < dmlResults.size(); i++) {
                    Database.UpsertResult ur = dmlResults[i];
                    if (ur.isSuccess()) {
                        success++;
                        if (i < creditNotesInSameOrder.size()) {
                            XeroCreditNoteResponseWrapper.CreditNote src = creditNotesInSameOrder[i];
                            if (src != null && String.isNotBlank(src.CreditNoteID)) {
                                succeededCreditNoteIds.add(src.CreditNoteID);
                                if (ur.getId() != null) {
                                    creditNoteIdToSalesforceId.put(src.CreditNoteID, ur.getId());
                                }
                            }
                        }
                    } else {
                        failed++;
                        for (Database.Error e : ur.getErrors()) {
                            String msg = 'Xero Credit Note Sync: Row ' + i + ' failed: ' + e.getStatusCode() + ' - ' + e.getMessage();
                            System.debug(msg);
                            errorLogs.add(ErrorUtility.build(
                                msg,
                                'Apex',
                                'XeroCreditNoteSyncQueue.execute: Some credit notes failed DML upsert.'
                            ));
                        }
                    }
                }
            }

            // 6) Process allocations - only for successfully upserted Credit Notes
            List<Credit_Note_Allocation__c> allocationsToInsert = new List<Credit_Note_Allocation__c>();
            // Collect Invoice Numbers for batch lookup
            Set<String> invoiceNumbers = new Set<String>();
            if (wrapped != null && wrapped.CreditNotes != null && !succeededCreditNoteIds.isEmpty()) {
                for (XeroCreditNoteResponseWrapper.CreditNote cn : wrapped.CreditNotes) {
                    if (cn != null && succeededCreditNoteIds.contains(cn.CreditNoteID) && cn.Allocations != null) {
                        for (XeroCreditNoteResponseWrapper.Allocation alloc : cn.Allocations) {
                            if (alloc != null && alloc.Invoice != null && String.isNotBlank(alloc.Invoice.InvoiceNumber)) {
                                invoiceNumbers.add(alloc.Invoice.InvoiceNumber);
                            }
                        }
                    }
                }
            }

            System.debug('succeededCreditNoteIds: ' + succeededCreditNoteIds);
            System.debug('invoiceNumbers: ' + invoiceNumbers);

            // Resolve Invoice__c records by Invoice_Number__c
            Map<String, Id> invoiceNumberToId = new Map<String, Id>();
            if (!invoiceNumbers.isEmpty()) {
                for (Invoice__c foundInvoice : [
                    SELECT Id, Invoice_Number__c
                    FROM Invoice__c
                    WHERE Invoice_Number__c IN :invoiceNumbers
                ]) {
                    if (foundInvoice.Invoice_Number__c != null) {
                        invoiceNumberToId.put(foundInvoice.Invoice_Number__c, foundInvoice.Id);
                    }
                }
            }

            System.debug('invoiceNumberToId: ' + invoiceNumberToId);

            // creditNoteIdToSalesforceId already built from upsert results
            System.debug('creditNoteIdToSalesforceId: ' + creditNoteIdToSalesforceId);

            // Now process allocations for successful credit notes only
            if (wrapped != null && wrapped.CreditNotes != null && !succeededCreditNoteIds.isEmpty()) {
                for (XeroCreditNoteResponseWrapper.CreditNote cn : wrapped.CreditNotes) {
                    if (cn != null && succeededCreditNoteIds.contains(cn.CreditNoteID) && cn.Allocations != null) {
                        Id cnSfId = creditNoteIdToSalesforceId.get(cn.CreditNoteID);
                        for (XeroCreditNoteResponseWrapper.Allocation alloc : cn.Allocations) {
                            Credit_Note_Allocation__c allocation = mapAllocation(cnSfId, alloc, invoiceNumberToId);
                            if (allocation != null) {
                                allocationsToInsert.add(allocation);
                            }
                        }
                    }
                }
            }

            if (!allocationsToInsert.isEmpty()) {
                // 7) Insert allocations with partial success
                Database.UpsertResult[] dmlResults = Database.upsert(allocationsToInsert, Credit_Note_Allocation__c.Fields.Allocation_ID__c, false);

                Integer success = 0, failed = 0;
                for (Integer i = 0; i < dmlResults.size(); i++) {
                    Database.UpsertResult sr = dmlResults[i];
                    if (!sr.isSuccess()) {
                        failed++;
                        for (Database.Error e : sr.getErrors()) {
                            String msg = 'Xero Credit Note Allocation Sync: Row ' + i + ' failed: ' + e.getStatusCode() + ' - ' + e.getMessage();
                            errorLogs.add(ErrorUtility.build(
                                msg,
                                'Apex',
                                'XeroCreditNoteSyncQueue.execute: Some credit note allocations failed DML insert.'
                            ));
                        }
                    } else {
                        success++;
                    }
                }
            }
        } catch (Exception ex) {
            errorLogs.add(ErrorUtility.build(
                'Xero Credit Note Sync: ' + ex.getMessage(),
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
     * @param raw Untyped map from XeroClient.getCreditNotesSinceLastModified.
     * @return XeroCreditNoteResponseWrapper or null.
     */
    private static XeroCreditNoteResponseWrapper parseResponseToWrapper(Map<String, Object> raw) {
        if (raw == null) return null;
        String jsonBody = JSON.serialize(raw);
        return XeroCreditNoteResponseWrapper.parse(jsonBody);
    }

    /**
     * @description Converts Xero's /Date(1234567890)/ format to standard Date.
     * @return Date standard Date.
     */
    private static Date convertUnixTimestamp(String unixTimestamp) {
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
     * @description Map a wrapper CreditNote into a Credit_Note__c record. Uses defensive Schema checks for optional fields.
     * @param cn The Xero wrapper credit note.
     * @param xeroIdToAccountId Map of Xero IDs to Account IDs.
     * @return Credit_Note__c sObject populated from Xero credit note.
     */
    private static Credit_Note__c mapCreditNote(XeroCreditNoteResponseWrapper.CreditNote cn, Map<String, Id> xeroIdToAccountId) {
        if (cn != null
            && cn.Contact != null
            && String.isNotBlank(cn.Contact.ContactID)
            && xeroIdToAccountId != null
            && xeroIdToAccountId.containsKey(cn.Contact.ContactID)
        ) {
            Credit_Note__c rec = new Credit_Note__c();
            if (Schema.sObjectType.Credit_Note__c.fields.getMap().containsKey('Name') && cn.CreditNoteNumber != null) rec.put('Name', cn.CreditNoteNumber);
            if (Schema.sObjectType.Credit_Note__c.fields.getMap().containsKey('Credit_Note_ID__c') && cn.CreditNoteID != null) rec.put('Credit_Note_ID__c', cn.CreditNoteID);
            if (Schema.sObjectType.Credit_Note__c.fields.getMap().containsKey('Issue_Date__c') && cn.DateString != null) rec.put('Issue_Date__c', Date.valueOf(cn.DateString));
            if (Schema.sObjectType.Credit_Note__c.fields.getMap().containsKey('Amount__c') && cn.Total != null) rec.put('Amount__c', cn.Total);
            if (Schema.sObjectType.Credit_Note__c.fields.getMap().containsKey('CurrencyIsoCode') && cn.CurrencyCode != null) rec.put('CurrencyIsoCode', cn.CurrencyCode);
            if (Schema.sObjectType.Credit_Note__c.fields.getMap().containsKey('Remaining_Credit__c') && cn.RemainingCredit != null) rec.put('Remaining_Credit__c', cn.RemainingCredit);
            if (Schema.sObjectType.Credit_Note__c.fields.getMap().containsKey('Account__c')) {
                rec.put('Account__c', xeroIdToAccountId.get(cn.Contact.ContactID));
            }
            System.debug('Mapped credit note: ' + rec);
            return rec;
        }
        return null;
    }

    /**
     * @description Map a wrapper Allocation into a Credit_Note_Allocation__c record.
     * @param alloc The Xero wrapper allocation.
     * @param creditNoteSFId Salesforce Credit_Note__c Id.
     * @param invoiceNumberToId Map of Invoice Number to Salesforce Invoice__c Id.
     * @return Credit_Note_Allocation__c sObject populated from Xero allocation.
     */
    private static Credit_Note_Allocation__c mapAllocation(String creditNoteSFId, XeroCreditNoteResponseWrapper.Allocation alloc, Map<String, Id> invoiceNumberToId) {
        if (alloc != null && alloc.Invoice != null && alloc.Invoice.InvoiceNumber != null && creditNoteSFId != null && invoiceNumberToId != null && invoiceNumberToId.containsKey(alloc.Invoice.InvoiceNumber)) {
            Credit_Note_Allocation__c rec = new Credit_Note_Allocation__c();
            
            // Set allocation fields
            if (Schema.sObjectType.Credit_Note_Allocation__c.fields.getMap().containsKey('Amount__c') && alloc.Amount != null) rec.put('Amount__c', alloc.Amount);
            if (Schema.sObjectType.Credit_Note_Allocation__c.fields.getMap().containsKey('Allocation_ID__c') && alloc.AllocationID != null) rec.put('Allocation_ID__c', alloc.AllocationID);
            if (Schema.sObjectType.Credit_Note_Allocation__c.fields.getMap().containsKey('Credit_Note__c') && creditNoteSFId != null) rec.put('Credit_Note__c', creditNoteSFId);
            if (Schema.sObjectType.Credit_Note_Allocation__c.fields.getMap().containsKey('Date__c') && alloc.Date_x != null) rec.put('Date__c', convertUnixTimestamp(alloc.Date_x));
            
            // Link to Invoice - we need to resolve the Invoice__c based on InvoiceNumber
            if (Schema.sObjectType.Credit_Note_Allocation__c.fields.getMap().containsKey('Invoice__c') && invoiceNumberToId != null && invoiceNumberToId.containsKey(alloc.Invoice.InvoiceNumber)) {
                rec.put('Invoice__c', invoiceNumberToId.get(alloc.Invoice.InvoiceNumber));
            }
            System.debug('allocation: ' + alloc);
            System.debug('Mapped allocation: ' + rec);
            System.debug('invoiceNumberToId: ' + invoiceNumberToId);
            System.debug('creditNoteSFId: ' + creditNoteSFId);

            return rec;
        }
        return null;
    }
}