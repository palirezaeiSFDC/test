/*******************************************************************************************
* @Name         LoyaltyStayPublishFailureCallback.cls
* @group        SF-Implementation
* @description  Loyalty Stay–specific failure callback. Extends GenericPublishFailureCallback
*               to rebuild Loyalty_Stay_Event__e platform events on retry.
*******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0              Anand Pandey    02/03/2026        Initial Creation - Extracted from LoyaltyStayEventPublisher
*  2.0              Anand Pandey    05/03/2026        Refactored to extend GenericPublishFailureCallback
*******************************************************************************************/
public with sharing class LoyaltyStayPublishFailureCallback extends GenericPublishFailureCallback {

    private static final String PROCESS_NAME = 'LoyaltyStayPublishFailureCallback';

    public LoyaltyStayPublishFailureCallback(Map<String, Id> uuidMap) {
        super(uuidMap);
    }

    protected override String getProcessName() {
        return PROCESS_NAME;
    }

    protected override GenericPublishFailureCallback.RetryResult rebuildEvents(Set<Id> failedRecordIds) {
        List<Loyalty_Stay__c> stays = LoyaltyStayEventBuilder.queryStays(failedRecordIds);
        if (stays.isEmpty()) {
            return null;
        }

        Map<String, String> brandCodes = LoyaltyStayEventBuilder.queryBrandCodes(stays);
        Map<String, Id> newUuidMap = new Map<String, Id>();
        List<SObject> events = new List<SObject>();

        for (Loyalty_Stay__c stay : stays) {
            Loyalty_Stay_Event__e evt = LoyaltyStayEventBuilder.buildEvent(stay, brandCodes);
            events.add(evt);
            newUuidMap.put(evt.EventUuid, stay.Id);
        }

        return new GenericPublishFailureCallback.RetryResult(events, newUuidMap);
    }
}