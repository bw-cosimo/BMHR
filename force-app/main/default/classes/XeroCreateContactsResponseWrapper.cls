public class XeroCreateContactsResponseWrapper {

    public String Id;
    public String Status;
    public String ProviderName;
    public List<Contact> Contacts;

    public class Contact {
        public String ContactID;
        public String ContactStatus;
        public String Name;
        public String EmailAddress;

        public Contact() {
            Name = '';
            EmailAddress = '';
        }
    }
}