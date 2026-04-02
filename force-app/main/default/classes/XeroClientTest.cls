@IsTest
private class XeroClientTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account for use in mock responses
        Account testAccount = new Account(
            Name = 'Test Account for Xero'
        );
        insert testAccount;
    }
    
    // ========== Constructor and Tenant ID Tests ==========
    
    @IsTest
    static void testConstructorSuccessfullyFetchesTenantId() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        
        // Act
        Test.startTest();
        XeroClient client = new XeroClient();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, client, 'Client should be instantiated');
        // Tenant ID is private but we can verify through subsequent calls
    }
    
    @IsTest
    static void testFetchTenantIdFailedRequest() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        
        // Act & Assert - This should still work as FailureInvoices returns 200 for /connections
        Test.startTest();
        XeroClient client = new XeroClient();
        System.assertNotEquals(null, client, 'Client should be created successfully');
        Test.stopTest();
    }
    
    // ========== Create Contacts Tests ==========
    
    @IsTest
    static void testCreateContactsSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        String payload = '{"Contacts":[{"Name":"Test Contact","EmailAddress":"test@example.com"}]}';
        
        // Act
        Test.startTest();
        XeroCreateContactsResponseWrapper response = client.createContacts(payload);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.Contacts, 'Contacts list should not be null');
    }
    
    @IsTest
    static void testCreateContactsFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        
        String payload = '{"Contacts":[{"Name":"Test Contact"}]}';
        
        // Act & Assert
        Test.startTest();
        try {
            XeroCreateContactsResponseWrapper response = client.createContacts(payload);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to create contacts'), 
                'Exception should indicate contact creation failure');
        }
        Test.stopTest();
    }
    
    // ========== Get Contact Groups Tests ==========
    
    @IsTest
    static void testGetContactGroupsSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // Act
        Test.startTest();
        XeroContactGroupsResponseWrapper response = client.getContactGroups();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.ContactGroups, 'ContactGroups should not be null');
        System.assert(response.ContactGroups.size() > 0, 'Should return at least one contact group');
    }
    
    @IsTest
    static void testGetContactGroupsEmptyResponse() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());
        XeroClient client = new XeroClient();
        
        // Act
        Test.startTest();
        XeroContactGroupsResponseWrapper response = client.getContactGroups();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(0, response.ContactGroups.size(), 'Should return empty list');
    }
    
    @IsTest
    static void testGetContactGroupsFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        
        // Act & Assert
        Test.startTest();
        try {
            XeroContactGroupsResponseWrapper response = client.getContactGroups();
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to fetch contact groups'), 
                'Exception should indicate contact groups fetch failure');
        }
        Test.stopTest();
    }
    
    // ========== Get Contact Tests ==========
    
    @IsTest
    static void testGetContactSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String contactNumber = 'CONT-001';
        
        // Act
        Test.startTest();
        XeroGetContactResponseWrapper response = client.getContact(contactNumber);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertNotEquals(null, response.Contacts, 'Contacts should not be null');
        System.assert(response.Contacts.size() > 0, 'Should return at least one contact');
    }
    
    @IsTest
    static void testGetContactEmptyResponse() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());
        XeroClient client = new XeroClient();
        String contactNumber = 'CONT-999';
        
        // Act
        Test.startTest();
        XeroGetContactResponseWrapper response = client.getContact(contactNumber);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assertEquals(0, response.Contacts.size(), 'Should return empty contact list');
    }
    
    @IsTest
    static void testGetContactFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        String contactNumber = 'CONT-001';
        
        // Act & Assert
        Test.startTest();
        try {
            XeroGetContactResponseWrapper response = client.getContact(contactNumber);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to fetch contact'), 
                'Exception should indicate contact fetch failure');
        }
        Test.stopTest();
    }
    
    // ========== Create Contact Group Tests ==========
    
    @IsTest
    static void testCreateContactGroupSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String payload = '{"Name":"New Test Group"}';
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.createContactGroup(payload);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.containsKey('ContactGroups'), 'Response should contain ContactGroups');
    }
    
    @IsTest
    static void testCreateContactGroupFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        String payload = '{"Name":"New Test Group"}';
        
        // Act & Assert
        Test.startTest();
        try {
            Map<String, Object> response = client.createContactGroup(payload);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to create contact groups'), 
                'Exception should indicate contact group creation failure');
        }
        Test.stopTest();
    }
    
    // ========== Update Contact Group Tests ==========
    
    @IsTest
    static void testUpdateContactGroupSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String contactGroupId = 'group-123';
        String payload = '{"Contacts":[{"ContactID":"contact-456"}]}';
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.updateContactGroup(contactGroupId, payload);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.containsKey('ContactGroups'), 'Response should contain ContactGroups');
    }
    
    @IsTest
    static void testUpdateContactGroupFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        String contactGroupId = 'group-123';
        String payload = '{"Contacts":[{"ContactID":"contact-456"}]}';
        
        // Act & Assert
        Test.startTest();
        try {
            Map<String, Object> response = client.updateContactGroup(contactGroupId, payload);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to update contact groups'), 
                'Exception should indicate contact group update failure');
        }
        Test.stopTest();
    }
    
    // ========== Delete Contact From Contact Group Tests ==========
    
    @IsTest
    static void testDeleteContactFromContactGroupSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String contactGroupId = 'group-123';
        String contactId = 'contact-456';
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.deleteContactFromContactGroup(contactGroupId, contactId);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.containsKey('Status'), 'Response should contain Status');
    }
    
    @IsTest
    static void testDeleteContactFromContactGroupFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        String contactGroupId = 'group-123';
        String contactId = 'contact-456';
        
        // Act & Assert
        Test.startTest();
        try {
            Map<String, Object> response = client.deleteContactFromContactGroup(contactGroupId, contactId);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to remove contact from contact groups'), 
                'Exception should indicate contact removal failure');
        }
        Test.stopTest();
    }
    
    // ========== Get Invoices Tests ==========
    
    @IsTest
    static void testGetInvoicesSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.getInvoices();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.containsKey('Invoices'), 'Response should contain Invoices');
        
        List<Object> invoices = (List<Object>) response.get('Invoices');
        System.assertNotEquals(null, invoices, 'Invoices list should not be null');
        System.assertEquals(2, invoices.size(), 'Should return 2 invoices from mock');
    }
    
    @IsTest
    static void testGetInvoicesEmptyResponse() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());
        XeroClient client = new XeroClient();
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.getInvoices();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.containsKey('Invoices'), 'Response should contain Invoices');
        
        List<Object> invoices = (List<Object>) response.get('Invoices');
        System.assertEquals(0, invoices.size(), 'Should return empty invoices list');
    }
    
    @IsTest
    static void testGetInvoicesFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        
        // Act & Assert
        Test.startTest();
        try {
            Map<String, Object> response = client.getInvoices();
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to fetch invoices'), 
                'Exception should indicate invoice fetch failure');
        }
        Test.stopTest();
    }
    
    // ========== Get Invoices Since Last Modified Tests ==========
    
    @IsTest
    static void testGetInvoicesSinceLastModifiedSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String lastModified = '2025-01-01T00:00:00';
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.getInvoicesSinceLastModified(lastModified);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        System.assert(response.containsKey('Invoices'), 'Response should contain Invoices');
        
        List<Object> invoices = (List<Object>) response.get('Invoices');
        System.assertNotEquals(null, invoices, 'Invoices list should not be null');
    }
    
    @IsTest
    static void testGetInvoicesSinceLastModifiedEmptyResponse() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Empty());
        XeroClient client = new XeroClient();
        String lastModified = '2025-01-01T00:00:00';
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.getInvoicesSinceLastModified(lastModified);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should not be null');
        
        List<Object> invoices = (List<Object>) response.get('Invoices');
        System.assertEquals(0, invoices.size(), 'Should return empty invoices list');
    }
    
    @IsTest
    static void testGetInvoicesSinceLastModifiedFailure() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.FailureInvoices());
        XeroClient client = new XeroClient();
        String lastModified = '2025-01-01T00:00:00';
        
        // Act & Assert
        Test.startTest();
        try {
            Map<String, Object> response = client.getInvoicesSinceLastModified(lastModified);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('Failed to fetch invoices'), 
                'Exception should indicate invoice fetch failure');
        }
        Test.stopTest();
    }
    
    // ========== Integration Tests ==========
    
    @IsTest
    static void testMultipleCalloutsSuccess() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // Act
        Test.startTest();
        XeroContactGroupsResponseWrapper groups = client.getContactGroups();
        Map<String, Object> invoices = client.getInvoices();
        XeroGetContactResponseWrapper contact = client.getContact('CONT-001');
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, groups, 'Contact groups should not be null');
        System.assertNotEquals(null, invoices, 'Invoices should not be null');
        System.assertNotEquals(null, contact, 'Contact should not be null');
    }
    
    @IsTest
    static void testMakeCalloutWithBlankBody() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        
        // Act - GET request with no body
        Test.startTest();
        Map<String, Object> response = client.getInvoices();
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should handle null body correctly');
    }
    
    @IsTest
    static void testMakeCalloutWithLastModifiedHeader() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new XeroHttpMocks.Success());
        XeroClient client = new XeroClient();
        String lastModified = 'Wed, 01 Jan 2025 00:00:00 GMT';
        
        // Act
        Test.startTest();
        Map<String, Object> response = client.getInvoicesSinceLastModified(lastModified);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, response, 'Response should handle If-Modified-Since header');
    }
}