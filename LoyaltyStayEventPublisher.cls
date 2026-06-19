/*******************************************************************************************
* @Name         LoyaltyStayEventPublisher.cls
* @group        SF-Implementation
* @description  Publishes Loyalty_Stay_Event__e platform events enriched with stay, transaction
*               journal, brand, and membership data. Publishes only when Stay_Status__c changes
*               to Posted - Eligible, Posted - Ineligible, Suspended, Exception Handling, or Cancelled.
*               Does NOT publish when status is In Progress or Blank. Includes an
*               LoyaltyStayPublishFailureCallback that retries failed publishes up to MAX_RETRIES times.
*******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0              Anand Pandey    02/03/2026        Initial Creation - Loyalty Stay Event Publisher
*******************************************************************************************/
public with sharing class LoyaltyStayEventPublisher {

    /** Statuses that trigger Stay Platform Event publication when Stay_Status__c changes */
    private static final Set<String> ELIGIBLE_EVENT_STATUSES = new Set<String>{
        StayAndEarnApexConstants.STAY_STATUS_POSTED,
        StayAndEarnApexConstants.STAY_STATUS_POSTED_INELIGIBLE,
        StayAndEarnApexConstants.STAY_STATUS_SUSPENDED,
        StayAndEarnApexConstants.STAY_STATUS_EXCEPTION,
        StayAndEarnApexConstants.STAY_STATUS_CANCELLED
    };

    /**
     * @description Publishes Stay Platform Events when Stay_Status__c changes to an eligible status.
     *              Only publishes for: Posted - Eligible, Posted - Ineligible, Suspended, Exception Handling, Cancelled.
     *              Does NOT publish for: In Progress, Blank.
     * @param oldMap Map of old Loyalty_Stay__c records from trigger context
     * @param newMap Map of new Loyalty_Stay__c records from trigger context
     */
    public static void publishEvents(Map<Id, SObject> oldMap, Map<Id, SObject> newMap) {
        if (TriggerControlUtil.bypassTrigger()) {
            return;
        }
        List<Loyalty_Stay__c> staysToPublish = new List<Loyalty_Stay__c>();
        for (Id stayId : newMap.keySet()) {
            if (((Loyalty_Stay__c) newMap.get(stayId)).Stay_Status__c != ((Loyalty_Stay__c) oldMap.get(stayId)).Stay_Status__c
                && String.isNotBlank(((Loyalty_Stay__c) newMap.get(stayId)).Stay_Status__c)
                && ELIGIBLE_EVENT_STATUSES.contains(((Loyalty_Stay__c) newMap.get(stayId)).Stay_Status__c)) {
                staysToPublish.add((Loyalty_Stay__c) newMap.get(stayId));
            }
        }
        publishEvents(staysToPublish);
    }

    /**
     * @description Publishes enriched Loyalty Stay platform events with a failure callback.
     * @param triggerStays Loyalty_Stay__c records from trigger context
     */
    public static void publishEvents(List<Loyalty_Stay__c> triggerStays) {
        if (TriggerControlUtil.bypassTrigger() || triggerStays == null || triggerStays.isEmpty()) {
            return;
        }

        Set<Id> stayIds = new Set<Id>();
        for (Loyalty_Stay__c stay : triggerStays) {
            if (stay?.Id != null && String.isNotBlank(stay.Stay_Status__c) && ELIGIBLE_EVENT_STATUSES.contains(stay.Stay_Status__c)) {
                stayIds.add(stay.Id);
            }
        }
        if (stayIds.isEmpty()) {
            return;
        }

        List<Loyalty_Stay__c> stays = LoyaltyStayEventBuilder.queryStays(stayIds);
        if (stays.isEmpty()) {
            return;
        }

        Map<String, String> brandCodes = LoyaltyStayEventBuilder.queryBrandCodes(stays);
        List<Loyalty_Stay_Event__e> events = new List<Loyalty_Stay_Event__e>();
        Map<String, Id> uuidMap = new Map<String, Id>();

        for (Loyalty_Stay__c stay : stays) {
            Loyalty_Stay_Event__e evt = LoyaltyStayEventBuilder.buildEvent(stay, brandCodes);
            events.add(evt);
            uuidMap.put(evt.EventUuid, stay.Id);
        }

        if (!events.isEmpty()) {

            System.OrgLimit callbackLimit = System.OrgLimits.getMap().get(ApexConstants.ORG_LIMIT_PUBLISH_CALLBACK);
            
            if (callbackLimit != null && callbackLimit.getValue() < (callbackLimit.getLimit() * ApexConstants.CALLBACK_USAGE_THRESHOLD)) {
                EventBus.publish(events, new LoyaltyStayPublishFailureCallback(uuidMap));
            } else {
                EventBus.publish(events);
            }
        }
    }
}