@IsTest
private class MultiSelectToListActionTest {

    @IsTest
    static void testMultipleValues() {
        // Arrange
        MultiSelectToListAction.Request req = new MultiSelectToListAction.Request();
        req.multiSelectValues = 'A;B;C';

        List<MultiSelectToListAction.Request> requests = new List<MultiSelectToListAction.Request>{ req };

        // Act
        List<MultiSelectToListAction.Response> results = MultiSelectToListAction.convert(requests);

        // Assert
        System.assertEquals(1, results.size(), 'Should return one response');
        System.assertNotEquals(null, results[0].values, 'Values list should not be null');
        System.assertEquals(3, results[0].values.size(), 'Should have 3 items');
        System.assertEquals('A', results[0].values[0]);
        System.assertEquals('B', results[0].values[1]);
        System.assertEquals('C', results[0].values[2]);
    }

    @IsTest
    static void testSingleValue() {
        // Arrange
        MultiSelectToListAction.Request req = new MultiSelectToListAction.Request();
        req.multiSelectValues = 'OnlyOne';

        List<MultiSelectToListAction.Request> requests = new List<MultiSelectToListAction.Request>{ req };

        // Act
        List<MultiSelectToListAction.Response> results = MultiSelectToListAction.convert(requests);

        // Assert
        System.assertEquals(1, results.size(), 'Should return one response');
        System.assertEquals(1, results[0].values.size(), 'Should have 1 item');
        System.assertEquals('OnlyOne', results[0].values[0]);
    }

    @IsTest
    static void testBlankValue() {
        // Arrange
        MultiSelectToListAction.Request req = new MultiSelectToListAction.Request();
        req.multiSelectValues = '';

        List<MultiSelectToListAction.Request> requests = new List<MultiSelectToListAction.Request>{ req };

        // Act
        List<MultiSelectToListAction.Response> results = MultiSelectToListAction.convert(requests);

        // Assert
        System.assertEquals(1, results.size(), 'Should return one response');
        System.assertNotEquals(null, results[0].values, 'Values list should not be null even if input is blank');
        System.assertEquals(0, results[0].values.size(), 'Blank input should result in an empty list');
    }

    @IsTest
    static void testNullValue() {
        // Arrange
        MultiSelectToListAction.Request req = new MultiSelectToListAction.Request();
        req.multiSelectValues = null;

        List<MultiSelectToListAction.Request> requests = new List<MultiSelectToListAction.Request>{ req };

        // Act
        List<MultiSelectToListAction.Response> results = MultiSelectToListAction.convert(requests);

        // Assert
        System.assertEquals(1, results.size(), 'Should return one response');
        System.assertNotEquals(null, results[0].values, 'Values list should not be null even if input is null');
        System.assertEquals(0, results[0].values.size(), 'Null input should result in an empty list');
    }

    @IsTest
    static void testMultipleRequests() {
        // Arrange
        MultiSelectToListAction.Request req1 = new MultiSelectToListAction.Request();
        req1.multiSelectValues = 'A;B';

        MultiSelectToListAction.Request req2 = new MultiSelectToListAction.Request();
        req2.multiSelectValues = 'X;Y;Z';

        List<MultiSelectToListAction.Request> requests = new List<MultiSelectToListAction.Request>{ req1, req2 };

        // Act
        List<MultiSelectToListAction.Response> results = MultiSelectToListAction.convert(requests);

        // Assert
        System.assertEquals(2, results.size(), 'Should return two responses');

        // First request assertions
        System.assertEquals(2, results[0].values.size(), 'First response should have 2 items');
        System.assertEquals('A', results[0].values[0]);
        System.assertEquals('B', results[0].values[1]);

        // Second request assertions
        System.assertEquals(3, results[1].values.size(), 'Second response should have 3 items');
        System.assertEquals('X', results[1].values[0]);
        System.assertEquals('Y', results[1].values[1]);
        System.assertEquals('Z', results[1].values[2]);
    }
}