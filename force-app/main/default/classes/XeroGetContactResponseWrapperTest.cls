@IsTest
private class XeroGetContactResponseWrapperTest {

    @IsTest
    static void testContactConstructor() {
        XeroGetContactResponseWrapper.Contact newContact = new XeroGetContactResponseWrapper.Contact();
        System.assertEquals(0, newContact.Addresses.size(), 'New contact should have no addresses');
        System.assertEquals(0, newContact.Phones.size(), 'New contact should have no phones');
    }
}