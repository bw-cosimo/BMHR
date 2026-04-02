/**
 * @author Cosimo
 * @description Queueable job that performs the Xero contact balance sync in a separate transaction
 * to avoid "uncommitted work pending" when Flow has already executed DML.
 */
public with sharing class XeroContactBalanceSyncQueue implements Queueable, Database.AllowsCallouts {

    private final List<String> contactIdsBatch;

    public XeroContactBalanceSyncQueue(List<String> contactIdsBatch) {
        this.contactIdsBatch = contactIdsBatch;
    }

    public void execute(QueueableContext qc) {
        List<Error_Log__c> errorLogs = new List<Error_Log__c>();

        try {
            // 1) Call Xero
            XeroClient client = new XeroClient();
            Map<String, Object> raw = client.getContactsByIds(contactIdsBatch);

            // 2) Wrap response
            XeroGetContactsResponseWrapper wrapped = parseResponseToWrapper(raw);

            // 3) Resolve Accounts by Xero_Id__c and map to sObjects
            Set<String> xeroIds = new Set<String>();
            if (wrapped != null && wrapped.Contacts != null) {
                for (XeroGetContactsResponseWrapper.ContactMinimal c : wrapped.Contacts) {
                    if (c != null && String.isNotBlank(c.ContactID)) {
                        xeroIds.add(c.ContactID);
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

            // 4) Map contacts to Account updates
            List<Account> accountsToUpdate = new List<Account>();
            if (wrapped != null && wrapped.Contacts != null) {
                for (XeroGetContactsResponseWrapper.ContactMinimal c : wrapped.Contacts) {
                    if (c != null && c.ContactID != null && xeroIdToAccountId.containsKey(c.ContactID)) {
                        Id accountId = xeroIdToAccountId.get(c.ContactID);
                        Account acc = new Account(Id = accountId);

                        // Update CurrencyIsoCode from DefaultCurrency if present
                        if (String.isNotBlank(c.DefaultCurrency)) {
                            acc.CurrencyIsoCode = c.DefaultCurrency;
                        }

                        // TODO: Confirm Outstanding_Balance__c (or AR/AP fields) mapping before enabling
                        // Example if using a single Outstanding_Balance__c:
                        // if (Schema.sObjectType.Account.fields.getMap().containsKey('Outstanding_Balance__c') && c.Balances != null && c.Balances.AccountsReceivable != null) {
                        //     acc.put('Outstanding_Balance__c', c.Balances.AccountsReceivable.Outstanding);
                        // }

                        accountsToUpdate.add(acc);
                    }
                }
            }

            if (!accountsToUpdate.isEmpty()) {
                // 5) DML with partial success (always update by Id)
                Database.SaveResult[] dmlResults = Database.update(accountsToUpdate, false);

                Integer success = 0, failed = 0;
                for (Integer i = 0; i < dmlResults.size(); i++) {
                    Database.SaveResult sr = dmlResults[i];
                    if (sr.isSuccess()) {
                        success++;
                    } else {
                        failed++;
                        for (Database.Error e : sr.getErrors()) {
                            String msg = 'Xero Contact Balance Sync: Row ' + i + ' failed: ' + e.getStatusCode() + ' - ' + e.getMessage();
                            errorLogs.add(ErrorUtility.build(
                                msg,
                                'Apex',
                                'XeroContactBalanceSyncQueue.execute: Some accounts failed DML update.'
                            ));
                        }
                    }
                }
            }
        } catch (Exception ex) {
            errorLogs.add(ErrorUtility.build(
                'Xero Contact Balance Sync: ' + ex.getMessage(),
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
     * @param raw Untyped map from XeroClient.getContactsByIds.
     * @return XeroGetContactsResponseWrapper or null.
     */
    private static XeroGetContactsResponseWrapper parseResponseToWrapper(Map<String, Object> raw) {
        if (raw == null) return null;
        String jsonBody = JSON.serialize(raw);
        return XeroGetContactsResponseWrapper.parse(jsonBody);
    }
}