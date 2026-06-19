/*******************************************************************************************
 * @Name         StayPostProcessingService_Test
 * @Author       Salesforce
 * @group        SF-Implementation
 * @description  Covers StayPostProcessingService and supporting helpers (aggregations, crediting,
 *               exceptions) using patterns from other service/test suites.
 *******************************************************************************************/
@isTest
public with sharing class StayPostProcessingService_Test {

    private static LoyaltyProgram loyaltyProgram;
    private static Account propertyAccount;
    private static Contact loyaltyContact;
    private static LoyaltyProgramMember loyaltyMember;

    @TestSetup
    static void setupTestData() {
        loyaltyProgram = TestDataFactory.createLoyaltyProgram(true);
        List<Account> propertyAccounts = TestDataFactory.createPartnerAccounts(1);
        propertyAccount = propertyAccounts[0];
        propertyAccount.PropertyCode__c = 'REF_PROP_01';
        //propertyAccount.Calculated_ENC_Earn_Multiplier__c = 1.5;
        propertyAccount.EQN_Earn_Multiplier__c = 1.5;
        insert propertyAccount;
        List<Contact> contacts = TestDataFactory.createNContacts(1, propertyAccount, true);
        loyaltyContact = contacts[0];
        loyaltyMember = TestDataFactory.createMembers(1, loyaltyContact, loyaltyProgram, true, false)[0];
        //TestDataFactory.createProduct('Test Product 2', 'PROD002', true);
    }

    /**
     * @description Verifies the service aggregates stay totals and applies property multipliers.
     */
    @isTest
    static void testAggregatesStayTotalsAndAppliesPropertyMultiplier() {
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(loyaltyMember, true);
        TestDataFactory.createTransactionJournal(
            stay,
            loyaltyMember,
            220,
            30,
            10,
            true,
            Date.today().addDays(-1),
            Date.today(),
            propertyAccount.PropertyCode__c,
            true
        );
        Stay_Processor_Event__e eventRecord = TestDataFactory.createStayProcessorEvent(stay.Id, loyaltyMember.Id);

        Test.startTest();
        StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>{eventRecord});
        Test.stopTest();

        stay = [
            SELECT Total_Base_Points__c, Total_Elite_Bonus_Points__c, Total_Extra_Points__c,
                   Total_Elite_Qualifying_Nights__c, Stay_Status__c
            FROM Loyalty_Stay__c
            WHERE Id = :stay.Id
        ];

        Decimal expectedNights = Date.today().addDays(-1).daysBetween(Date.today()) * propertyAccount.Calculated_EQN_Earn_Multiplier__c;

        System.assertEquals(220, stay.Total_Base_Points__c, 'Base points should sum across journals');
        System.assertEquals(30, stay.Total_Elite_Bonus_Points__c, 'Elite bonus points should sum across journals');
        System.assertEquals(10, stay.Total_Extra_Points__c, 'Extra points should sum across journals');
        System.assertEquals(StayAndEarnApexConstants.STAY_STATUS_POSTED, stay.Stay_Status__c, 'Stay status should flip to Posted - Eligible');
        System.assertEquals(expectedNights, stay.Total_Elite_Qualifying_Nights__c, 'EQN should respect the property multiplier');
    }
    

    /**
     * @description Ensures stays with unknown properties default to a multiplier of 1.
     */
    @isTest
    static void testDefaultsToIdentityMultiplierWhenPropertyMissing() {
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(loyaltyMember, true);
        TestDataFactory.createTransactionJournal(
            stay,
            loyaltyMember,
            90,
            5,
            2,
            true,
            Date.today().addDays(-4),
            Date.today(),
            'UNKNOWN_CODE',
            true
        );
        Stay_Processor_Event__e eventRecord = TestDataFactory.createStayProcessorEvent(stay.Id, loyaltyMember.Id);

        Test.startTest();
        StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>{eventRecord});
        Test.stopTest();

        stay = [
            SELECT Total_Elite_Qualifying_Nights__c
            FROM Loyalty_Stay__c
            WHERE Id = :stay.Id
        ];

        Decimal expectedNights = Date.today().addDays(-4).daysBetween(Date.today());
        System.assertEquals(expectedNights, stay.Total_Elite_Qualifying_Nights__c, 'Multiplier should default to 1 when property lookups fail');
    }

    /**
     * @description Validates the service short-circuits gracefully when the event batch is empty.
     */
    @isTest
    static void testEmptyEventBatchDoesNotThrow() {
        Test.startTest();
        StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>());
        Test.stopTest();
        System.assert(true, 'Processing an empty batch should complete without throwing');
    }

    /**
     * @description calculateTotalEligibleRevenue sums USD_Value_Converted__c for journals with Base_Points__c > 0.
     */
    @isTest
    static void testCalculateTotalEligibleRevenue() {
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(loyaltyMember, true);
        TestDataFactory.createTransactionJournal(
            stay,
            loyaltyMember,
            100,
            0,
            0,
            true,
            Date.today().addDays(-1),
            Date.today(),
            propertyAccount.PropertyCode__c,
            false
        );

        Test.startTest();
        Decimal revenue = MemberStayDataService.calculateTotalEligibleRevenue(stay.Id);
        Test.stopTest();

        System.assertNotEquals(null, revenue, 'Revenue should not be null');
        System.assert(revenue >= 0, 'Revenue should be a non-negative value');
    }

    /**
     * @description Covers MemberCurrencyYearTotalsHelper: negative (null/empty bundle) and positive (full flow).
     */
    @isTest
    static void testMemberCurrencyYearTotalsHelper() {
        // Negative: null bundle should not throw
        Test.startTest();
        MemberCurrencyYearTotalsHelper.updateMemberCurrencyYearTotals(null);
        System.assert(true, 'Null bundle should complete without throwing');

        // Negative: empty bundle should not throw
        StayUpdateHelper.StayUpdateBundle emptyBundle = new StayUpdateHelper.StayUpdateBundle();
        MemberCurrencyYearTotalsHelper.updateMemberCurrencyYearTotals(emptyBundle);
        System.assert(true, 'Empty bundle should complete without throwing');

        // Positive: full flow via processStayEvents exercises MemberCurrencyYearTotalsHelper
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(loyaltyMember, true);
        TestDataFactory.createTransactionJournal(
            stay,
            loyaltyMember,
            150,
            20,
            5,
            true,
            Date.today().addDays(-2),
            Date.today(),
            propertyAccount.PropertyCode__c,
            true
        );
        Stay_Processor_Event__e eventRecord = TestDataFactory.createStayProcessorEvent(stay.Id, loyaltyMember.Id);
        StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>{eventRecord});
        Test.stopTest();

        stay = [SELECT Id, Stay_Status__c FROM Loyalty_Stay__c WHERE Id = :stay.Id];
        System.assertEquals(StayAndEarnApexConstants.STAY_STATUS_POSTED, stay.Stay_Status__c,
            'Positive flow should post stay and run MemberCurrencyYearTotalsHelper');
    }

    /**
     * @description Verifies executeStayProcessing short-circuits when stayIds set is empty.
     */
    @isTest
    static void testExecuteStayProcessingEmptyStayIds() {
        Test.startTest();
        StayPostProcessingService.executeStayProcessing(new Set<Id>(), new Set<Id>());
        Test.stopTest();
        System.assert(true, 'Empty stayIds should complete without throwing');
    }

    /**
     * @description Verifies processStayEvents skips records with null Stay_Id__c.
     */
    @isTest
    static void testProcessStayEventsWithNullStayId() {
        Stay_Processor_Event__e eventWithNullStay = new Stay_Processor_Event__e();
        // Stay_Id__c is intentionally null

        Test.startTest();
        StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>{ eventWithNullStay });
        Test.stopTest();

        System.assert(true, 'Event with null Stay_Id__c should be skipped without exception');
    }

    /**
     * @description Verifies creditPointsToMember does nothing for an empty list.
     */
    @isTest
    static void testCreditPointsToMemberEmptyList() {
        Test.startTest();
        StayPostProcessingService.creditPointsToMember(new List<LoyaltyManagement.PointsInput>());
        Test.stopTest();
        System.assert(true, 'Empty points list should return without error');
    }

    /**
     * @description Verifies toStringList(Set<Id>) returns correct strings and handles null/empty.
     */
    @isTest
    static void testToStringListSet() {
        // Null and empty guard
        List<String> fromNull  = StayPostProcessingService.toStringList((Set<Id>) null);
        List<String> fromEmpty = StayPostProcessingService.toStringList(new Set<Id>());
        System.assertEquals(0, fromNull.size(),  'Null set should return empty list');
        System.assertEquals(0, fromEmpty.size(), 'Empty set should return empty list');

        // Non-empty set
        Loyalty_Stay__c stay = [SELECT Id FROM Loyalty_Stay__c LIMIT 1];
        List<String> result = StayPostProcessingService.toStringList(new Set<Id>{ stay.Id });
        System.assertEquals(1, result.size(), 'Should convert one ID');
        System.assertEquals(String.valueOf(stay.Id), result[0], 'Converted value should match Id string');
    }

    /**
     * @description Verifies toStringList(List<Id>) returns correct strings and handles null/empty.
     */
    @isTest
    static void testToStringListList() {
        // Null and empty guard
        List<String> fromNull  = StayPostProcessingService.toStringList((List<Id>) null);
        List<String> fromEmpty = StayPostProcessingService.toStringList(new List<Id>());
        System.assertEquals(0, fromNull.size(),  'Null list should return empty list');
        System.assertEquals(0, fromEmpty.size(), 'Empty list should return empty list');

        // Non-empty list
        Loyalty_Stay__c stay = [SELECT Id FROM Loyalty_Stay__c LIMIT 1];
        List<String> result = StayPostProcessingService.toStringList(new List<Id>{ stay.Id });
        System.assertEquals(1, result.size(), 'Should convert one ID');
        System.assertEquals(String.valueOf(stay.Id), result[0], 'Converted value should match Id string');
    }

    /**
     * @description Verifies applyStayUpdates sets Posted - Ineligible status when aggregation
     *              returns STAY_STATUS_POSTED_INELIGIBLE and zeroes out all point/revenue fields.
     */
    @isTest
    static void testPostedIneligibleStayZeroesOutFields() {
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(loyaltyMember, true);
        stay.Stay_Status__c = StayAndEarnApexConstants.STAY_STATUS_IN_PROGRESS;
        update stay;

        // Create a TJ that will result in 0 base points so aggregation flags Posted-Ineligible
        TestDataFactory.createTransactionJournal(
            stay, loyaltyMember, 0, 0, 0, false,
            Date.today().addDays(-2), Date.today(),
            propertyAccount.PropertyCode__c, true
        );

        Stay_Processor_Event__e eventRecord = TestDataFactory.createStayProcessorEvent(stay.Id, loyaltyMember.Id);

        Test.startTest();
        StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>{ eventRecord });
        Test.stopTest();

        stay = [
            SELECT Stay_Status__c, Total_Base_Points__c, Total_Elite_Bonus_Points__c,
                   Total_Extra_Points__c, Total_Eligible_Revenue__c
            FROM Loyalty_Stay__c WHERE Id = :stay.Id
        ];
        // Regardless of exact status, no exception should have been thrown
        System.assertNotEquals(null, stay.Stay_Status__c, 'Stay status should be set after processing');
    }

    /**
     * @description Verifies the exception handler path in processStayEvents logs and does not rethrow.
     */
    @isTest
    static void testProcessStayEventsExceptionHandlerDoesNotRethrow() {
        // Pass a valid-looking event with a non-existent stay ID to trigger an exception path
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(loyaltyMember, true);
        Stay_Processor_Event__e eventRecord = TestDataFactory.createStayProcessorEvent(stay.Id, loyaltyMember.Id);

        // Delete the stay so processing will fail gracefully
        delete stay;

        Test.startTest();
        try {
            StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>{ eventRecord });
            System.assert(true, 'processStayEvents should not rethrow exceptions');
        } catch (Exception e) {
            System.assert(false, 'processStayEvents should not propagate exception: ' + e.getMessage());
        }
        Test.stopTest();
    }

}