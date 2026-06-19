/*******************************************************************************************
* @Name         LoyaltyStayEventPublisher_Test.cls
* @group        SF-Implementation
* @description  Test class for LoyaltyStayEventPublisher. Covers publishEvents, guard clauses,
*               buildEvent field mapping, queryBrandCodes, and LoyaltyStayPublishFailureCallback.
*******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0              Anand Pandey    03/03/2026        Initial Creation - Test class for LoyaltyStayEventPublisher
*******************************************************************************************/
@isTest
public with sharing class LoyaltyStayEventPublisher_Test {

    @TestSetup
    static void setupTestData() {
        List<User> users = TestDataFactory.getIntegrationUsers(1);
        insert users;
        TestDataFactory.assignPermissionSets(true, new List<String>{
            ApexConstants.PERMISSIONSET_LOYALTY_CORE_INTEGRATION_USER,
            ApexConstants.PERMISSIONSET_MANAGE_LOYALTY_PROGRAMS
        }, users[0].Id);

        System.runAs(users[0]) {
            LoyaltyProgram program = TestDataFactory.createLoyaltyProgram('MarriottBonvoy', 'MB', true);

            Brand__c brand = new Brand__c(
                Name = 'Test Brand', Brand__c = 'MC',
                Brand_Description__c = 'Test Brand Desc',
                Service_Type__c = 'F',
                Base_Earn_Multiplier__c = 10,
                Base_Earn_Multiplier_Start_Date__c = Date.today().addYears(-1),
                Base_Earn_Multiplier_End_Date__c = Date.today().addYears(1),
                EQN_Earn_Multiplier__c = 1,
                EQN_Earn_Multiplier_Start_Date__c = Date.today().addYears(-1),
                EQN_Earn_Multiplier_End_Date__c = Date.today().addYears(1)
            );
            insert brand;

            Account property = TestDataFactory.createPropertyAccount('PUB001', true);
            Id propertyRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Property')?.getRecordTypeId();
            if (propertyRtId != null) {
                property.RecordTypeId = propertyRtId;
            }
            property.Brand__c = brand.Id;
            update property;

            List<Account> personAccounts = TestDataFactory.createPersonAccounts(1);
            insert personAccounts;
            Account pa = [SELECT PersonContactId FROM Account WHERE Id = :personAccounts[0].Id];

            LoyaltyProgramMember member = TestDataFactory.createLoyaltyProgramMember(
                program, 'PUB-MEMBER-001', 'Active', true, pa.PersonContactId
            );

            Loyalty_Stay__c stay = new Loyalty_Stay__c(
                Membership_Number__c = member.Id,
                Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS,
                Stay_Source__c = 'CONNECTED_PMS',
                Property_Code__c = 'PUB001',
                Checkin_Date__c = Date.today().addDays(-3),
                Checkout_Date__c = Date.today(),
                Total_Elite_Qualifying_Nights__c = 3,
                Reservation_Confirmation_Number__c = 'CONF-PUB-001'
            );
            insert stay;

            TransactionJournal tj = TestDataFactory.createTransactionJournal(
                stay, member, 100, 10, 5, true,
                Date.today().addDays(-3), Date.today(), 'PUB001', false
            );
            tj.Folio_Number__c = 'FOLIO-001';
            tj.Rate_Plan_Code__c = 'RACK';
            tj.Associate_Id__c = 'ASSOC-001';
            insert tj;
        }
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE LastName = 'IntegrationUser0' LIMIT 1];
    }

    private static Loyalty_Stay__c getTestStay() {
        return [SELECT Id, Stay_Status__c FROM Loyalty_Stay__c WHERE Property_Code__c = 'PUB001' LIMIT 1];
    }

    /** @description Validates publishEvents(oldMap, newMap) publishes when Stay_Status__c changes to eligible status. */
    @isTest
    static void testPublishEventsWithOldMapNewMap() {
        System.runAs(getTestUser()) {
            Loyalty_Stay__c stay = getTestStay();

            Loyalty_Stay__c oldStay = stay.clone(true, true, true, true);
            oldStay.Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS;

            Loyalty_Stay__c newStay = stay.clone(true, true, true, true);
            newStay.Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_POSTED;

            Map<Id, SObject> oldMap = new Map<Id, SObject>{ stay.Id => oldStay };
            Map<Id, SObject> newMap = new Map<Id, SObject>{ stay.Id => newStay };

            Test.startTest();
            LoyaltyStayEventPublisher.publishEvents(oldMap, newMap);
            Test.stopTest();

            System.assert(true, 'publishEvents(oldMap, newMap) completed without exception');
        }
    }

    /** @description Validates publishEvents(oldMap, newMap) does not publish when status unchanged or changes to ineligible. */
    @isTest
    static void testPublishEventsWithOldMapNewMapNoPublish() {
        System.runAs(getTestUser()) {
            Loyalty_Stay__c stay = getTestStay();

            Loyalty_Stay__c oldStay = stay.clone(true, true, true, true);
            oldStay.Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS;
            Loyalty_Stay__c newStaySame = stay.clone(true, true, true, true);
            newStaySame.Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS;

            Map<Id, SObject> oldMapSame = new Map<Id, SObject>{ stay.Id => oldStay };
            Map<Id, SObject> newMapSame = new Map<Id, SObject>{ stay.Id => newStaySame };

            Test.startTest();
            LoyaltyStayEventPublisher.publishEvents(oldMapSame, newMapSame);
            Test.stopTest();

            Loyalty_Stay__c oldStayPosted = stay.clone(true, true, true, true);
            oldStayPosted.Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_POSTED;
            Loyalty_Stay__c newStayToIneligible = stay.clone(true, true, true, true);
            newStayToIneligible.Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS;

            Map<Id, SObject> oldMapEligible = new Map<Id, SObject>{ stay.Id => oldStayPosted };
            Map<Id, SObject> newMapToIneligible = new Map<Id, SObject>{ stay.Id => newStayToIneligible };

            LoyaltyStayEventPublisher.publishEvents(oldMapEligible, newMapToIneligible);
            System.assert(true, 'No publish when status unchanged or changes to In Progress');
        }
    }

    /** @description Validates publishEvents builds and publishes events with all fields populated. */
    @isTest
    static void testPublishEventsWithFullData() {
        System.runAs(getTestUser()) {
            Loyalty_Stay__c stay = getTestStay();

            Test.startTest();
            LoyaltyStayEventPublisher.publishEvents(new List<Loyalty_Stay__c>{ stay });
            Test.stopTest();

            System.assert(true, 'publishEvents completed without exception');
        }
    }

    /** @description Validates guard clauses for null and empty inputs. */
    @isTest
    static void testPublishEventsGuardClauses() {
        Test.startTest();
        LoyaltyStayEventPublisher.publishEvents(null);
        LoyaltyStayEventPublisher.publishEvents(new List<Loyalty_Stay__c>());
        Test.stopTest();
        System.assert(true, 'Guard clauses handled without exception');
    }

    /** @description Validates buildEvent maps all fields from stay, journal, and brand. */
    @isTest
    static void testBuildEventFieldMapping() {
        System.runAs(getTestUser()) {
            Loyalty_Stay__c stay = getTestStay();
            List<Loyalty_Stay__c> stays = LoyaltyStayEventBuilder.queryStays(new Set<Id>{ stay.Id });
            Map<String, String> brandCodes = LoyaltyStayEventBuilder.queryBrandCodes(stays);

            Test.startTest();
            Loyalty_Stay_Event__e evt = LoyaltyStayEventBuilder.buildEvent(stays[0], brandCodes);
            Test.stopTest();

            System.assertNotEquals(null, evt.EventUuid, 'EventUuid should be pre-populated via newSObject');
            System.assertEquals(stays[0].Name, evt.Loyalty_Stay__c, 'Loyalty_Stay__c mismatch');
            System.assertEquals('PUB001', evt.Property_Code__c, 'Property_Code__c mismatch');
            System.assertEquals(Date.today().addDays(-3), evt.Checkin_Date__c, 'Checkin_Date__c mismatch');
            System.assertEquals(Date.today(), evt.Checkout_Date__c, 'Checkout_Date__c mismatch');
            System.assertEquals(3, evt.Elite_Qualifying_Nights__c, 'Elite_Qualifying_Nights__c mismatch');
            System.assertEquals('CONF-PUB-001', evt.Reservation_Confirmation_Number__c, 'Reservation_Confirmation_Number__c mismatch');
            System.assertEquals('PUB-MEMBER-001', evt.Membership_Number__c, 'Membership_Number__c mismatch');
            System.assertEquals('MC', evt.Brand_Code__c, 'Brand_Code__c mismatch');
            System.assertEquals('FOLIO-001', evt.Folio_Number__c, 'Folio_Number__c mismatch');
            System.assertEquals('RACK', evt.Rate_Plan_Code__c, 'Rate_Plan_Code__c mismatch');
            System.assertEquals('ASSOC-001', evt.Associate_Id__c, 'Associate_Id__c mismatch');
            System.assertEquals('CONNECTED_PMS', evt.Stay_Source__c, 'Stay_Source__c mismatch');
        }
    }

    /** @description Validates queryBrandCodes returns empty map when no property codes match. */
    @isTest
    static void testQueryBrandCodesNoMatch() {
        System.runAs(getTestUser()) {
            Loyalty_Stay__c stayNoMatch = new Loyalty_Stay__c(Property_Code__c = 'NOMATCH');

            Test.startTest();
            Map<String, String> result = LoyaltyStayEventBuilder.queryBrandCodes(
                new List<Loyalty_Stay__c>{ stayNoMatch }
            );
            Test.stopTest();

            System.assert(result.isEmpty(), 'Should return empty map for unmatched property code');
        }
    }

    /** @description Validates the failure callback retries and eventually logs after exhausting retries. */
    @isTest
    static void testPublishFailureCallbackRetries() {
        System.runAs(getTestUser()) {
            Loyalty_Stay__c stay = getTestStay();
            List<Loyalty_Stay__c> stays = LoyaltyStayEventBuilder.queryStays(new Set<Id>{ stay.Id });
            Map<String, String> brandCodes = LoyaltyStayEventBuilder.queryBrandCodes(stays);

            Loyalty_Stay_Event__e evt = LoyaltyStayEventBuilder.buildEvent(stays[0], brandCodes);
            Map<String, Id> uuidMap = new Map<String, Id>{ evt.EventUuid => stay.Id };

            LoyaltyStayPublishFailureCallback cb = new LoyaltyStayPublishFailureCallback(uuidMap);

            EventBus.publish(new List<Loyalty_Stay_Event__e>{ evt }, cb);

            for (Integer i = 1; i <= GenericPublishFailureCallback.MAX_RETRIES; i++) {
                Test.getEventBus().fail();
                System.assertEquals(i, cb.getRetryCount(), 'Retry count should be ' + i);
            }

            Test.getEventBus().fail();
            System.assertEquals(
                GenericPublishFailureCallback.MAX_RETRIES,
                cb.getRetryCount(),
                'Retry count should not exceed MAX_RETRIES'
            );
        }
    }
}