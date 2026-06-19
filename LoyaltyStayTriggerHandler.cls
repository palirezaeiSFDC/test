/*******************************************************************************************
 * @Name         LoyaltyStayTriggerHandler.cls
 * @Author       
 * @group        SF-Implementation
 * @description  Trigger Framework Handler for Loyalty Stay object (after insert, after update)
 *******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0             Anand Pandey    02/03/2026        Initial Creation - Trigger Framework for Loyalty Stay
*******************************************************************************************/
@SuppressWarnings('PMD.EmptyStatementBlock')
public class LoyaltyStayTriggerHandler implements ITriggerHandler {
    public void beforeInsert(List<SObject> newList) {
        // No logic required for before insert as of now and it's part of the trigger framework
    }

    public void beforeUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        // No logic required for before update as of now and it's part of the trigger framework
    }

    public void beforeDelete(Map<Id, SObject> oldMap) {
        // No logic required for before delete as of now and it's part of the trigger framework
    }

    public void afterInsert(List<SObject> newList) {
        //LoyaltyStayEventPublisher.publishEvents(newList);
    }

    public void afterUpdate(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        LoyaltyStayEventPublisher.publishEvents(oldMap, newMap);
    }

    public void afterDelete(Map<Id, SObject> oldMap) {
        // No logic required for after delete as of now and it's part of the trigger framework
    }
}