@IsTest
private class ErrorUtilityTest {
    @IsTest
    static void build_minimal_sets_fields_without_insert() {
        Error_Log__c log = ErrorUtility.build('Message', 'Apex', 'Stack');
        System.assertNotEquals(null, log, 'Should return a record');
        System.assertEquals('Message', log.Error_Message__c);
        System.assertEquals('Apex', log.Type__c);
        System.assertEquals('Stack', log.Stack_Trace__c);
        // Not inserted yet
        System.assertEquals(null, log.Id);
    }

    @IsTest
    static void build_with_related_only_when_present() {
        // Build using the overload that includes relatedRecordId; Context__c is not used in org
        Error_Log__c log = ErrorUtility.build('Msg', 'Apex', 'Trace', null, UserInfo.getUserId());
        System.assertEquals('Msg', log.Error_Message__c);
        System.assertEquals('Apex', log.Type__c);
        System.assertEquals('Trace', log.Stack_Trace__c);

        // Verify Related_Record_Id__c only if the field exists
        Map<String, Schema.SObjectField> fmap = Schema.SObjectType.Error_Log__c.fields.getMap();
        if (fmap.containsKey('Related_Record_Id__c')) {
            System.assertEquals(String.valueOf(UserInfo.getUserId()), (String)log.get('Related_Record_Id__c'));
        }
    }

    @IsTest
    static void insertLogs_handles_empty_and_null() {
        List<Database.SaveResult> resultsNull = ErrorUtility.insertLogs(null, false);
        System.assertEquals(0, resultsNull.size(), 'Null list should return empty results');

        List<Database.SaveResult> resultsEmpty = ErrorUtility.insertLogs(new List<Error_Log__c>(), false);
        System.assertEquals(0, resultsEmpty.size(), 'Empty list should return empty results');
    }

    @IsTest
    static void insertLogs_inserts_records_partial_success() {
        // Create one valid and one potentially invalid record to validate partial success behavior
        Error_Log__c validLog = ErrorUtility.build('Valid message', 'Apex', null);
        Error_Log__c invalidLog = new Error_Log__c(); // may fail depending on org validation

        List<Database.SaveResult> results = ErrorUtility.insertLogs(new List<Error_Log__c>{ validLog, invalidLog }, false);
        System.assertEquals(2, results.size(), 'Should return a result per record');

        // At least one should succeed
        Boolean anySuccess = false;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                anySuccess = true;
                System.assertNotEquals(null, r.getId(), 'Successful save should have an Id');
            }
        }
        System.assertEquals(true, anySuccess, 'At least one record should insert in partial mode');
    }

    @IsTest
    static void insertLog_single_convenience() {
        Error_Log__c log = ErrorUtility.build('Single', 'Apex', null);
        Database.SaveResult res = ErrorUtility.insertLog(log, false);
        System.assertNotEquals(null, res, 'Should return a result');
        System.assertEquals(true, res.isSuccess(), 'Single insert should succeed for a valid record');
    }
}