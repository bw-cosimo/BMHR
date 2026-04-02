/**
 * @author Cosimo
 * @description Utility for building and inserting Error_Log__c records in a consistent, bulk-safe manner.
 */
public with sharing class ErrorUtility {

    // Optional centralization of max lengths (adjust to your org if you want automatic truncation)
    // private static final Integer MAX_ERROR_MESSAGE_LEN = 255;
    // private static final Integer MAX_TYPE_LEN = 100;

    /**
     * @description Build a minimal Error_Log__c with message, type and stack trace.
     * @param message Error message to record (required for meaningful logs).
     * @param type Logical category (e.g., 'Apex', 'Integration', 'Validation').
     * @param stackTrace Optional stack trace (may be null).
     * @return Error_Log__c instance (not inserted).
     */
    public static Error_Log__c build(String message, String type, String stackTrace) {
        Error_Log__c log = new Error_Log__c();
        if (message != null) log.Error_Message__c = message;
        if (type != null) log.Type__c = type;
        if (stackTrace != null) log.Stack_Trace__c = stackTrace;
        return log;
    }

    /**
     * @description Build an Error_Log__c with additional optional context and related record id.
     * @param message Error message to record.
     * @param type Logical category (e.g., 'Apex', 'Integration', 'Validation').
     * @param stackTrace Optional stack trace.
     * @param context Optional free-form context (e.g., class/method or business context).
     * @param relatedRecordId Optional related record Id (as Id or String if your field is Text).
     * @return Error_Log__c instance (not inserted).
     */
    public static Error_Log__c build(String message, String type, String stackTrace, String context, Id relatedRecordId) {
        Error_Log__c log = build(message, type, stackTrace);
        if (Schema.sObjectType.Error_Log__c.fields.getMap().containsKey('Related_Record_Id__c') && relatedRecordId != null) {
            log.put('Related_Record_Id__c', String.valueOf(relatedRecordId));
        }
        return log;
    }

    /**
     * @description Insert a list of Error_Log__c with control over allOrNone. Returns per-row SaveResults.
     * @param logs List of Error_Log__c to insert. If null/empty, returns an empty List.
     * @param allOrNone When false, performs partial success insert.
     * @return List<Database.SaveResult> results corresponding to the provided list.
     */
    public static List<Database.SaveResult> insertLogs(List<Error_Log__c> logs, Boolean allOrNone) {
        if (logs == null || logs.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        // DML is performed by caller context; surface partial errors to caller
        return Database.insert(logs, allOrNone == null ? false : allOrNone);
    }

    /**
     * @description Convenience method to insert a single Error_Log__c.
     * @param log Error_Log__c record to insert (may be null; if null returns null).
     * @param allOrNone Whether to enforce all-or-none (defaults false when null).
     * @return Database.SaveResult or null if input is null.
     */
    public static Database.SaveResult insertLog(Error_Log__c log, Boolean allOrNone) {
        if (log == null) return null;
        List<Database.SaveResult> results = insertLogs(new List<Error_Log__c>{ log }, allOrNone);
        return (results.isEmpty() ? null : results[0]);
    }

    // Optional helper if you want to ensure values fit within field limits.
    // private static String truncate(String value, Integer maxLen) {
    //     if (value == null || maxLen == null) return value;
    //     return value.length() <= maxLen ? value : value.substring(0, maxLen);
    // }
}