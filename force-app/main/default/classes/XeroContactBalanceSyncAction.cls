/**
 * @author Cosimo
 * @description Flow-invocable action to fetch Xero contact balances and currencies for a list of Account Xero_Id__c values.
 *              Batches the input into chunks of 10 and enqueues queueables to process each batch.
 */
public with sharing class XeroContactBalanceSyncAction {

    /**
     * @description Optional Flow input to override lastModified and control upsert behavior.
     */
    public class Request {
        @InvocableVariable(label='Account Xero IDs' description='List of Account Xero_Id__c values to fetch balances for.')
        public List<String> accountXeroIds;
    }

    /**
     * @description Flow output with counts and messages.
     */
    public class Result {
        @InvocableVariable public List<String> messages;
    }

    /**
     * @description Fetch and update Account currency/balances from Xero contacts.
     * @param requests Flow requests; only the first request is used. If none provided, defaults are applied.
     * @return List<Result> containing success/error counts and messages for Flow display.
     */
    @InvocableMethod(label='Sync Xero Contact Balances' description='Fetch and update Account currency and balances from Xero contacts.')
    public static List<Result> run(List<Request> requests) {
        Request req = (requests == null || requests.isEmpty()) ? new Request() : requests[0];

        Result res = new Result();
        res.messages = new List<String>();

        if (req.accountXeroIds == null || req.accountXeroIds.isEmpty()) {
            res.messages.add('No Xero IDs provided.');
            return new List<Result>{ res };
        }

        // Filter out blank/null IDs
        List<String> validIds = new List<String>();
        for (String id : req.accountXeroIds) {
            if (String.isNotBlank(id)) {
                validIds.add(id);
            }
        }

        if (validIds.isEmpty()) {
            res.messages.add('No valid Xero IDs provided.');
            return new List<Result>{ res };
        }

        // Batch into chunks of 10
        Integer batchSize = 10;
        Integer totalBatches = (validIds.size() + batchSize - 1) / batchSize;
        Integer totalIds = validIds.size();

        for (Integer i = 0; i < totalIds; i += batchSize) {
            List<String> batch = new List<String>();
            Integer endIndex = Math.min(i + batchSize, totalIds);
            for (Integer j = i; j < endIndex; j++) {
                batch.add(validIds[j]);
            }
            System.debug('Enqueuing XeroContactBalanceSyncQueue for batch: ' + batch);
            System.enqueueJob(new XeroContactBalanceSyncQueue(batch));
        }

        res.messages.add('Enqueued ' + totalBatches + ' batch(es) for ' + totalIds + ' Xero IDs.');
        return new List<Result>{ res };
    }
}