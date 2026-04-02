/**
 * @author Cosimo
 * @description Apex service client for interacting with the Xero Accounting API.
 *              Handles authentication via Named Credentials, retrieves tenant ID,
 *              and exposes helper methods for Contacts, Contact Groups, and Invoices.
 */
public with sharing class XeroClient {
    /**
     * @description Named Credential used for authenticated Xero API callouts.
     */
    private static final String NAMED_CREDENTIAL = 'callout:Xero_Integration';

    /**
     * @description API version for Xero Accounting endpoints.
     */
    private static final String VERSION = '/2.0';

    /**
     * @description Xero API base path prefix.
     */
    private static final String PREFIX = '/api.xro';

    /**
     * @description Holds the tenantId resolved from the /connections API.
     */
    private String tenantId;

    /**
     * @description Initializes the client. TenantId will be lazily resolved on first non-/connections call.
     */
    public XeroClient() {
        // Defer tenant lookup to first API call to avoid constructor callouts in Flow contexts.
        this.tenantId = null;
    }

    /**
     * @description Calls Xero `/connections` to retrieve the tenant ID associated
     *              with the authenticated user. This endpoint DOES NOT require
     *              the `xero-tenant-id` header.
     *
     * @return The tenantId (String) required for subsequent Xero API calls.
     * @throws CalloutException when no tenants are returned or request fails.
     */
    private String fetchTenantId() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/connections');
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');

        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            List<XeroConnectionWrapper> items =
                (List<XeroConnectionWrapper>) JSON.deserialize(
                    res.getBody(),
                    List<XeroConnectionWrapper>.class
                );

            if (!items.isEmpty()) {
                return items[0].tenantId;
            }

            throw new CalloutException('No tenants returned from Xero');
        }

        throw new CalloutException('Failed to fetch tenants: ' + res.getBody());
    }

    /**
     * @description Ensure tenantId is available; lazily fetch from /connections if needed.
     */
    private void ensureTenantId() {
        if (String.isBlank(this.tenantId)) {
            this.tenantId = fetchTenantId();
        }
    }

    /**
     * @description Internal helper for authenticated Xero REST API calls.
     *
     * @param endpoint The Xero API endpoint path, excluding Named Credential prefix.
     * @param method   HTTP verb (GET, POST, PUT).
     * @param body     JSON request body or null.
     * @param lastModified Optional If-Modified-Since header value in GMT (UTC).
     *
     * @return HttpResponse from the callout.
     */
    private HttpResponse makeCallout(String endpoint, String method, String body, String lastModified) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + endpoint);
        req.setMethod(method);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');

        // /connections does NOT require xero-tenant-id and must not attempt to resolve it before calling
        Boolean isConnections = endpoint == '/connections' || endpoint.endsWith('/connections');
        if (!isConnections) {
            ensureTenantId();
            if (!String.isBlank(tenantId)) {
                req.setHeader('xero-tenant-id', tenantId);
            }
        }

        if (lastModified != null) {
            req.setHeader('If-Modified-Since', lastModified);
        }

        if (String.isNotBlank(body)) {
            req.setBody(body);
        }

        return http.send(req);
    }

    /**
     * @description Creates one or more Xero contacts. Expects payload in the form:
     *              { "Contacts": [ {...}, {...} ] }
     *
     * @param payload JSON serialized contact list.
     * @return Parsed XeroCreateContactsResponseWrapper containing created contacts.
     *
     * @throws CalloutException when Xero returns an error.
     */
    public XeroCreateContactsResponseWrapper createContacts(String payload) {
        HttpResponse response = makeCallout(PREFIX + VERSION + '/Contacts', 'POST', payload, null);

        if (response.getStatusCode() == 200) {
            return (XeroCreateContactsResponseWrapper)
                JSON.deserialize(response.getBody(), XeroCreateContactsResponseWrapper.class);
        }

        throw new CalloutException('Failed to create contacts: ' + response.getBody());
    }

    /**
     * @description Retrieves all Xero Contact Groups.
     *
     * @return XeroContactGroupsResponseWrapper containing list of groups.
     * @throws CalloutException if fetch fails.
     */
    public XeroContactGroupsResponseWrapper getContactGroups() {
        HttpResponse response = makeCallout(PREFIX + VERSION + '/ContactGroups', 'GET', null, null);

        if (response.getStatusCode() == 200) {
            return (XeroContactGroupsResponseWrapper)
                JSON.deserialize(response.getBody(), XeroContactGroupsResponseWrapper.class);
        }

        throw new CalloutException('Failed to fetch contact groups: ' + response.getBody());
    }

    /**
     * @description Get contact by contact Number
     *
     * @return XeroGetContactResponseWrapper containing list of contacts.
     * @throws CalloutException if fetch fails.
     */
    public XeroGetContactResponseWrapper getContact(String contactNumber) {
        HttpResponse response = makeCallout(PREFIX + VERSION + '/Contacts/' + contactNumber, 'GET', null, null);
        System.debug(response.getBody());

        if (response.getStatusCode() == 200) {
            XeroGetContactResponseWrapper res = (XeroGetContactResponseWrapper) JSON.deserialize(response.getBody(), XeroGetContactResponseWrapper.class);
            return res;
        }

        throw new CalloutException('Failed to fetch contact: ' + response.getBody());
    }

    /**
     * @description Creates a new contact group in Xero.
     *
     * @param payload JSON body defining { "Name": "GroupName" }.
     * @return Untyped Map deserialized from Xero response body.
     */
    public Map<String, Object> createContactGroup(String payload) {
        HttpResponse response = makeCallout(PREFIX + VERSION + '/ContactGroups', 'POST', payload, null);

        if (response.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        }

        throw new CalloutException('Failed to create contact groups: ' + response.getBody());
    }

    /**
     * @description Adds contacts to an existing Xero Contact Group.
     *
     * @param contactGroupId UUID of the Xero Contact Group.
     * @param payload JSON body in format: { "Contacts": [ {"ContactID": "..."} ] }
     *
     * @return Untyped Map representing Xero response.
     */
    public Map<String, Object> updateContactGroup(String contactGroupId, String payload) {
        HttpResponse response = makeCallout(
            PREFIX + VERSION + '/ContactGroups/' + contactGroupId + '/Contacts',
            'PUT',
            payload,
            null
        );

        if (response.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        }

        throw new CalloutException('Failed to update contact groups: ' + response.getBody());
    }

    /**
     * @description Removes contacts to an existing Xero Contact Group.
     *
     * @param contactGroupId UUID of the Xero Contact Group.
     * @param contactId The id of the contact that should be removed from the group.
     *
     * @return Untyped Map representing Xero response.
     */
    public Map<String, Object> deleteContactFromContactGroup(String contactGroupId, String contactId) {
        HttpResponse response = makeCallout(
            PREFIX + VERSION + '/ContactGroups/' + contactGroupId + '/Contacts/' + contactId,
            'DELETE',
            null,
            null
        );

        if (response.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        }

        throw new CalloutException('Failed to remove contact from contact groups: ' + response.getBody());
    }

    /**
     * @description Returns all invoices in the Xero tenant.
     *
     * @return Untyped Map representing invoices.
     */
    public Map<String, Object> getInvoices() {
        HttpResponse response = makeCallout(PREFIX + VERSION + '/Invoices', 'GET', null, null);

        if (response.getStatusCode() == 200) {
            Map<String, Object> s = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            System.debug(JSON.serializePretty(s));
            return s;
        }

        throw new CalloutException('Failed to fetch invoices: ' + response.getBody());
    }

    /**
     * @description Returns invoices modified since given timestamp.
     *
     * @param lastModified UTC timestamp formatted yyyy-MM-ddThh:mm:ss.
     * @return Untyped Map representing invoices.
     *
     * @throws CalloutException if request fails.
     */
    public Map<String, Object> getInvoicesSinceLastModified(String lastModified) {
        HttpResponse response = makeCallout(PREFIX + VERSION + '/Invoices?Statuses=AUTHORISED,PAID', 'GET', null, lastModified);

        if (response.getStatusCode() == 200) {
            Map<String, Object> s = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            System.debug(JSON.serializePretty(s));
            return s;
        }

        throw new CalloutException('Failed to fetch invoices: ' + response.getBody());
    }

    /**
     * @description Returns credit notes modified since given timestamp.
     *
     * @param lastModified UTC timestamp formatted yyyy-MM-ddThh:mm:ss.
     * @return Untyped Map representing credit notes.
     *
     * @throws CalloutException if request fails.
     */
    public Map<String, Object> getCreditNotesSinceLastModified(String lastModified) {
        HttpResponse response = makeCallout(PREFIX + VERSION + '/CreditNotes', 'GET', null, lastModified);

        if (response.getStatusCode() == 200) {
            Map<String, Object> s = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            System.debug(JSON.serializePretty(s));
            return s;
        }

        throw new CalloutException('Failed to fetch credit notes: ' + response.getBody());
    }

    /**
     * @description Retrieves Xero contacts by their IDs.
     *
     * @param ids List of Xero Contact IDs to fetch.
     * @return Untyped Map representing contacts.
     *
     * @throws CalloutException if request fails.
     */
    public Map<String, Object> getContactsByIds(List<String> ids) {
        if (ids == null || ids.isEmpty()) {
            throw new CalloutException('No contact IDs provided');
        }
        
        // Build the query parameter with comma-separated IDs
        String idsParam = String.join(ids, ',');
        String endpoint = PREFIX + VERSION + '/Contacts/?IDs=' + idsParam;
        
        HttpResponse response = makeCallout(endpoint, 'GET', null, null);

        if (response.getStatusCode() == 200) {
            Map<String, Object> s = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            System.debug(JSON.serializePretty(s));
            return s;
        }

        throw new CalloutException('Failed to fetch contacts: ' + response.getBody());
    }
}