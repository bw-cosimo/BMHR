trigger OpportunityProductTrigger on OpportunityLineItem (before insert) {
 OpportunityLineItemHandler.preventMixedProductCategories(Trigger.new);
}