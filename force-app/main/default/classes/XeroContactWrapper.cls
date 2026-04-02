public class XeroContactWrapper {
    public class XeroContact {
        public String ContactNumber;
        public String ContactStatus;
        public String Name;
        public String FirstName;
        public String LastName;
        public String CompanyNumber;
        public String EmailAddress;
        public List<Address> Addresses;
        public List<ContactPersons> ContactPersons;
        public Boolean IsSupplier;
        public Boolean IsCustomer;
        public String parentName;

        public XeroContact() {
            Addresses = new List<Address>();
            ContactPersons = new List<ContactPersons>();
        }
    }

    // Address Wrapper
    public class Address {
        public String AddressType;      // POBOX, STREET, DELIVERY, etc.
        public String AddressLine1;
        public String AddressLine2;
        public String City;
        public String Region;
        public String PostalCode;
        public String Country;
    }


    // Payment Terms Wrapper
    public class ContactPersons {
        public String FirstName;
        public String LastName;
        public String EmailAddress;
        public Boolean IncludeInEmails;
    }


    /* =====================================================================================
       BUILDER METHOD TO GENERATE XERO CONTACT FROM SALESFORCE ACCOUNT + CONTACT
       ===================================================================================== */
    public static XeroContact buildFromSalesforce(Contact con, List<Contact> contactPeople) {
        XeroContact x = new XeroContact();

        // Basic Identity Fields
        x.Name = con.Account.Name;
        x.ContactNumber = con.AccountId;
        x.FirstName = con.FirstName;
        x.LastName  = con.LastName;
        x.EmailAddress = con.Email;
        x.ContactStatus = 'ACTIVE';
        x.parentName = con.Account.Parent.Name;


        // Addresses
        XeroContactWrapper.Address addr = new XeroContactWrapper.Address();
        addr.AddressType = 'POBOX';
        addr.AddressLine1 = con.Account.BillingStreet;
        addr.City = con.Account.BillingCity;
        addr.Region = con.Account.BillingState;
        addr.PostalCode = con.Account.BillingPostalCode;
        addr.Country = con.Account.BillingCountry;

        x.Addresses.add(addr);

        for (Contact contactPerson : contactPeople) {
            if (x.ContactPersons.size() == 5) {
                break;
            }

            if (contactPerson.Id == con.Id) {
                continue;
            }

            XeroContactWrapper.ContactPersons contactPersonWrapper = new XeroContactWrapper.ContactPersons();
            contactPersonWrapper.FirstName = contactPerson.FirstName;
            contactPersonWrapper.LastName = contactPerson.LastName;
            contactPersonWrapper.EmailAddress = contactPerson.Email;
            contactPersonWrapper.IncludeInEmails = true;
            x.ContactPersons.add(contactPersonWrapper);
        }
        x.IsSupplier = con.Account.RecordType.DeveloperName == 'Partner';
        x.IsCustomer = con.Account.RecordType.DeveloperName == 'Client';

        return x;
    }


    /* =====================================================================================
       JSON HELPER
       ===================================================================================== */
    public static String toJson(XeroContact contact) {
        return JSON.serialize(contact);
    }
}