/**
 * @description Trigger for Account object to handle  after update and after insert events
 * @author Mladen Georgiev
 * @since 17-Nov-2025
 * @version 1.0
 */
trigger AccountTrigger on Account (after insert, after update) {
    AccountTriggerHandler.handleTrigger(
        Trigger.new,
        Trigger.operationType
    );
}