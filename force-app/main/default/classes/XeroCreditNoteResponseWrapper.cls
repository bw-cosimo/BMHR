public with sharing class XeroCreditNoteResponseWrapper {
    public List<CreditNote> CreditNotes;

    public class CreditNote {
        public String CurrencyCode;
        public String UpdatedDateUTC;
        public Decimal Total;
        public Decimal TotalTax;
        public Decimal SubTotal;
        public String LineAmountTypes;
        public String Status;
        public String FullyPaidOnDate;
        public String DateString;
        public String Date_x;
        public Contact Contact;
        public Decimal CurrencyRate;
        public String Type;
        public String CreditNoteID;
        public String CreditNoteNumber;
        public Decimal RemainingCredit;
        public List<Allocation> Allocations;
    }

    public class Contact {
        public Boolean HasValidationErrors;
        public String Name;
        public String ContactID;
    }

    public class Allocation {
        public String AllocationID;
        public Decimal Amount;
        public String Date_x;
        public Invoice Invoice;
    }

    public class Invoice {
        public String InvoiceID;
        public String InvoiceNumber;
    }

    // Convenience method to parse from JSON string
    public static XeroCreditNoteResponseWrapper parse(String jsonStr) {
        return (XeroCreditNoteResponseWrapper) System.JSON.deserialize(jsonStr.replaceAll('"Date"', '"Date_x"'), XeroCreditNoteResponseWrapper.class);
    }
}