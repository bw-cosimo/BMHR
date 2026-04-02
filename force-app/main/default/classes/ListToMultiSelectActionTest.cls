@IsTest
public class ListToMultiSelectActionTest {

    @IsTest
    static void testConvertListToString() {
        // 1. Prepare data
        List<ListToMultiSelectAction.Request> requests = new List<ListToMultiSelectAction.Request>();

        // Scenario A: Standard list with multiple values
        ListToMultiSelectAction.Request req1 = new ListToMultiSelectAction.Request();
        req1.values = new List<String>{'Apples', 'Oranges', 'Bananas'};
        
        // Scenario B: Empty list
        ListToMultiSelectAction.Request req2 = new ListToMultiSelectAction.Request();
        req2.values = new List<String>();

        // Scenario C: Null list
        ListToMultiSelectAction.Request req3 = new ListToMultiSelectAction.Request();
        req3.values = null;

        requests.add(req1);
        requests.add(req2);
        requests.add(req3);
        
        Test.startTest();
        List<ListToMultiSelectAction.Response> responses = ListToMultiSelectAction.convert(requests);
        Test.stopTest();

        Assert.areEqual(3, responses.size(), 'Should return one response per request.');
        
        Assert.areEqual('Apples;Oranges;Bananas', responses[0].multiSelectString, 'The list should be joined by semi-colons.');
        
        Assert.isNull(responses[1].multiSelectString, 'An empty list should return a null string.');
        Assert.isNull(responses[2].multiSelectString, 'A null list should return a null string.');
    }
}