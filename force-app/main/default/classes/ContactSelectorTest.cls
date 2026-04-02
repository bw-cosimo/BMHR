@IsTest
private class ContactSelectorTest {
    
    @TestSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        // Create Parent Account
        Account parentAccount = new Account(
            Name = 'Parent Account'
        );
        insert parentAccount;
        
        // Create Test Accounts with different statuses
        List<Account> accounts = new List<Account>();
        
        Account activeAccount = new Account(
            Name = 'Active Account',
            Status__c = 'Live',
            ParentId = parentAccount.Id
        );
        accounts.add(activeAccount);
        
        Account prospectAccount = new Account(
            Name = 'Prospect Account',
            Status__c = 'Prospect'
        );
        accounts.add(prospectAccount);
        
        Account customerAccount = new Account(
            Name = 'Customer Account',
            Status__c = 'Live'
        );
        accounts.add(customerAccount);
        
        insert accounts;
        
        // Create Contacts with different roles
        List<Contact> contacts = new List<Contact>();
        
        // Primary Billing Contact for Active Account
        contacts.add(new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@test.com',
            AccountId = activeAccount.Id,
            Role__c = 'Primary Billing Contact'
        ));
        
        // Additional Billing Contact for Active Account
        contacts.add(new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@test.com',
            AccountId = activeAccount.Id,
            Role__c = 'Additional Billing Contact'
        ));
        
        // Contact with different role for Active Account (should not be returned)
        contacts.add(new Contact(
            FirstName = 'Bob',
            LastName = 'Johnson',
            Email = 'bob.johnson@test.com',
            AccountId = activeAccount.Id,
            Role__c = ''
        ));
        
        // Primary Billing Contact for Prospect Account (should not be returned)
        contacts.add(new Contact(
            FirstName = 'Alice',
            LastName = 'Williams',
            Email = 'alice.williams@test.com',
            AccountId = prospectAccount.Id,
            Role__c = 'Primary Billing Contact'
        ));
        
        // Additional Billing Contact for Customer Account
        contacts.add(new Contact(
            FirstName = 'Charlie',
            LastName = 'Brown',
            Email = 'charlie.brown@test.com',
            AccountId = customerAccount.Id,
            Role__c = 'Additional Billing Contact'
        ));
        
        // Primary Billing Contact for Customer Account
        contacts.add(new Contact(
            FirstName = 'Diana',
            LastName = 'Prince',
            Email = 'diana.prince@test.com',
            AccountId = customerAccount.Id,
            Role__c = 'Primary Billing Contact'
        ));
        
        insert contacts;
    }
    
    @IsTest
    static void testGetContactsByAccountIdsWithValidAccounts() {
        // Arrange
        List<Account> accounts = [
            SELECT Id, Name, Status__c 
            FROM Account 
            WHERE Status__c != 'Prospect'
        ];
        
        List<Id> accountIds = new List<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getContactsByAccountIds(accountIds);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(4, results.size(), 'Should return 4 contacts (2 from Active, 2 from Customer)');
        
        // Verify all returned contacts have valid roles
        for (Contact con : results) {
            System.assert(
                con.Role__c == 'Primary Billing Contact' || con.Role__c == 'Additional Billing Contact',
                'Contact should have a valid billing role'
            );
            System.assertNotEquals('Prospect', con.Account.Status__c, 'Account should not be a Prospect');
        }
        
        // Verify Account fields are populated
        System.assertNotEquals(null, results[0].Account.Name, 'Account Name should be populated');
        System.assertNotEquals(null, results[0].AccountId, 'AccountId should be populated');
    }
    
    @IsTest
    static void testGetContactsByAccountIdsExcludesProspectAccounts() {
        // Arrange
        Account prospectAccount = [
            SELECT Id 
            FROM Account 
            WHERE Status__c = 'Prospect' 
            LIMIT 1
        ];
        
        List<Id> accountIds = new List<Id>{ prospectAccount.Id };
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getContactsByAccountIds(accountIds);
        Test.stopTest();
        
        // Assert
        System.assertEquals(0, results.size(), 'Should return no contacts for Prospect accounts');
    }
    
    @IsTest
    static void testGetContactsByAccountIdsEmptyList() {
        // Arrange
        List<Id> accountIds = new List<Id>();
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getContactsByAccountIds(accountIds);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for empty input');
    }
    
    @IsTest
    static void testGetContactsByAccountIdsNonExistentAccountIds() {
        // Arrange
        List<Id> accountIds = new List<Id>();
        // Create fake Account IDs that don't exist
        String fakeId = '001000000000000AAA';
        accountIds.add(fakeId);
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getContactsByAccountIds(accountIds);
        Test.stopTest();
        
        // Assert
        System.assertEquals(0, results.size(), 'Should return empty list for non-existent account IDs');
    }
    
    @IsTest
    static void testGetAdditionalContactsWithValidAccounts() {
        // Arrange
        List<Account> accounts = [
            SELECT Id 
            FROM Account 
            WHERE Status__c != 'Prospect'
        ];
        
        List<Id> accountIds = new List<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getAdditionalContacts(accountIds);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(2, results.size(), 'Should return 2 additional billing contacts');
        
        // Verify all returned contacts have Additional Billing Contact role
        for (Contact con : results) {
            System.assertEquals('Additional Billing Contact', con.Role__c, 
                'All contacts should have Additional Billing Contact role');
            System.assertNotEquals('Prospect', con.Account.Status__c, 
                'Account should not be a Prospect');
            System.assertNotEquals(null, con.Email, 'Email should be populated');
        }
    }
    
    @IsTest
    static void testGetAdditionalContactsExcludesProspectAccounts() {
        // Arrange
        Account prospectAccount = [
            SELECT Id 
            FROM Account 
            WHERE Status__c = 'Prospect' 
            LIMIT 1
        ];
        
        List<Id> accountIds = new List<Id>{ prospectAccount.Id };
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getAdditionalContacts(accountIds);
        Test.stopTest();
        
        // Assert
        System.assertEquals(0, results.size(), 
            'Should return no additional contacts for Prospect accounts');
    }
    
    @IsTest
    static void testGetAdditionalContactsEmptyList() {
        // Arrange
        List<Id> accountIds = new List<Id>();
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getAdditionalContacts(accountIds);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list for empty input');
    }
    
    @IsTest
    static void testGetAdditionalContactsExcludesPrimaryContacts() {
        // Arrange
        List<Account> accounts = [
            SELECT Id 
            FROM Account 
            WHERE Status__c = 'Live'
        ];
        
        List<Id> accountIds = new List<Id>();
        for (Account acc : accounts) {
            accountIds.add(acc.Id);
        }
        
        // Get count of Primary Billing Contacts for comparison
        Integer primaryContactCount = [
            SELECT COUNT() 
            FROM Contact 
            WHERE AccountId IN :accountIds 
            AND Role__c = 'Primary Billing Contact'
        ];
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getAdditionalContacts(accountIds);
        Test.stopTest();
        
        // Assert
        System.assert(primaryContactCount > 0, 'There should be primary contacts in test data');
        
        // Verify no Primary Billing Contacts are returned
        for (Contact con : results) {
            System.assertNotEquals('Primary Billing Contact', con.Role__c, 
                'Should not return Primary Billing Contacts');
        }
    }
    
    @IsTest
    static void testGetContactsByAccountIdsVerifyAllFieldsPopulated() {
        // Arrange
        Account activeAccount = [
            SELECT Id 
            FROM Account 
            WHERE Status__c = 'Live' 
            LIMIT 1
        ];
        
        List<Id> accountIds = new List<Id>{ activeAccount.Id };
        
        // Act
        Test.startTest();
        List<Contact> results = ContactSelector.getContactsByAccountIds(accountIds);
        Test.stopTest();
        
        // Assert
        System.assert(results.size() > 0, 'Should return at least one contact');
        
        Contact testContact = results[0];
        
        // Verify Contact fields
        System.assertNotEquals(null, testContact.Id, 'Contact Id should be populated');
        System.assertNotEquals(null, testContact.FirstName, 'FirstName should be populated');
        System.assertNotEquals(null, testContact.LastName, 'LastName should be populated');
        System.assertNotEquals(null, testContact.Email, 'Email should be populated');
        System.assertNotEquals(null, testContact.Role__c, 'Role should be populated');
        
        // Verify Account fields
        System.assertNotEquals(null, testContact.AccountId, 'AccountId should be populated');
        System.assertNotEquals(null, testContact.Account.Name, 'Account Name should be populated');
        System.assertNotEquals(null, testContact.Account.Status__c, 'Account Status should be populated');
    }
}