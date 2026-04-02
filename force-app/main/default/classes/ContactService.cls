/**
 * @author Cosimo
 * @description Apex service for Contact object. 
 * Handles creation of Xero contact objects and API callouts
 */
public with sharing class ContactService {
    
    private static final String NO_CONTACTS_MSG = 'No contacts found for the provided account IDs';
    private static final String NO_GROUPS_MSG = 'No contact groups found in Xero';
    private static final String BLANK_GROUP_ERROR = 'Contact group name cannot be blank';

    private static List<Exception> deferredExceptions = new List<Exception>();
    
    /**
     * Sends contacts associated with given account IDs to Xero
     * Called from triggers - queues the callout asynchronously
     * @param accountIds List of Salesforce Account IDs
     */
    public static void sendContactsToXero(List<Id> accountIds) {
        if (isInvalidAccountIds(accountIds)) {
            return;
        }

        System.enqueueJob(new XeroContactQueueable(accountIds));
    }

    /**
     * Performs the actual sync to Xero (called by queueable)
     * @param accountIds List of Salesforce Account IDs
     */
    @TestVisible
    private static void sendContactsToXeroSync(List<Id> accountIds) {
        if (isInvalidAccountIds(accountIds)) {
            return;
        }

        try {
            List<Contact> contacts = ContactSelector.getContactsByAccountIds(accountIds);
            
            if (contacts.isEmpty()) {
                System.debug(NO_CONTACTS_MSG);
                return;
            }

            processContactsForXero(contacts, accountIds);
            
        } catch (Exception e) {
            handleError(e);
        }

        if (!deferredExceptions.isEmpty()) {
            List<Error_Log__c> logs = new List<Error_Log__c>();
            for (Exception e : deferredExceptions) {
                Error_Log__c log = ErrorUtility.build(
                    'ContactService: ' + e.getMessage(),
                    'Apex',
                    e.getStackTraceString()
                );
                logs.add(log);
            }
            ErrorUtility.insertLogs(logs, false);
        }
    }

    /**
     * Processes contacts for Xero sync
     * @param contacts List of Salesforce contacts
     */
    @TestVisible
    private static void processContactsForXero(List<Contact> contacts, List<Id> accountIds) {

        List<Contact> additionalContacts = ContactSelector.getAdditionalContacts(accountIds);
        List<XeroContactWrapper.XeroContact> xeroContacts = buildXeroContacts(contacts, additionalContacts);
        
        if (!xeroContacts.isEmpty()) {
            sendToXero(xeroContacts);
        }
    }

    /**
     * Builds Xero contact objects from Salesforce contacts
     * @param contacts List of Salesforce contacts
     * @param additionalContacts Additional contacts for reference
     * @return List of Xero contact wrapper objects
     */
    @TestVisible
    private static List<XeroContactWrapper.XeroContact> buildXeroContacts(
        List<Contact> contacts, 
        List<Contact> additionalContacts
    ) {
        List<XeroContactWrapper.XeroContact> xeroContacts = new List<XeroContactWrapper.XeroContact>();
        
        for (Contact contact : contacts) {
            XeroContactWrapper.XeroContact xeroContact = 
                XeroContactWrapper.buildFromSalesforce(contact, additionalContacts);
            
            if (xeroContact != null) {
                xeroContacts.add(xeroContact);
            }
        }
        
        return xeroContacts;
    }

    /**
     * Sends Xero contacts via API callout and manages contact groups
     * @param xeroContacts List of Xero contact objects
     */
    @TestVisible
    private static void sendToXero(List<XeroContactWrapper.XeroContact> xeroContacts) {
        String payload = buildCreateContactsPayload(xeroContacts);
        
        XeroClient client = new XeroClient();
        
        XeroCreateContactsResponseWrapper res = client.createContacts(payload);
        
        if (isInvalidContactResponse(res)) {
            System.debug('No contacts created in Xero');
            return;
        }
        
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> existingGroupsMap = 
            getExistingContactGroups(client);

        processContactGroups(client, res.Contacts, xeroContacts, existingGroupsMap);
    }

    /**
     * Retrieves and maps existing contact groups from Xero
     * @param client XeroClient instance
     * @return Map of lowercase group names to ContactGroup objects
     */
    @TestVisible
    private static Map<String, XeroContactGroupsResponseWrapper.ContactGroup> getExistingContactGroups(
        XeroClient client
    ) {
        XeroContactGroupsResponseWrapper response = client.getContactGroups();
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> groupsMap = 
            new Map<String, XeroContactGroupsResponseWrapper.ContactGroup>();
        
        if (response == null || response.ContactGroups == null) {
            System.debug(NO_GROUPS_MSG);
            return groupsMap;
        }
        
        for (XeroContactGroupsResponseWrapper.ContactGroup cg : response.ContactGroups) {
            if (String.isNotBlank(cg.Name)) {
                groupsMap.put(cg.Name.toLowerCase(), cg);
            }
        }
        
        return groupsMap;
    }

    /**
     * Processes contact group assignments for created contacts
     * @param client XeroClient instance
     * @param createdContacts List of contacts created in Xero
     * @param originalContacts Original Xero contact wrappers
     * @param existingGroupsMap Map of existing contact groups
     */
    @TestVisible
    private static void processContactGroups(
        XeroClient client,
        List<XeroCreateContactsResponseWrapper.Contact> createdContacts,
        List<XeroContactWrapper.XeroContact> originalContacts,
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> existingGroupsMap
    ) {
        Integer contactCount = Math.min(createdContacts.size(), originalContacts.size());
        Map<String, String> mapAccountIdXeroId = new Map<String, String>();
        for (Integer i = 0; i < contactCount; i++) {
            XeroCreateContactsResponseWrapper.Contact createdContact = createdContacts[i];
            XeroContactWrapper.XeroContact originalContact = originalContacts[i];
            mapAccountIdXeroId.put(originalContact.ContactNumber, createdContact.ContactID);
            processContactGroupAssignment(client, createdContact, originalContact, existingGroupsMap);
        }
        updateAccounts(mapAccountIdXeroId);
    }

    /**
     * Processes contact group assignment for a single contact
     * @param client XeroClient instance
     * @param createdContact Contact created in Xero
     * @param originalContact Original Xero contact wrapper
     * @param existingGroupsMap Map of existing contact groups
     */
    @TestVisible
    private static void processContactGroupAssignment(
        XeroClient client,
        XeroCreateContactsResponseWrapper.Contact createdContact,
        XeroContactWrapper.XeroContact originalContact,
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> existingGroupsMap
    ) {
        if (String.isBlank(originalContact.parentName)) {
            removeContactFromAllGroups(client, createdContact.ContactID);
            return;
        }
        
        String groupName = originalContact.parentName;
        String contactGroupId = getOrCreateContactGroup(client, groupName, existingGroupsMap);
        
        if (String.isNotBlank(contactGroupId) && String.isNotBlank(createdContact.ContactID)) {
            assignContactToGroup(client, contactGroupId, createdContact.ContactID, groupName);
        }
    }

    private static void updateAccounts(Map<String, String> mapAccountIdXeroId) {
        // Validate CRUD permissions before performing DML
        if (!Schema.sObjectType.Account.isUpdateable() || !Schema.sObjectType.Account.fields.Xero_Id__c.isUpdateable()) {
            handleError(new ContactServiceException('Insufficient permissions to update Account or Xero_Id__c field'));
            return;
        }

        List<Account> accounts = [SELECT Id, Xero_Id__c FROM Account WHERE Xero_Id__c = null AND Id in :mapAccountIdXeroId.keySet() WITH SECURITY_ENFORCED];
        List<Account> accountsToUpdate = new List<Account>();
        for (Account account : accounts) {
            String xeroId = mapAccountIdXeroId.get(account.Id);
            if (String.isNotBlank(xeroId)) {
                account.Xero_Id__c = xeroId;
                accountsToUpdate.add(account);
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            AccountTriggerHelper.isExecuting = true;
            update accountsToUpdate;
            AccountTriggerHelper.isExecuting = false;
        }
    }

    /**
     * Gets existing contact group ID or creates new group
     * @param client XeroClient instance
     * @param groupName Name of the contact group
     * @param existingGroupsMap Map of existing contact groups
     * @return ContactGroupID
     */
    @TestVisible
    private static String getOrCreateContactGroup(
        XeroClient client,
        String groupName,
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> existingGroupsMap
    ) {
        String groupNameLower = groupName.toLowerCase();
        
        if (existingGroupsMap.containsKey(groupNameLower)) {
            String groupId = existingGroupsMap.get(groupNameLower).ContactGroupID;
            return groupId;
        }
        
        return createNewContactGroup(client, groupName, existingGroupsMap);
    }

    /**
     * Creates a new contact group and adds it to the map
     * @param client XeroClient instance
     * @param groupName Name of the contact group
     * @param existingGroupsMap Map of existing contact groups
     * @return ContactGroupID
     */
    @TestVisible
    private static String createNewContactGroup(
        XeroClient client,
        String groupName,
        Map<String, XeroContactGroupsResponseWrapper.ContactGroup> existingGroupsMap
    ) {
        try {
            String contactGroupId = createContactGroup(client, groupName);
            
            XeroContactGroupsResponseWrapper.ContactGroup newGroup = 
                new XeroContactGroupsResponseWrapper.ContactGroup();
            newGroup.Name = groupName;
            newGroup.ContactGroupID = contactGroupId;
            existingGroupsMap.put(groupName.toLowerCase(), newGroup);
            return contactGroupId;
            
        } catch (Exception e) {
            handleError(e);
            return null;
        }
    }

    /**
     * Assigns a contact to a contact group
     * @param client XeroClient instance
     * @param contactGroupId ID of the contact group
     * @param contactId ID of the contact
     * @param groupName Name of the group (for logging)
     */
    @TestVisible
    private static void assignContactToGroup(
        XeroClient client,
        String contactGroupId,
        String contactId,
        String groupName
    ) {
        try {
            addContactToGroup(client, contactGroupId, contactId);
        } catch (Exception e) {
            handleError(e);
        }
    }

    /**
     * Creates a new contact group in Xero
     * @param client XeroClient instance
     * @param groupName Name of the contact group to create
     * @return ContactGroupID of the created group
     */
    @TestVisible
    private static String createContactGroup(XeroClient client, String groupName) {
        if (String.isBlank(groupName)) {
            throw new ContactServiceException(BLANK_GROUP_ERROR);
        }
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'Name' => groupName
        };
        
        Map<String, Object> responseMap = client.createContactGroup(JSON.serialize(requestBody));
        return extractContactGroupId(responseMap);
    }

    /**
     * Extracts ContactGroupID from API response
     * @param responseMap Response from Xero API
     * @return ContactGroupID
     */
    @TestVisible
    private static String extractContactGroupId(Map<String, Object> responseMap) {
        List<Object> contactGroups = (List<Object>) responseMap.get('ContactGroups');
        
        if (contactGroups == null || contactGroups.isEmpty()) {
            throw new ContactServiceException('Failed to create contact group: No group returned');
        }
        
        Map<String, Object> createdGroup = (Map<String, Object>) contactGroups[0];
        String contactGroupId = (String) createdGroup.get('ContactGroupID');
        
        if (String.isBlank(contactGroupId)) {
            throw new ContactServiceException('Failed to create contact group: No ID returned');
        }
        
        return contactGroupId;
    }

    /**
     * Adds a contact to a contact group in Xero
     * @param client XeroClient instance
     * @param contactGroupId ID of the contact group
     * @param contactId ID of the contact to add
     */
    @TestVisible
    private static void addContactToGroup(XeroClient client, String contactGroupId, String contactId) {
        validateContactGroupParams(contactGroupId, contactId);
        removeContactFromAllGroups(client, contactId);
        
        Map<String, Object> requestBody = new Map<String, Object>{
            'Contacts' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'ContactID' => contactId }
            }
        };
        
        client.updateContactGroup(contactGroupId, JSON.serialize(requestBody));
    }

    /**
     * Removes a contact from all contact groups in Xero
     * @param client XeroClient instance
     * @param contactId ID of the contact to remove
     */
    @TestVisible
    private static void removeContactFromAllGroups(XeroClient client, String contactId) {
        if (String.isBlank(contactId)) {
            throw new ContactServiceException('Contact ID is required');
        }
        
        try {
            XeroGetContactResponseWrapper.Contact contact = getContact(client, contactId);
            List<XeroGetContactResponseWrapper.ContactGroups> contactGroups = contact.ContactGroups;

            if (contactGroups != null && !contactGroups.isEmpty()) {
                String existingGroupId = contactGroups[0].ContactGroupID;
                client.deleteContactFromContactGroup(existingGroupId, contactId);
                System.debug('Removed contact ' + contactId + ' from group ' + existingGroupId);
            }
        } catch (Exception e) {
            handleError(e);
        }
    }

    /**
     * Retrieves a contact from Xero
     * @param client XeroClient instance
     * @param contactId ID of the contact to retrieve
     * @return Contact object
     */
    @TestVisible
    private static XeroGetContactResponseWrapper.Contact getContact(XeroClient client, String contactId) {
        XeroGetContactResponseWrapper contactsResponse = client.getContact(contactId);
        
        if (contactsResponse == null || contactsResponse.Contacts == null || contactsResponse.Contacts.isEmpty()) {
            throw new ContactServiceException('Failed to get contact: No contact returned');
        }

        return contactsResponse.Contacts[0];
    }

    /**
     * Builds JSON payload for creating contacts in Xero
     * @param contacts List of Xero contact wrapper objects
     * @return JSON string payload
     */
    @TestVisible
    private static String buildCreateContactsPayload(List<XeroContactWrapper.XeroContact> contacts) {
        if (contacts == null || contacts.isEmpty()) {
            throw new ContactServiceException('Cannot build payload with empty contact list');
        }

        XeroCreateContactsRequestWrapper req = new XeroCreateContactsRequestWrapper();
        req.Contacts.addAll(contacts);
        return JSON.serialize(req);
    }

    // ==================== UTILITY METHODS ====================

    /**
     * Validates if account IDs list is null or empty
     */
    private static Boolean isInvalidAccountIds(List<Id> accountIds) {
        return accountIds == null || accountIds.isEmpty();
    }

    /**
     * Validates if contact response is invalid
     */
    private static Boolean isInvalidContactResponse(XeroCreateContactsResponseWrapper res) {
        return res == null || res.Contacts == null || res.Contacts.isEmpty();
    }

    /**
     * Validates contact group parameters
     */
    private static void validateContactGroupParams(String contactGroupId, String contactId) {
        if (String.isBlank(contactGroupId) || String.isBlank(contactId)) {
            throw new ContactServiceException('Contact group ID and contact ID are required');
        }
    }

    /**
     * Handles errors consistently
     */
    private static void handleError(Exception e) {
        deferredExceptions.add(e);
    }

    // ==================== INNER CLASSES ====================

    /**
     * Custom exception for ContactService
     */
    public class ContactServiceException extends Exception {}

    /**
     * Queueable class to handle async callouts to Xero
     */
    public class XeroContactQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> accountIds;

        public XeroContactQueueable(List<Id> accountIds) {
            this.accountIds = accountIds;
        }

        public void execute(QueueableContext context) {
            ContactService.sendContactsToXeroSync(accountIds);
        }
    }
}