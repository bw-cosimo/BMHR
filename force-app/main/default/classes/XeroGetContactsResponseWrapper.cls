public with sharing class XeroGetContactsResponseWrapper {
    public List<ContactMinimal> Contacts;

    public class ContactMinimal {
        public String ContactID;
        public String DefaultCurrency;
        public Balances Balances;
    }

    public class Balances {
        public SubBalance AccountsReceivable;
        public SubBalance AccountsPayable;
    }

    public class SubBalance {
        public Decimal Outstanding;
        public Decimal Overdue;
    }

    public static XeroGetContactsResponseWrapper parse(String jsonStr) {
        return (XeroGetContactsResponseWrapper) System.JSON.deserialize(jsonStr, XeroGetContactsResponseWrapper.class);
    }
}