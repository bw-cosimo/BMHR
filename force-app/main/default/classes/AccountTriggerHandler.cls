/**
 * @description Trigger handler for Account object
 */
public with sharing class AccountTriggerHandler {
    /**
    * @description Main trigger handler method for Account object
    * @param newRecords List of new records
    * @param operationType Trigger operation type
    */
    public static void handleTrigger(
        List<Account> newRecords,
        System.TriggerOperation operationType
    ) {
        switch on operationType {
            when AFTER_INSERT {
                handleAfterInsertOrUpdate(newRecords);
            }
            when AFTER_UPDATE {
                handleAfterInsertOrUpdate(newRecords);
            }
        }
    }
    
    /**
     * @description Handles after insert or update operations
     * @param newRecords List of new records
     */
    private static void handleAfterInsertOrUpdate(List<Account> newRecords) {
        System.debug('AccountTriggerHandler.handleAfterInsertOrUpdate' + newRecords);
        System.debug('AccountTriggerHelper.isExecuting' + AccountTriggerHelper.isExecuting);
        if (AccountTriggerHelper.isExecuting) {
            return;
        }
        List<Id> accountIds = new List<Id>();
        for (Account acc : newRecords) {
            accountIds.add(acc.Id);
        }
        ContactService.sendContactsToXero(accountIds);
    }
}