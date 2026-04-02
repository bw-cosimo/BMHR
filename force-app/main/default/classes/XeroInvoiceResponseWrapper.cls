public with sharing class XeroInvoiceResponseWrapper {
    public List<Invoice> Invoices;

    public class Invoice {
        public String CurrencyCode;
        public String UpdatedDateUTC;
        public Decimal Total;
        public Decimal TotalTax;
        public Decimal SubTotal;

        // Flexible typing for now; can be specialized later
        // public List<Object> LineItems;

        public String LineAmountTypes;
        public String Status;
        public String FullyPaidOnDate;

        public String DueDate;
        public String DueDateString;
        public String InvoiceDate;
        public String DateString;

        public Contact Contact;

        public Boolean HasErrors;
        public Boolean HasAttachments;
        public Boolean IsDiscounted;

        public Decimal CurrencyRate;
        public Decimal AmountCredited;
        public Decimal AmountPaid;
        public Decimal AmountDue;

        // public List<Object> CreditNotes;

        public String Reference;
        public String InvoiceNumber;
        public String InvoiceID;
        public String Type;
    }

    public class Contact {
        public Boolean HasValidationErrors;
        public String Name;
        public String ContactID;
    }

    // Convenience method to parse from JSON string
    public static XeroInvoiceResponseWrapper parse(String jsonStr) {
        return (XeroInvoiceResponseWrapper) System.JSON.deserialize(jsonStr, XeroInvoiceResponseWrapper.class);
    }
}