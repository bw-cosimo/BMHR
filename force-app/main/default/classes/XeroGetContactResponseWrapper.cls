public class XeroGetContactResponseWrapper {

    public List<Contact> Contacts;

    public class Contact {
        public String ContactID;
        public String ContactStatus;
        public String Name;
        public String FirstName;
        public String LastName;
        public String CompanyNumber;
        public String EmailAddress;
        public String BankAccountDetails;
        public String TaxNumber;
        public String AccountsReceivableTaxType;
        public String AccountsPayableTaxType;
        public List<Address> Addresses;
        public List<Phone> Phones;
        public String UpdatedDateUTC;
        public Boolean IsSupplier;
        public Boolean IsCustomer;
        public String DefaultCurrency;
        public List<ContactGroups> ContactGroups;

        public Contact() {
            Addresses = new List<Address>();
            Phones = new List<Phone>();
        }
    }

    public class Address {
        public String AddressType;
        public String AddressLine1;
        public String AddressLine2;
        public String City;
        public String Region;
        public String PostalCode;
        public String Country;
        public String AttentionTo;
    }

    public class Phone {
        public String PhoneType;
        public String PhoneNumber;
        public String PhoneAreaCode;
        public String PhoneCountryCode;
    }
    public class ContactGroups {
        public String ContactGroupID;
    }
}