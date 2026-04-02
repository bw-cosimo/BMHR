public with sharing class ContactSelector {
    private static final String ADDITIONAL_BILLING_CONTACT_ROLE = 'Additional Billing Contact';
    private static final String PRIMARY_BILLING_CONTACT_ROLE = 'Primary Billing Contact';
    private static final String EXCLUDE_ACCOUNT_STATUS = 'Prospect';

    public static List<Contact> getContactsByAccountIds(List<Id> accountIds) {
        List<String> validRoles = new List<String>{ADDITIONAL_BILLING_CONTACT_ROLE, PRIMARY_BILLING_CONTACT_ROLE};
        return [
            SELECT 
                Id, 
                Account.Status__c, 
                Role__c,
                FirstName,
                LastName,
                Email,
                AccountId, 
                Account.Name, 
                Account.BillingStreet, 
                Account.BillingCountry, 
                Account.BillingCity, 
                Account.BillingState, 
                Account.BillingPostalCode, 
                Account.RecordType.DeveloperName,
                Account.Parent.Name
            FROM Contact 
            WHERE 
                AccountId IN :accountIds
                AND Role__c IN :validRoles
                AND Account.Status__c != :EXCLUDE_ACCOUNT_STATUS
            WITH SECURITY_ENFORCED
        ];
    }

    public static List<Contact> getAdditionalContacts(List<Id> accountIds) {
        return [
            SELECT 
                Id, 
                Account.Status__c, 
                Role__c,
                FirstName,
                LastName,
                Email
            FROM Contact 
            WHERE 
                AccountId IN :accountIds
                AND Role__c = :ADDITIONAL_BILLING_CONTACT_ROLE
                AND Account.Status__c != :EXCLUDE_ACCOUNT_STATUS
            WITH SECURITY_ENFORCED
        ];
    }
}