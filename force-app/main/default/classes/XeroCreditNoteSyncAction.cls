/**
 * @author Cosimo
 * @description Flow-invocable action to fetch Xero credit notes modified since previous midnight (UTC) and insert/upsert Credit_Note__c records.
 */
public with sharing class XeroCreditNoteSyncAction {

    /**
     * @description Optional Flow input to override lastModified and control upsert behavior.
     */
    public class Request {
        @InvocableVariable(label='Override Last Modified (UTC)' description='Optional UTC timestamp yyyy-MM-ddThh:mm:ss. If blank, uses previous midnight UTC.')
        public String overrideLastModifiedUtc;
    }

    /**
     * @description Flow output with counts and messages.
     */
    public class Result {
        @InvocableVariable public List<String> messages;
        @InvocableVariable public String lastModifiedUsed;
    }

    /**
     * @description Fetch and insert Xero credit notes created/modified since previous midnight UTC.
     * @param requests Flow requests; only the first request is used. If none provided, defaults are applied.
     * @return List<Result> containing success/error counts and messages for Flow display.
     */
    @InvocableMethod(label='Sync Xero Credit Notes Since Previous Midnight' description='Fetch and insert Xero credit notes modified since previous midnight (UTC) using Xero API.')
    public static List<Result> run(List<Request> requests) {
        Request req = (requests == null || requests.isEmpty()) ? new Request() : requests[0];

        Result res = new Result();
        res.messages = new List<String>();

        String lastModified = String.isNotBlank(req.overrideLastModifiedUtc)
            ? req.overrideLastModifiedUtc
            : previousMidnightGmt();
        res.lastModifiedUsed = lastModified;

        // Enqueue async processing to isolate callouts from any prior Flow DML
        System.enqueueJob(new XeroCreditNoteSyncQueue(lastModified));

        res.messages.add('Xero credit note sync enqueued for processing.');
        return new List<Result>{ res };
    }

    /**
     * @description Compute previous midnight in UTC formatted as yyyy-MM-ddThh:mm:ss (for If-Modified-Since).
     * @return String UTC timestamp for previous midnight.
     */
    private static String previousMidnightGmt() {
        Date prior = Date.today().addDays(-1);
        return Datetime.newInstance(prior, Time.newInstance(0, 0, 0, 0))
            .formatGmt('yyyy-MM-dd\'T\'HH:mm:ss');
    }
}