public class OpportunityLineItemHandler {

    public static void preventMixedProductCategories(List<OpportunityLineItem> newLines) {
        if (newLines == null || newLines.isEmpty()) {
            return;
        }

        // Collect Opportunity and PricebookEntry Ids from the incoming records
        Set<Id> oppIds = new Set<Id>();
        Set<Id> newPbeIds = new Set<Id>();

        for (OpportunityLineItem oli : newLines) {
            if (oli.OpportunityId != null) {
                oppIds.add(oli.OpportunityId);
            }
            if (oli.PricebookEntryId != null) {
                newPbeIds.add(oli.PricebookEntryId);
            }
        }

        if (oppIds.isEmpty() || newPbeIds.isEmpty()) {
            return;
        }

        // Existing line items for these Opportunities (already in DB)
        List<OpportunityLineItem> existingLines = [
            SELECT Id,
                   OpportunityId,
                   PricebookEntry.Product2.Product_Category__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
        ];

        // Map: OpportunityId -> set of categories already present
        Map<Id, Set<String>> oppIdToCategories = new Map<Id, Set<String>>();

        // Categories for the NEW lines' PricebookEntries
        Map<Id, String> pbeIdToCategory = new Map<Id, String>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2.Product_Category__c
            FROM PricebookEntry
            WHERE Id IN :newPbeIds
        ]) {
            pbeIdToCategory.put(pbe.Id, pbe.Product2.Product_Category__c);
        }

        // Now enforce: at most ONE category per Opportunity
        for (OpportunityLineItem oli : newLines) {
            if (oli.OpportunityId == null || oli.PricebookEntryId == null) {
                continue;
            }

            String newCat = pbeIdToCategory.get(oli.PricebookEntryId);

            // If no category on product, you can decide to allow or block; here we block
            if (String.isBlank(newCat)) {
                oli.addError('Product has no Product Category, cannot be added to this Opportunity.');
                continue;
            }

            Set<String> cats = oppIdToCategories.get(oli.OpportunityId);
            if (cats == null) {
                cats = new Set<String>();
                oppIdToCategories.put(oli.OpportunityId, cats);
            }

            // Clone the set to simulate final state including this line
            Set<String> resultingCats = cats.clone();
            resultingCats.add(newCat);

            if (resultingCats.size() > 1) {
                oli.addError('You can only add products from a single Product Category at the time');
            } else {
                // Commit this category so subsequent new lines in this same transaction see it
                cats.add(newCat);
            }
        }
    }
}