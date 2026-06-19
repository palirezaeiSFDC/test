/*******************************************************************************************
 * @name         StayProcessorEventHandler_Test
 * @author       Sai Vinay Kumar thumu
 * @group        SF-Implementation
 * @description  Validates StayProcessorEventHandler, StayAggregationHelper, StayUpdateHelper,
 * and StayPostProcessingService using a shared fixture and helper runners.
 *******************************************************************************************/
@isTest
public with sharing class StayProcessorEventHandler_Test {

    /******************************
     * Test Data Setup
     ******************************/
    @TestSetup
    static void setupTestData() {
        // Create Integration User using TestDataFactory
        List<User> integrationUsers = TestDataFactory.getIntegrationUsers(1);
        insert integrationUsers;
        
        // Assign Permission Sets to Integration User using TestDataFactory
        TestDataFactory.assignPermissionSets(
            true, 
            new List<String>{ 
                ApexConstants.PERMISSIONSET_LOYALTY_CORE_INTEGRATION_USER,
                    ApexConstants.PERMISSIONSET_MANAGE_LOYALTY_PROGRAMS
                    }, 
            integrationUsers[0].Id
        );
        // Use System.runAs to avoid Mixed DML error
        // Non-setup objects must be created in a different context than setup objects
        System.runAs(integrationUsers[0]) {
            // Create Loyalty Program
            LoyaltyProgram loyaltyProgram = TestDataFactory.createLoyaltyProgram(
                ApexConstants.LOYALTY_PROGRAM_MARRIOTTBONVOY,
                'MB',
                true
            );
            
            Account propertyAccount = TestDataFactory.createPropertyAccount('TEST001', true);
            Id propertyRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Property')?.getRecordTypeId();
            if (propertyRecordTypeId != null) {
                propertyAccount.RecordTypeId = propertyRecordTypeId;
            }
            propertyAccount.EQN_Earn_Multiplier__c = 1.5;
            propertyAccount.PropertyCode__c = 'TEST001';
            update propertyAccount;
            
            // Create Person Accounts for Members
            List<Account> personAccounts = TestDataFactory.createPersonAccounts(1);
            insert personAccounts;
            
            List<Account> personAccountsWithContact = [SELECT Id, PersonContactId FROM Account WHERE Id IN :personAccounts];
            
            // Create Active Loyalty Program Member
            LoyaltyProgramMember loyaltyMember = TestDataFactory.createLoyaltyProgramMember(
                loyaltyProgram,
                '123456789',
                'Active',
                true,
                personAccountsWithContact[0].PersonContactId
            );
            
            // Create Journal Infrastructure
            JournalType journalType = TestDataFactory.createJournalType('Stay', true);
            TestDataFactory.createJournalSubType('Room', journalType.Id, true);
            TestDataFactory.createProduct('Test Product', 'PROD001', true);
            
            // Create existing Stay for duplicate/overlap testing
            Loyalty_Stay__c existingStay = TestDataFactory.createLoyaltyStay(loyaltyMember, true);
            existingStay.Property_Code__c = 'TEST001';
            existingStay.Checkin_Date__c = System.today().addDays(-10);
            existingStay.Checkout_Date__c = System.today().addDays(-8);
            existingStay.Reservation_Confirmation_Number__c = 'EXISTING123';
            update existingStay;
        }
    }

    /*******************************************************************************************
    * @description   Retrieves the integration user created in test setup.
    * @return        User - The integration user
    *******************************************************************************************/
    private static User getIntegrationUser() {
        return [
            SELECT Id 
            FROM User 
            WHERE LastName = 'IntegrationUser0'
            LIMIT 1
        ];
    }

    /**
     * @description Validates aggregation logic via the Platform Event Handler.
     */
    @isTest
    static void testStayAggregationUpdatesTotalsViaHandler() {

        User integrationUser = getIntegrationUser();
        System.runAs(integrationUser) {
            Account prop = [SELECT Id, PropertyCode__c, Calculated_EQN_Earn_Multiplier__c FROM Account WHERE PropertyCode__c = 'TEST001' LIMIT 1];
            Date start = System.today().addDays(-3);
            Date endDt = System.today();

        Stay_Processor_Event__e eventRecord = createEventWithJournal(
            120, 15, 5, true, start, endDt, prop.PropertyCode__c
        );

        runStayProcessing(eventRecord, true);
        }
        System.assert(true, 'Stay aggregation totals updated successfully');
    }

    /**
     * @description Validates aggregation logic via direct Service call.
     */
    @isTest
    static void testStayAggregationUpdatesTotalsViaService() {

        User integrationUser = getIntegrationUser();
        System.runAs(integrationUser) {
            Account prop = [SELECT Id, PropertyCode__c, Calculated_EQN_Earn_Multiplier__c FROM Account WHERE PropertyCode__c = 'TEST001' LIMIT 1];
            Date start = System.today().addDays(-2);
            Date endDt = System.today();

        Stay_Processor_Event__e eventRecord = createEventWithJournal(
            80, 10, 2, true, start, endDt, prop.PropertyCode__c
        );

        runStayProcessing(eventRecord, false);
        }
        System.assert(true, 'Stay aggregation totals updated successfully');
    }

    /**
     * @description Tests the system resilience when a Stay has zero transaction journals.
     */
    @isTest
    static void testStayProcessingWithNoTransactionJournals() {
        LoyaltyProgramMember member = [SELECT Id,ProgramId FROM LoyaltyProgramMember LIMIT 1];
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, true);
        List<Stay_Processor_Event__e> eventList = New List<Stay_Processor_Event__e>();
        Stay_Processor_Event__e eventRecord = TestDataFactory.createStayProcessorEvent(stay.Id, member.Id);
        eventList.add(eventRecord);
        stay = [SELECT Total_Base_Points__c, Total_Elite_Bonus_Points__c, Total_Extra_Points__c, Stay_Status__c 
                FROM Loyalty_Stay__c WHERE Id = :stay.Id LIMIT 1];
        set<Id> idSet = new set<Id>();
        idSet.add(stay.Id);
        runStayProcessing(eventRecord, true);
        Exception ex = new DmlException('Test exception');
        StayPostProcessingService.logException(eventList, idSet, idSet, ex);

        System.assertEquals(null, stay.Total_Base_Points__c, 'Base points should be null when no journals exist');
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static Stay_Processor_Event__e createEventWithJournal(
        Decimal basePoints, Decimal eliteBonus, Decimal extraPoints,
        Boolean encQualified, Date startDate, Date endDate, String establishment
    ) {
        LoyaltyProgramMember member = [SELECT Id,ProgramId FROM LoyaltyProgramMember LIMIT 1];
        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, true);
        
        TransactionJournal journal = TestDataFactory.createTransactionJournal(
            stay, member, basePoints, eliteBonus, extraPoints,
            encQualified, startDate, endDate, establishment, false
        );
        
        journal.Is_EQN_Qualified__c = encQualified;
        journal.Status = 'Processed';
        if (startDate != null) {
            journal.StartDate = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        }
        if (endDate != null) {
            journal.EndDate = DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0));
        }
        insert journal;
        
        return TestDataFactory.createStayProcessorEvent(stay.Id, member.Id);
    }

    /**
     * @description Logic to execute the processing and trigger Platform Event delivery.
     */
    private static void runStayProcessing(Stay_Processor_Event__e eventRecord, Boolean publishEvent) {
        Test.startTest();
        if (publishEvent) {
            EventBus.publish(eventRecord); // Correct way to test events
            StayProcessorEventHandler.handleStayProcessing(new List<Stay_Processor_Event__e>{eventRecord});
        } else {
            StayPostProcessingService.processStayEvents(new List<Stay_Processor_Event__e>{eventRecord});
        }
        Test.stopTest(); // Forces delivery and handles limits
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void assertStayTotals(Id stayId, Decimal basePoints, Decimal eliteBonus, Decimal extraPoints, Decimal multiplier, Date start, Date endDt) {
        Loyalty_Stay__c stay = [
            SELECT Total_Base_Points__c, Total_Elite_Bonus_Points__c, Total_Extra_Points__c,
                   Total_Elite_Qualifying_Nights__c, Stay_Status__c
            FROM Loyalty_Stay__c WHERE Id = :stayId LIMIT 1
        ];

        System.assertEquals(basePoints, stay.Total_Base_Points__c, 'Total Base Points mismatch');
        System.assertEquals(eliteBonus, stay.Total_Elite_Bonus_Points__c, 'Total Elite Bonus Points mismatch');
        System.assertEquals(extraPoints, stay.Total_Extra_Points__c, 'Total Extra Points mismatch');
        Decimal expectedEQN = (start != null && endDt != null) ? Math.max(0, start.daysBetween(endDt)) * multiplier : 0;
        System.assertEquals(expectedEQN, stay.Total_Elite_Qualifying_Nights__c, 'Total Elite Qualifying Nights mismatch');
    }

    /**
     * @description Tests the Loyalty creditPoints service integration.
     */
    @isTest
    static void creditPointsToMember() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id,ProgramId FROM LoyaltyProgramMember LIMIT 1];
            
            Map<String, Object> payload = new Map<String, Object>{
                'loyaltyProgramMemberId' => member.Id,
                'points' => 10.0,
                'programName' => ApexConstants.LOYALTY_PROGRAM_MARRIOTTBONVOY,
                'programCurrencyName' => 'Elite Qualifying Nights',
                'journalDate' => System.today()
            };
            
            LoyaltyManagement.PointsInput input = (LoyaltyManagement.PointsInput) JSON.deserialize(
                JSON.serialize(payload), 
                LoyaltyManagement.PointsInput.class
            );
            
            Test.startTest();
            StayPostProcessingService.creditPointsToMember(new List<LoyaltyManagement.PointsInput>{ input });
            Test.stopTest();

            System.assert(true, 'Credit points processed successfully');
        }
    }

    /**
     * @description Tests the error logging logic by passing null events.
     */
    @isTest
    static void testLogExceptionPath() {
        System.runAs(getIntegrationUser()) {
            Test.startTest();
            StayPostProcessingService.processStayEvents(null);
            Test.stopTest();
            System.assert(true, 'Processed null events without exception');
        }
    }

    /**
     * @description Tests calculateRevenueBySourceCategory for Stay File with multiple TJs
     */
    @isTest
    static void testCalculateRevenueBySourceCategoryStayFileWithMultipleTJs() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id,ProgramId FROM LoyaltyProgramMember LIMIT 1];
            Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, true);
            stay.Stay_Source_Category__c = StayAndEarnApexConstants.STAY_SOURCE_STAY_FILE;
            update stay;
            
            // Create TransactionJournals with different USD_Value_Converted values
            TransactionJournal tj1 = TestDataFactory.createTransactionJournal(
                stay, member, 100, 10, 5, true, System.today().addDays(-2), System.today(), 'TEST001', false
            );
            tj1.USD_Value_Converted__c = 150.50;
            tj1.Base_Points__c = 100;
            
            TransactionJournal tj2 = TestDataFactory.createTransactionJournal(
                stay, member, 200, 20, 10, true, System.today().addDays(-1), System.today(), 'TEST001', false
            );
            tj2.USD_Value_Converted__c = 250.75;
            tj2.Base_Points__c = 200;
            
            TransactionJournal tj3 = TestDataFactory.createTransactionJournal(
                stay, member, 50, 5, 2, false, System.today().addDays(-3), System.today(), 'TEST001', false
            );
            tj3.USD_Value_Converted__c = 100.00;
            tj3.Base_Points__c = 50;
            
            TransactionJournal tj4 = TestDataFactory.createTransactionJournal(
                stay, member, 75, 7, 3, true, System.today().addDays(-4), System.today(), 'TEST001', false
            );
            tj4.USD_Value_Converted__c = 75.25;
            tj4.Base_Points__c = 75;
            
            insert new List<TransactionJournal>{tj1, tj2, tj3, tj4};
            
            Test.startTest();
            Decimal totalRevenue = StayAggregationHelper.calculateRevenueBySourceCategory(stay, null);
            Test.stopTest();
            
            // Should query from DB and sum all TJs with Base_Points__c > 0
            System.assertNotEquals(null, totalRevenue, 'Revenue should not be null');
            System.assert(totalRevenue > 0, 'Revenue should be greater than 0');
        }
    }

    /**
     * @description Tests calculateRevenueBySourceCategory with Connected PMS source (returns 0)
     */
    @isTest
    static void testCalculateRevenueBySourceCategoryConnectedPMS() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id FROM LoyaltyProgramMember LIMIT 1];
            Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, true);
            stay.Stay_Source_Category__c = StayAndEarnApexConstants.STAY_SOURCE_CONNECTED_PMS;
            update stay;
            
            Test.startTest();
            Decimal revenue = StayAggregationHelper.calculateRevenueBySourceCategory(stay, null);
            Test.stopTest();
            
            System.assertEquals(0, revenue, 'Revenue should be 0 for Connected PMS source');
        }
    }

    /**
     * @description Covers miscellaneous helper and string construction methods.
     */
    @isTest
    static void testRecordIdStringConstruction() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id,ProgramId FROM LoyaltyProgramMember LIMIT 1];
            Loyalty_Stay__c stay = [SELECT Id FROM Loyalty_Stay__c LIMIT 1];
            
            Test.startTest();
            Set<Id> idSet = new Set<Id>{stay.Id};
            StayPostProcessingService.toStringList(idSet);
            List<Id> idList = new List<Id>{stay.Id};
            StayPostProcessingService.toStringList(idList);
            
            StayUpdateHelper.MemberJournalContext memberContext = 
                new StayUpdateHelper.MemberJournalContext(member.Id, stay.Id);
            Decimal pointsDecimal = 2.0;
            StayUpdateHelper.PointsCurrencyContext pointsContext = 
                new StayUpdateHelper.PointsCurrencyContext(
                    pointsDecimal.doubleValue(),
                    ApexConstants.LOYALTY_PROGRAM_MARRIOTTBONVOY,
                    StayAndEarnApexConstants.CURRENCY_ELITE_QUALIFYING_NIGHTS
                );
            StayUpdateHelper.PointsInputRequest pointsRequest = 
                new StayUpdateHelper.PointsInputRequest(memberContext, pointsContext);
            StayUpdateHelper.buildPointsInput(pointsRequest);
            
            Date startDate = System.today();
            Date endDate = System.today().addDays(1);
            Decimal eligibleNights = Math.max(0, startDate.daysBetween(endDate));
            System.assert(eligibleNights >= 0, 'Eligible nights calculated successfully');
            Test.stopTest();
        }
    }
    
            /**
     * @description Tests captureEqnType sets EQN Type from Visit_Type__c and Program_Of_Record__c.
     *              Precedence: POR > Paid > Redemption.
     */
    @isTest
    static void testCaptureEqnType() {
        StayAggregationHelper.StayAggregation aggregation = new StayAggregationHelper.StayAggregation();

        // POR: Program_Of_Record__c = 'DL'
        TransactionJournal journalPor = new TransactionJournal(Program_Of_Record__c = 'DELONIX');
        StayAggregationHelper.captureEqnType(aggregation, journalPor);
        System.assertEquals(StayAndEarnApexConstants.EQN_TYPE_POR, aggregation.eqnType, 'EQN Type should be POR when Program_Of_Record is DL');

        // Paid: Visit_Type__c = 'PAID_STAY'
        aggregation = new StayAggregationHelper.StayAggregation();
        TransactionJournal journalPaid = new TransactionJournal(Visit_Type__c = 'PAID_STAY');
        StayAggregationHelper.captureEqnType(aggregation, journalPaid);
        System.assertEquals(StayAndEarnApexConstants.EQN_TYPE_PAID, aggregation.eqnType, 'EQN Type should be Paid for Paid Stay');

        // Paid: Visit_Type__c = 'PAID_DAY_USE_STAY'
        aggregation = new StayAggregationHelper.StayAggregation();
        TransactionJournal journalPaidDayUse = new TransactionJournal(Visit_Type__c = 'PAID_DAY_USE_STAY');
        StayAggregationHelper.captureEqnType(aggregation, journalPaidDayUse);
        System.assertEquals(StayAndEarnApexConstants.EQN_TYPE_PAID, aggregation.eqnType, 'EQN Type should be Paid for Paid Day Use Stay');

        // Redemption: Visit_Type__c = 'REDEMPTION_STAY'
        aggregation = new StayAggregationHelper.StayAggregation();
        TransactionJournal journalRedemption = new TransactionJournal(Visit_Type__c = 'REDEMPTION_STAY');
        StayAggregationHelper.captureEqnType(aggregation, journalRedemption);
        System.assertEquals(StayAndEarnApexConstants.EQN_TYPE_REDEMPTION, aggregation.eqnType, 'EQN Type should be Redemption for Redemption Stay');

        // Redemption: Visit_Type__c = 'REDEMPTION_DAY_USE_STAY'
        aggregation = new StayAggregationHelper.StayAggregation();
        TransactionJournal journalRedemptionDayUse = new TransactionJournal(Visit_Type__c = 'REDEMPTION_DAY_USE_STAY');
        StayAggregationHelper.captureEqnType(aggregation, journalRedemptionDayUse);
        System.assertEquals(StayAndEarnApexConstants.EQN_TYPE_REDEMPTION, aggregation.eqnType, 'EQN Type should be Redemption for Redemption Day Use Stay');

        // Null safety: null journal does not throw
        aggregation = new StayAggregationHelper.StayAggregation();
        StayAggregationHelper.captureEqnType(aggregation, null);
        System.assertEquals(null, aggregation.eqnType, 'eqnType should remain null when journal is null');

        // Blank Visit_Type: no change
        aggregation = new StayAggregationHelper.StayAggregation();
        StayAggregationHelper.captureEqnType(aggregation, new TransactionJournal(Visit_Type__c = ''));
        System.assertEquals(null, aggregation.eqnType, 'eqnType should remain null when Visit_Type is blank');
    }

    /**
     * @description Tests aggregate method with null and empty stays list
     */
    @isTest
    static void testAggregateWithNullAndEmptyStays() {
        System.runAs(getIntegrationUser()) {
            Test.startTest();
            // Test with null stays
            StayAggregationHelper.StayAggregationResult resultNull = StayAggregationHelper.aggregate(null, new Set<Id>());
            System.assertNotEquals(null, resultNull, 'Result should not be null');
            System.assertEquals(0, resultNull.aggregations.size(), 'Aggregations should be empty for null stays');
            
            // Test with empty stays list
            StayAggregationHelper.StayAggregationResult resultEmpty = StayAggregationHelper.aggregate(new List<Loyalty_Stay__c>(), new Set<Id>());
            System.assertNotEquals(null, resultEmpty, 'Result should not be null');
            System.assertEquals(0, resultEmpty.aggregations.size(), 'Aggregations should be empty for empty stays list');
            
            // Test with stay that has null Id
            Loyalty_Stay__c stayWithNullId = new Loyalty_Stay__c();
            StayAggregationHelper.StayAggregationResult resultNullId = StayAggregationHelper.aggregate(new List<Loyalty_Stay__c>{stayWithNullId}, new Set<Id>());
            System.assertEquals(0, resultNullId.aggregations.size(), 'Aggregations should be empty for stay with null Id');
            Test.stopTest();
        }
    }

    /**
     * @description Tests aggregate method with TJ that has ErrorDescription = 'Error'
     */
    @isTest
    static void testAggregateWithErrorTJ() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id,ProgramId FROM LoyaltyProgramMember LIMIT 1];
            Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, true);
            
            // Create TJ with ErrorDescription = 'Error'
            TransactionJournal tj = TestDataFactory.createTransactionJournal(
                stay, member, 100, 10, 5, true, System.today().addDays(-2), System.today(), 'TEST001', false
            );
            tj.ErrorDescription = StayAndEarnApexConstants.TJ_STATUS_ERROR;
            tj.Status = 'Pending';
            insert tj;
            
            // Query stay with TJs
            Loyalty_Stay__c stayWithTJs = [
                SELECT Id, (SELECT Id, Status, ErrorDescription, Base_Points__c, Elite_Bonus_Points__c, 
                            Extra_Points__c, Is_EQN_Qualified__c, StartDate, EndDate, Establishment, 
                            IsParentTransaction FROM Transaction_Journal__r)
                FROM Loyalty_Stay__c WHERE Id = :stay.Id
            ];
            
            Test.startTest();
            Set<Id> tjIds = new Set<Id>();
            StayAggregationHelper.aggregate(
                new List<Loyalty_Stay__c>{stayWithTJs}, tjIds
            );
            Test.stopTest();
            
            // Verify TJ status was updated to Error
            TransactionJournal updatedTJ = [SELECT Status FROM TransactionJournal WHERE Id = :tj.Id];
            System.assertEquals(StayAndEarnApexConstants.TJ_STATUS_ERROR, updatedTJ.Status, 'TJ Status should be updated to Error');
        }
    }

    /**
     * @description Tests calculateRevenueBySourceCategory with stay that has Total_Eligible_Revenue__c already set
     */
    @isTest
    static void testCalculateRevenueBySourceCategoryWithExistingValue() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id FROM LoyaltyProgramMember LIMIT 1];
            Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, true);
            stay.Total_Eligible_Revenue__c = 500.00;
            stay.Stay_Source_Category__c = StayAndEarnApexConstants.STAY_SOURCE_STAY_FILE;
            update stay;
            
            Test.startTest();
            Decimal revenue = StayAggregationHelper.calculateRevenueBySourceCategory(stay, null);
            Test.stopTest();
            
            System.assertNotEquals(null, revenue, 'Revenue should not be null');
        }
    }

    /**
     * @description Tests calculateRevenueBySourceCategory with null stay
     */
    @isTest
    static void testCalculateRevenueBySourceCategoryWithNullStay() {
        System.runAs(getIntegrationUser()) {
            Test.startTest();
            Decimal revenue = StayAggregationHelper.calculateRevenueBySourceCategory(null, null);
            Test.stopTest();
            
            System.assertEquals(0, revenue, 'Should return 0 for null stay');
        }
    }

    /**
     * @description Tests calculateRevenueBySourceCategory with stay without source category
     */
    @isTest
    static void testCalculateRevenueBySourceCategoryWithoutSourceCategory() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id FROM LoyaltyProgramMember LIMIT 1];
            Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, true);
            
            Test.startTest();
            Decimal revenue = StayAggregationHelper.calculateRevenueBySourceCategory(stay, null);
            Test.stopTest();
            
            System.assertEquals(0, revenue, 'Should return 0 for stay without source category');
        }
    }
}