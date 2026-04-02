public with sharing class ContactTriggerHandler {
/**
    * @description Main trigger handler method for Account object
    */
    public static void handleTrigger(
        List<Contact> newRecords,
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
    
    private static void handleAfterInsertOrUpdate(List<Contact> newRecords) {
        System.debug('AccountTriggerHandler.handleAfterInsertOrUpdate' + newRecords);
        System.debug('AccountTriggerHelper.isExecuting' + AccountTriggerHelper.isExecuting);
        if (AccountTriggerHelper.isExecuting) {
            return;
        }
        List<Id> accountIds = new List<Id>();
        for (Contact contact : newRecords) {
            accountIds.add(contact.AccountId);
        }
        ContactService.sendContactsToXero(accountIds);
    }
}