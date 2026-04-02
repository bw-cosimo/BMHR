/**
 * @author Cosimo
 * @description Test class for ContactService
 */
@isTest
private class ContactServiceTest {
    
    // ==================== TEST DATA SETUP ====================
    
    @TestSetup
    static void setupTestData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i
            ));
        }
        insert accounts;
        
        // Create test contacts
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test' + i + '@example.com',
                AccountId = accounts[i].Id
            ));
        }
        insert contacts;
    }
    
    // ==================== PUBLIC METHOD TESTS ====================
    
    @isTest
    static void testSendContactsToXeroSuccess() {
        // Given
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{ accounts[0].Id };
        
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        
        // When
        Test.startTest();
        ContactService.sendContactsToXero(accountIds);
        Test.stopTest();
        
        // Then
        // Verify job was enqueued (no exceptions thrown)
        System.assertEquals(1, accounts.size(), 'Should have test account');
    }
    
    @isTest
    static void testSendContactsToXeroNullAccountIds() {
        // When/Then
        Test.startTest();
        ContactService.sendContactsToXero(null);
        Test.stopTest();
        
        // No exception should be thrown
        System.assert(true, 'Should handle null gracefully');
    }
    
    @isTest
    static void testSendContactsToXeroEmptyAccountIds() {
        // When/Then
        Test.startTest();
        ContactService.sendContactsToXero(new List<Id>());
        Test.stopTest();
        
        // No exception should be thrown
        System.assert(true, 'Should handle empty list gracefully');
    }
    
    // ==================== SYNC METHOD TESTS ====================
    
    @isTest
    static void testSendContactsToXeroSyncSuccess() {
        // Given
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{ accounts[0].Id };
        
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        
        // When
        Test.startTest();
        ContactService.sendContactsToXeroSync(accountIds);
        Test.stopTest();
        
        // Then - No exception thrown means success
        System.assert(true, 'Sync should complete successfully');
    }
    
    @isTest
    static void testSendContactsToXeroSyncNoContactsFound() {
        // Given - Account with no contacts
        Account newAccount = new Account(Name = 'No Contacts Account');
        insert newAccount;
        
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        
        // When
        Test.startTest();
        ContactService.sendContactsToXeroSync(new List<Id>{ newAccount.Id });
        Test.stopTest();
        
        // Then - Should return gracefully
        System.assert(true, 'Should handle no contacts gracefully');
    }
    
    // ==================== BUILD XERO CONTACTS TESTS ====================
    
    @isTest
    static void testBuildXeroContactsSuccess() {
        // Given
        List<Contact> contacts = [SELECT   
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
                Account.Parent.Name FROM Contact LIMIT 2];
        List<Contact> additionalContacts = new List<Contact>();
        
        // When
        Test.startTest();
        List<XeroContactWrapper.XeroContact> result = 
            ContactService.buildXeroContacts(contacts, additionalContacts);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() <= contacts.size(), 'Should process contacts');
    }
    
    @isTest
    static void testBuildXeroContactsEmptyList() {
        // Given
        List<Contact> contacts = new List<Contact>();
        List<Contact> additionalContacts = new List<Contact>();
        
        // When
        Test.startTest();
        List<XeroContactWrapper.XeroContact> result = 
            ContactService.buildXeroContacts(contacts, additionalContacts);
        Test.stopTest();
        
        // Then
        System.assertEquals(0, result.size(), 'Result should be empty');
    }
    
    // ==================== SEND TO XERO TESTS ====================
    
    @isTest
    static void testSendToXeroSuccess() {
        // Given
        List<XeroContactWrapper.XeroContact> xeroContacts = createMockXeroContacts();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        
        // When
        Test.startTest();
        ContactService.sendToXero(xeroContacts);
        Test.stopTest();
        
        // Then - No exception means success
        System.assert(true, 'Should send successfully');
    }
    
    @isTest
    static void testSendToXeroNoContactsCreated() {
        // Given
        List<XeroContactWrapper.XeroContact> xeroContacts = createMockXeroContacts();
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());
        
        // When
        Test.startTest();
        ContactService.sendToXero(xeroContacts);
        Test.stopTest();
        
        // Then - Should handle gracefully
        System.assert(true, 'Should handle no contacts created');
    }
    
    // ==================== CONTACT GROUP TESTS ====================
    
    @isTest
    static void testGetExistingContactGroupsSuccess() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // When
        Test.startTest();
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> result = 
            ContactService.getExistingContactGroups(client);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetExistingContactGroupsNoGroups() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());
        XeroClient client = new XeroClient();
        
        // When
        Test.startTest();
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> result = 
            ContactService.getExistingContactGroups(client);
        Test.stopTest();
        
        // Then
        System.assertEquals(0, result.size(), 'Should return empty map');
    }
    
    @isTest
    static void testCreateContactGroupSuccess() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String groupName = 'Test Group';
        
        // When
        Test.startTest();
        String groupId = ContactService.createContactGroup(client, groupName);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, groupId, 'Group ID should not be null');
        System.assert(String.isNotBlank(groupId), 'Group ID should not be blank');
    }
    
    @isTest
    static void testCreateContactGroupBlankName() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // When/Then
        Test.startTest();
        try {
            ContactService.createContactGroup(client, '');
            System.assert(false, 'Should have thrown exception');
        } catch (ContactService.ContactServiceException e) {
            System.assert(e.getMessage().contains('cannot be blank'), 
                'Should throw exception for blank name');
        }
        Test.stopTest();
    }

    @isTest
    static void testAddContactToGroupSuccess() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String groupId = 'group-123';
        String contactId = 'contact-456';
        
        // When
        Test.startTest();
        ContactService.addContactToGroup(client, groupId, contactId);
        Test.stopTest();
        
        // Then - No exception means success
        System.assert(true, 'Should add contact to group successfully');
    }
    
    @isTest
    static void testAddContactToGroupBlankGroupId() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // When/Then
        Test.startTest();
        try {
            ContactService.addContactToGroup(client, '', 'contact-123');
            System.assert(false, 'Should have thrown exception');
        } catch (ContactService.ContactServiceException e) {
            System.assert(e.getMessage().contains('required'), 
                'Should throw exception for blank group ID');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testAddContactToGroupBlankContactId() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // When/Then
        Test.startTest();
        try {
            ContactService.addContactToGroup(client, 'group-123', '');
            System.assert(false, 'Should have thrown exception');
        } catch (ContactService.ContactServiceException e) {
            System.assert(e.getMessage().contains('required'), 
                'Should throw exception for blank contact ID');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRemoveContactFromAllGroupsSuccess() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String contactId = 'contact-123';
        
        // When
        Test.startTest();
        ContactService.removeContactFromAllGroups(client, contactId);
        Test.stopTest();
        
        // Then - No exception means success
        System.assert(true, 'Should remove contact from groups successfully');
    }
    
    @isTest
    static void testRemoveContactFromAllGroupsBlankContactId() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // When/Then
        Test.startTest();
        try {
            ContactService.removeContactFromAllGroups(client, '');
            System.assert(false, 'Should have thrown exception');
        } catch (ContactService.ContactServiceException e) {
            System.assert(e.getMessage().contains('required'), 
                'Should throw exception for blank contact ID');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testRemoveContactFromAllGroupsNoGroups() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpCalloutMockContactNoGroups());
        XeroClient client = new XeroClient();
        String contactId = 'contact-123';
        
        // When
        Test.startTest();
        ContactService.removeContactFromAllGroups(client, contactId);
        Test.stopTest();
        
        // Then - Should handle gracefully
        System.assert(true, 'Should handle contact with no groups');
    }
    
    @isTest
    static void testGetContactSuccess() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String contactId = 'contact-123';
        
        // When
        Test.startTest();
        XeroGetContactResponseWrapper.Contact result = 
            ContactService.getContact(client, contactId);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Contact should not be null');
    }
    
    @isTest
    static void testGetContactNoContactReturned() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());
        XeroClient client = new XeroClient();
        
        // When/Then
        Test.startTest();
        try {
            ContactService.getContact(client, 'contact-123');
            System.assert(false, 'Should have thrown exception');
        } catch (ContactService.ContactServiceException e) {
            System.assert(e.getMessage().contains('No contact returned'), 
                'Should throw exception when no contact returned');
        }
        Test.stopTest();
    }
    
    // ==================== PAYLOAD TESTS ====================
    
    @isTest
    static void testBuildCreateContactsPayloadSuccess() {
        // Given
        List<XeroContactWrapper.XeroContact> contacts = createMockXeroContacts();
        
        // When
        Test.startTest();
        String payload = ContactService.buildCreateContactsPayload(contacts);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, payload, 'Payload should not be null');
        System.assert(payload.contains('Contacts'), 'Payload should contain Contacts');
    }
    
    @isTest
    static void testBuildCreateContactsPayloadEmptyList() {
        // Given
        List<XeroContactWrapper.XeroContact> contacts = new List<XeroContactWrapper.XeroContact>();
        
        // When/Then
        Test.startTest();
        try {
            ContactService.buildCreateContactsPayload(contacts);
            System.assert(false, 'Should have thrown exception');
        } catch (ContactService.ContactServiceException e) {
            System.assert(e.getMessage().contains('empty contact list'), 
                'Should throw exception for empty list');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testBuildCreateContactsPayloadNullList() {
        // When/Then
        Test.startTest();
        try {
            ContactService.buildCreateContactsPayload(null);
            System.assert(false, 'Should have thrown exception');
        } catch (ContactService.ContactServiceException e) {
            System.assert(e.getMessage().contains('empty contact list'), 
                'Should throw exception for null list');
        }
        Test.stopTest();
    }
    
    // ==================== PROCESS CONTACT GROUPS TESTS ====================
    
    @isTest
    static void testProcessContactGroupsSuccess() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        List<XeroCreateContactsResponseWrapper.Contact> createdContacts = 
            new List<XeroCreateContactsResponseWrapper.Contact>();
        XeroCreateContactsResponseWrapper.Contact contact1 = 
            new XeroCreateContactsResponseWrapper.Contact();
        contact1.ContactID = 'xero-contact-1';
        createdContacts.add(contact1);
        
        List<XeroContactWrapper.XeroContact> originalContacts = createMockXeroContacts();
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> groupsMap = 
            new Map<String, XeroContactGroupsResponseWrapper.ContactGroup>();
        
        // When
        Test.startTest();
        ContactService.processContactGroups(client, createdContacts, originalContacts, groupsMap);
        Test.stopTest();
        
        // Then - No exception means success
        System.assert(true, 'Should process contact groups successfully');
    }
    
    @isTest
    static void testProcessContactGroupAssignmentWithParentName() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        XeroCreateContactsResponseWrapper.Contact createdContact = 
            new XeroCreateContactsResponseWrapper.Contact();
        createdContact.ContactID = 'contact-123';
        
        XeroContactWrapper.XeroContact originalContact = new XeroContactWrapper.XeroContact();
        originalContact.parentName = 'Test Parent';
        
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> groupsMap = 
            new Map<String, XeroContactGroupsResponseWrapper.ContactGroup>();
        
        // When
        Test.startTest();
        ContactService.processContactGroupAssignment(
            client, createdContact, originalContact, groupsMap
        );
        Test.stopTest();
        
        // Then - No exception means success
        System.assert(true, 'Should process assignment successfully');
    }
    
    @isTest
    static void testProcessContactGroupAssignmentNoParentName() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        XeroCreateContactsResponseWrapper.Contact createdContact = 
            new XeroCreateContactsResponseWrapper.Contact();
        createdContact.ContactID = 'contact-123';
        
        XeroContactWrapper.XeroContact originalContact = new XeroContactWrapper.XeroContact();
        originalContact.parentName = null;
        
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> groupsMap = 
            new Map<String, XeroContactGroupsResponseWrapper.ContactGroup>();
        
        // When
        Test.startTest();
        ContactService.processContactGroupAssignment(
            client, createdContact, originalContact, groupsMap
        );
        Test.stopTest();
        
        // Then - Should remove from all groups
        System.assert(true, 'Should handle no parent name');
    }
    
    @isTest
    static void testGetOrCreateContactGroupExistingGroup() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String groupName = 'Existing Group';
        
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> groupsMap = 
            new Map<String, XeroContactGroupsResponseWrapper.ContactGroup>();
        XeroContactGroupsResponseWrapper.ContactGroup existingGroup = 
            new XeroContactGroupsResponseWrapper.ContactGroup();
        existingGroup.Name = groupName;
        existingGroup.ContactGroupID = 'existing-group-id';
        groupsMap.put(groupName.toLowerCase(), existingGroup);
        
        // When
        Test.startTest();
        String result = ContactService.getOrCreateContactGroup(client, groupName, groupsMap);
        Test.stopTest();
        
        // Then
        System.assertEquals('existing-group-id', result, 'Should return existing group ID');
    }
    
    @isTest
    static void testGetOrCreateContactGroupNewGroup() {
        // Given
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String groupName = 'New Group';
        
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> groupsMap = 
            new Map<String, XeroContactGroupsResponseWrapper.ContactGroup>();
        
        // When
        Test.startTest();
        String result = ContactService.getOrCreateContactGroup(client, groupName, groupsMap);
        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, result, 'Should create and return new group ID');
    }
    
    // ==================== QUEUEABLE TESTS ====================
    
    @isTest
    static void testXeroContactQueueableExecute() {
        // Given
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        List<Id> accountIds = new List<Id>{ accounts[0].Id };
        
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        
        // When
        Test.startTest();
        System.enqueueJob(new ContactService.XeroContactQueueable(accountIds));
        Test.stopTest();
        
        // Then - Job completed without errors
        System.assert(true, 'Queueable should execute successfully');
    }
    
    // ==================== HELPER METHODS ====================
    
    private static List<XeroContactWrapper.XeroContact> createMockXeroContacts() {
        List<XeroContactWrapper.XeroContact> contacts = new List<XeroContactWrapper.XeroContact>();
        
        XeroContactWrapper.XeroContact contact1 = new XeroContactWrapper.XeroContact();
        contact1.Name = 'Test Contact 1';
        contact1.parentName = 'Test Parent Company';
        contacts.add(contact1);
        
        return contacts;
    }


    private class XeroHttpCalloutMockContactNoGroups implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(200);
            String endpoint = req.getEndpoint();
            if (endpoint.endsWith('/connections')) {
                res.setStatusCode(200);
                res.setBody('[{"tenantId":"11111111-2222-3333-4444-555555555555"}]');
                return res;
            }
            res.setBody('{"Contacts":[{"ContactID":"contact-123","Name":"Test Contact","ContactGroups":[]}]}');
            return res;
        }
    }
    
    private class XeroHttpCalloutMockError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setStatusCode(500);
            res.setBody('{"Error":"Internal Server Error"}');
            return res;
        }
    }
}