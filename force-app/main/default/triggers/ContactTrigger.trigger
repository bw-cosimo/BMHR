/**
 * @description Trigger for Contact object to handle  after update and after insert events
 * @author Mladen Georgiev
 * @since 18-Nov-2025
 * @version 1.0
 */
trigger ContactTrigger on Contact (after insert, after update) {
    ContactTriggerHandler.handleTrigger(
        Trigger.new,
        Trigger.operationType
    );
}