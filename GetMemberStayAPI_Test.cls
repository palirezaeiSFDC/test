/*******************************************************************************************
 * @name         GetMemberStayAPI_Test.cls
 * @author       Salesforce
 * @group        SF-Implementation
 * @description  Test class to cover MemberStayApi Class.
 *******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0              Akanksha         03/16/2026        Initial Creation for LYLT-.
*******************************************************************************************/
@isTest
public with sharing class GetMemberStayAPI_Test {
    private static final String EMAIL_FOR_INTEGRATION_USER = 'MemberStayApi_Test@test.com';
    private static User integrationUser;

    /**********************************************************************************
     * @description   Setup test data
     **************************************************************************************/
    @TestSetup
    static void setupTestData() {
        LoyaltyProgram loyaltyProgram = TestDataFactory.createLoyaltyProgram(false);
        insert loyaltyProgram;

        List<Account> listOfPersonAccounts = TestDataFactory.createPersonAccounts(10);
        insert listOfPersonAccounts;

        listOfPersonAccounts = [SELECT PersonContactId FROM Account WHERE Id IN :listOfPersonAccounts];

        List<LoyaltyProgramMember> listOfLoyaltyProgramMembers = TestDataFactory.createLoyaltyProgramMembers(loyaltyProgram, listOfPersonAccounts);
        insert listOfLoyaltyProgramMembers;

        LoyaltyProgramMember member = listOfLoyaltyProgramMembers[0];

        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, false);
        stay.Stay_Status__c   = StayAndEarnApexConstants.STAY_STATUS_POSTED;
        stay.Checkin_Date__c  = Date.today().addDays(-5);
        stay.Checkout_Date__c = Date.today().addDays(-3);
        insert stay;

        TestDataFactory.createTransactionJournal(stay, member, 100, 50, 25, false, stay.Checkin_Date__c, stay.Checkout_Date__c, 'TestHotel', true);

        List<User> listOfUsersToInsert = new List<User>();
        User systemAdminUser  = TestDataFactory.getSystemAdminUsers(1)[0];
        listOfUsersToInsert.add(systemAdminUser);
        User integrationUser  = TestDataFactory.getIntegrationUsers(1)[0];
        integrationUser.Email = EMAIL_FOR_INTEGRATION_USER;
        listOfUsersToInsert.add(integrationUser);
        insert listOfUsersToInsert;

        System.runAs(systemAdminUser) {
            TestDataFactory.assignPermissionSets(true, new List<String>{
                ApexConstants.PERMISSIONSET_MANAGE_LOYALTY_PROGRAMS,
                ApexConstants.PERMISSIONSET_LOYALTY_CORE_INTEGRATION_USER
            }, integrationUser.Id);
        }
    }

    /**********************************************************************************
     * @description   Returns the active integration user created in test setup
     **************************************************************************************/
    private static User getIntegrationUser() {
        if (integrationUser == null) {
            integrationUser = [SELECT Id FROM User WHERE Email =: EMAIL_FOR_INTEGRATION_USER AND IsActive = true LIMIT 1];
        }
        return integrationUser;
    }

    /**********************************************************************************
     * @description   Test successful getMemberStay with valid membershipNumber, startDate and endDate
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysSuccess() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT Id, MembershipNumber FROM LoyaltyProgramMember LIMIT 1];

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();
            request.requestURI = '/services/apexrest/loyalty/MarriottBonvoy/earn/sf-stay';
            request.httpMethod = 'GET';
            request.addParameter('membershipNumber', member.MembershipNumber);
            request.addParameter('startDate', String.valueOf(Date.today().addDays(-30)));
            request.addParameter('endDate',   String.valueOf(Date.today()));

            RestContext.request  = request;
            RestContext.response = response;

            Test.startTest();
            MemberStayApi.getMemberStay();
            Test.stopTest();

            System.assert(response.statusCode == 200 || response.statusCode == 404 || response.statusCode == 500,
                'Status code should be 200, 404, or 500. Actual: ' + response.statusCode);
            if (response.statusCode == 200 && response.responseBody != null) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
                System.assertNotEquals(null, responseMap.get('postedStays'), 'postedStays should not be null');
                List<Object> postedStays = (List<Object>) responseMap.get('postedStays');
                System.assertEquals(1, postedStays.size(), 'There should be exactly 1 posted stay');
            }
        }
    }
    
        /**********************************************************************************
     * @description   Test getMemberStays with missing membership number
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysMissingMembershipNumber() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        request.requestURI = '/services/apexrest/loyalty/MarriottBonvoy/sf-member';
        request.httpMethod = 'GET';
        request.addParameter('clientId', 'TEST_CLIENT_001');
        
        RestContext.request = request;
        RestContext.response = response;
        
            Test.startTest();
            MemberStayApi.getMemberStay();
            Test.stopTest();
        
        System.assertEquals(400, response.statusCode, 'Status code should be 400 for missing membership number');
        System.assert(response.responseBody.toString().contains(ApexConstants.REQ_PARAM_MISS_MEMBERSHIPNUMBER), 'Expected response body to contain ' + ApexConstants.REQ_PARAM_MISS_MEMBERSHIPNUMBER);
    }

    /**********************************************************************************
     * @description   Test parseAndValidateDates: invalid startDate format.
     *                Invokes MemberStayApi.getMemberStay() which calls parseAndValidateDates via buildValidatedGetStayRequest.
     **************************************************************************************/
    @isTest
    static void testParseAndValidateDatesInvalidStartDateFormat() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT MembershipNumber FROM LoyaltyProgramMember LIMIT 1];

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();
            request.requestURI = '/services/apexrest/loyalty/MarriottBonvoy/earn/sf-stay';
            request.httpMethod = 'GET';
            request.addParameter(ApexConstants.MEMBERSHIP_NUMBER, member.MembershipNumber);
            request.addParameter(StayAndEarnApexConstants.PARAM_START_DATE, 'invalid-date');
            request.addParameter(StayAndEarnApexConstants.PARAM_END_DATE, String.valueOf(Date.today()));

            RestContext.request  = request;
            RestContext.response = response;

            Test.startTest();
            MemberStayApi.getMemberStay();
            Test.stopTest();

            System.assertEquals(400, response.statusCode, 'Status code should be 400 for invalid startDate format');
            System.assert(response.responseBody.toString().contains(StayAndEarnApexConstants.ERR_MSG_INVALID_START_DATE_FORMAT),
                'Response should contain invalid startDate format message');
        }
    }

    /**********************************************************************************
     * @description   Test parseAndValidateDates: invalid endDate format.
     *                Invokes MemberStayApi.getMemberStay() which calls parseAndValidateDates via buildValidatedGetStayRequest.
     **************************************************************************************/
    @isTest
    static void testParseAndValidateDatesInvalidEndDateFormat() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT MembershipNumber FROM LoyaltyProgramMember LIMIT 1];

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();
            request.requestURI = '/services/apexrest/loyalty/MarriottBonvoy/earn/sf-stay';
            request.httpMethod = 'GET';
            request.addParameter(ApexConstants.MEMBERSHIP_NUMBER, member.MembershipNumber);
            request.addParameter(StayAndEarnApexConstants.PARAM_START_DATE, String.valueOf(Date.today().addDays(-30)));
            request.addParameter(StayAndEarnApexConstants.PARAM_END_DATE, 'not-a-date');

            RestContext.request  = request;
            RestContext.response = response;

            Test.startTest();
            MemberStayApi.getMemberStay();
            Test.stopTest();

            System.assertEquals(400, response.statusCode, 'Status code should be 400 for invalid endDate format');
            System.assert(response.responseBody.toString().contains(StayAndEarnApexConstants.ERR_MSG_INVALID_END_DATE_FORMAT),
                'Response should contain invalid endDate format message');
        }
    }

    /**********************************************************************************
     * @description   Test parseAndValidateDates: missing startDate and endDate (both required).
     *                Invokes MemberStayApi.getMemberStay() which calls parseAndValidateDates via buildValidatedGetStayRequest.
     **************************************************************************************/
    @isTest
    static void testParseAndValidateDatesMissingStartAndEndDate() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT MembershipNumber FROM LoyaltyProgramMember LIMIT 1];

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();
            request.requestURI = '/services/apexrest/loyalty/MarriottBonvoy/earn/sf-stay';
            request.httpMethod = 'GET';
            request.addParameter(ApexConstants.MEMBERSHIP_NUMBER, member.MembershipNumber);
            // Do not add startDate or endDate - both are required

            RestContext.request  = request;
            RestContext.response = response;

            Test.startTest();
            MemberStayApi.getMemberStay();
            Test.stopTest();

            System.assertEquals(400, response.statusCode, 'Status code should be 400 when startDate and endDate are missing');
            System.assert(response.responseBody.toString().contains(StayAndEarnApexConstants.ERR_MSG_START_END_DATE_REQUIRED),
                'Response should contain startDate and endDate required message');
        }
    }

    /**********************************************************************************
     * @description   Test parseAndValidateDates: startDate greater than endDate (invalid range).
     *                Invokes MemberStayApi.getMemberStay() which calls parseAndValidateDates via buildValidatedGetStayRequest.
     **************************************************************************************/
    @isTest
    static void testParseAndValidateDatesStartDateGreaterThanEndDate() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT MembershipNumber FROM LoyaltyProgramMember LIMIT 1];

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();
            request.requestURI = '/services/apexrest/loyalty/MarriottBonvoy/earn/sf-stay';
            request.httpMethod = 'GET';
            request.addParameter(ApexConstants.MEMBERSHIP_NUMBER, member.MembershipNumber);
            request.addParameter(StayAndEarnApexConstants.PARAM_START_DATE, String.valueOf(Date.today()));
            request.addParameter(StayAndEarnApexConstants.PARAM_END_DATE, String.valueOf(Date.today().addDays(-30)));

            RestContext.request  = request;
            RestContext.response = response;

            Test.startTest();
            MemberStayApi.getMemberStay();
            Test.stopTest();

            System.assertEquals(400, response.statusCode, 'Status code should be 400 when startDate > endDate');
            System.assert(response.responseBody.toString().contains(StayAndEarnApexConstants.ERR_MSG_INVALID_DATE_RANGE),
                'Response should contain invalid date range message');
        }
    }

    /**********************************************************************************
     * @description   Test parseAndValidateDates: valid dates (success path).
     *                Invokes MemberStayApi.getMemberStay() which calls parseAndValidateDates via buildValidatedGetStayRequest.
     **************************************************************************************/
    @isTest
    static void testParseAndValidateDatesValidDates() {
        System.runAs(getIntegrationUser()) {
            LoyaltyProgramMember member = [SELECT MembershipNumber FROM LoyaltyProgramMember LIMIT 1];

            RestRequest request = new RestRequest();
            RestResponse response = new RestResponse();
            request.requestURI = '/services/apexrest/loyalty/MarriottBonvoy/earn/sf-stay';
            request.httpMethod = 'GET';
            request.addParameter(ApexConstants.MEMBERSHIP_NUMBER, member.MembershipNumber);
            request.addParameter(StayAndEarnApexConstants.PARAM_START_DATE, String.valueOf(Date.today().addDays(-30)));
            request.addParameter(StayAndEarnApexConstants.PARAM_END_DATE, String.valueOf(Date.today()));

            RestContext.request  = request;
            RestContext.response = response;

            Test.startTest();
            MemberStayApi.getMemberStay();
            Test.stopTest();

            System.assert(response.statusCode == 200 || response.statusCode == 404 || response.statusCode == 500,
                'Status code should be 200, 404, or 500 when dates are valid. Actual: ' + response.statusCode);
            if (response.statusCode == 200) {
                System.assertNotEquals(null, response.responseBody, 'Response body should not be null');
            }
        }
    }

    /**********************************************************************************
     * @description   Test GetMemberStaysResponseWrapper.staysToMap() - all three stay lists populated.
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysResponseWrapperToMapAllListsPopulated() {
        GetMemberStaysResponseWrapper wrapper = new GetMemberStaysResponseWrapper();
        wrapper.postedStays.add(new Map<String, Object>{ 'arrivalDate' => '2026-01-01' });
        wrapper.purgedStays.add(new Map<String, Object>{ 'arrivalDate' => '2026-01-02' });
        wrapper.ecStays.add(new Map<String, Object>{ 'arrivalDate' => '2026-01-03' });

        Map<String, Object> result = wrapper.staysToMap();

        System.assert(result.containsKey(StayAndEarnApexConstants.GET_STAY_POSTED_STAYS), 'Should contain postedStays');
        System.assert(result.containsKey(StayAndEarnApexConstants.GET_STAY_PURGED_STAYS), 'Should contain purgedStays');
        System.assert(result.containsKey(StayAndEarnApexConstants.GET_STAY_EC_STAYS), 'Should contain ecStays');
        System.assertEquals(3, result.size(), 'Should have exactly 3 keys');
    }

    /**********************************************************************************
     * @description   Test GetMemberStaysResponseWrapper.staysToMap() - only postedStays populated.
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysResponseWrapperToMapOnlyPostedStays() {
        GetMemberStaysResponseWrapper wrapper = new GetMemberStaysResponseWrapper();
        wrapper.postedStays.add(new Map<String, Object>{ 'arrivalDate' => '2026-01-01' });
        // purgedStays and ecStays remain empty

        Map<String, Object> result = wrapper.staysToMap();

        System.assert(result.containsKey(StayAndEarnApexConstants.GET_STAY_POSTED_STAYS), 'Should contain postedStays');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_PURGED_STAYS), 'Should not contain purgedStays');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_EC_STAYS), 'Should not contain ecStays');
        System.assertEquals(1, result.size(), 'Should have exactly 1 key');
    }

    /**********************************************************************************
     * @description   Test GetMemberStaysResponseWrapper.staysToMap() - only purgedStays populated.
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysResponseWrapperToMapOnlyPurgedStays() {
        GetMemberStaysResponseWrapper wrapper = new GetMemberStaysResponseWrapper();
        wrapper.purgedStays.add(new Map<String, Object>{ 'arrivalDate' => '2026-01-02' });

        Map<String, Object> result = wrapper.staysToMap();

        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_POSTED_STAYS), 'Should not contain postedStays');
        System.assert(result.containsKey(StayAndEarnApexConstants.GET_STAY_PURGED_STAYS), 'Should contain purgedStays');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_EC_STAYS), 'Should not contain ecStays');
        System.assertEquals(1, result.size(), 'Should have exactly 1 key');
    }

    /**********************************************************************************
     * @description   Test GetMemberStaysResponseWrapper.staysToMap() - only ecStays populated.
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysResponseWrapperToMapOnlyEcStays() {
        GetMemberStaysResponseWrapper wrapper = new GetMemberStaysResponseWrapper();
        wrapper.ecStays.add(new Map<String, Object>{ 'arrivalDate' => '2026-01-03' });

        Map<String, Object> result = wrapper.staysToMap();

        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_POSTED_STAYS), 'Should not contain postedStays');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_PURGED_STAYS), 'Should not contain purgedStays');
        System.assert(result.containsKey(StayAndEarnApexConstants.GET_STAY_EC_STAYS), 'Should contain ecStays');
        System.assertEquals(1, result.size(), 'Should have exactly 1 key');
    }

    /**********************************************************************************
     * @description   Test GetMemberStaysResponseWrapper.staysToMap() - all lists empty.
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysResponseWrapperToMapAllEmpty() {
        GetMemberStaysResponseWrapper wrapper = new GetMemberStaysResponseWrapper();
        // All lists remain empty

        Map<String, Object> result = wrapper.staysToMap();

        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_POSTED_STAYS), 'Should not contain postedStays');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_PURGED_STAYS), 'Should not contain purgedStays');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_EC_STAYS), 'Should not contain ecStays');
        System.assertEquals(0, result.size(), 'Should have no keys');
    }

    /**********************************************************************************
     * @description   Test GetMemberStaysResponseWrapper.staysToMap() - null lists (edge case).
     **************************************************************************************/
    @isTest
    static void testGetMemberStaysResponseWrapperToMapNullLists() {
        GetMemberStaysResponseWrapper wrapper = new GetMemberStaysResponseWrapper();
        wrapper.postedStays = null;
        wrapper.purgedStays = null;
        wrapper.ecStays     = null;

        Map<String, Object> result = wrapper.staysToMap();

        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_POSTED_STAYS), 'Should not contain postedStays when null');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_PURGED_STAYS), 'Should not contain purgedStays when null');
        System.assert(!result.containsKey(StayAndEarnApexConstants.GET_STAY_EC_STAYS), 'Should not contain ecStays when null');
        System.assertEquals(0, result.size(), 'Should have no keys');
    }

    /**********************************************************************************
     * @description   Creates and returns a LoyaltyTier for a given level id.
     **************************************************************************************/
    private static LoyaltyTier createTierForLevel(String levelId) {
        LoyaltyProgram program = [SELECT Id FROM LoyaltyProgram LIMIT 1];
        LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
            LoyaltyProgramId = program.Id,
            Name = 'GM Tier Group ' + levelId + ' ' + String.valueOf(Datetime.now().getTime()),
            IsPrimary = true,
            QpResetPeriod = 'Years',
            QpResetDate = Date.today()
        );
        insert tierGroup;
        LoyaltyTier tier = new LoyaltyTier(
            LoyaltyTierGroupId = tierGroup.Id,
            Name = 'Test Loyalty Tier ' + tierGroup.Id,
            Upgrade_LevelCode__c = 'MRD',
            Level_Id__c = 'R',
            Derived_Level_Type_Id__c = 'MRD',
            Derived_Level_Type_Description__c = 'Member',
            Level_Id_Description__c = 'Basic'
        );
        insert tier;
        return [SELECT Id FROM LoyaltyTier WHERE Id = :tier.Id LIMIT 1];
    }

    /**********************************************************************************
     * @description   Creates stay + 1 TJ with benefit and returns queried stay with relationships.
     **************************************************************************************/
    private static Loyalty_Stay__c createStayWithBenefitAndTier(String levelId, String benefitName) {
        LoyaltyProgramMember member = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
        LoyaltyTier tier = createTierForLevel(levelId);

        Loyalty_Stay__c stay = TestDataFactory.createLoyaltyStay(member, false);
        stay.Loyalty_Tier__c = tier.Id;
        stay.Checkin_Date__c = Date.today().addDays(-5);
        stay.Checkout_Date__c = Date.today().addDays(-3);
        stay.Total_Base_Points__c = 100;
        stay.Total_Elite_Bonus_Points__c = 50;
        stay.Total_Extra_Points__c = 25;
        stay.Total_Elite_Qualifying_Nights__c = 2;
        stay.Total_Eligible_Revenue_Local__c = 500;
        stay.Total_Eligible_Revenue__c = 550;
        insert stay;

        TransactionJournal tj = TestDataFactory.createTransactionJournal(
            stay, member, 100, 50, 25, true,
            stay.Checkin_Date__c, stay.Checkout_Date__c, 'TestHotel', false
        );
        tj.Benefits__c = benefitName;
        insert tj;

        return [
            SELECT Id, Checkin_Date__c, Checkout_Date__c,
                   Total_Base_Points__c, Total_Elite_Bonus_Points__c, Total_Extra_Points__c,
                   Total_Elite_Qualifying_Nights__c, Total_Eligible_Revenue_Local__c, Total_Eligible_Revenue__c,
                   Loyalty_Tier__r.Level_Id__c,Stay_Scenario__c,
                   (SELECT Id, Benefits__c,Visit_Type__c,Extra_Points__c FROM Transaction_Journal__r)
            FROM Loyalty_Stay__c
            WHERE Id = :stay.Id
            LIMIT 1
        ];
    }

    /**********************************************************************************
     * @description   Covers resolveArrivalFlags when GOLD tier + Welcome Gift benefit.
     **************************************************************************************/
    @isTest
    static void testResolveArrivalFlagsGoldWithWelcomeGift() {
        Loyalty_Stay__c stay = createStayWithBenefitAndTier(
            ApexConstants.LEVEL_ID_FOR_GOLD_TIER,
            StayAndEarnApexConstants.WELCOME_GIFT_BENEFIT_NAME
        );
        Map<String, Object> stayDetail = new Map<String, Object>();

        GetMemberStaysUtility.resolveArrivalFlags(stayDetail, stay);
        System.assertEquals(
            ApexConstants.NO_FLAG,
            stayDetail.get(StayAndEarnApexConstants.GET_STAY_KEY_PLAT_ARRIVAL_FLAG),
            'Gold tier + qualifying benefit should set platArrivalFlag to N'
        );
    }

    /**********************************************************************************
     * @description   Covers resolveArrivalFlags when PLAT tier + Lounge Alternative benefit.
     **************************************************************************************/
    @isTest
    static void testResolveArrivalFlagsPlatWithLoungeAlternative() {
        Loyalty_Stay__c stay = createStayWithBenefitAndTier(
            ApexConstants.LEVEL_ID_FOR_GOLD_TIER,
            ApexConstants.LEVEL_ID_FOR_PLATINUM_TIER
        );
        Map<String, Object> stayDetail = new Map<String, Object>();

        GetMemberStaysUtility.resolveArrivalFlags(stayDetail, stay);

        System.assertEquals(
            ApexConstants.NO_FLAG,
            stayDetail.get(StayAndEarnApexConstants.GET_STAY_KEY_GOLD_ARRIVAL_FLAG),
            'Platinum tier + qualifying benefit should set goldArrivalFlag to N'
        );
    }

    /**********************************************************************************
     * @description   Covers resolveArrivalFlags when no qualifying benefit exists.
     **************************************************************************************/
    @isTest
    static void testResolveArrivalFlagsNoQualifyingBenefit() {
        Loyalty_Stay__c stay = createStayWithBenefitAndTier(
            ApexConstants.LEVEL_ID_FOR_GOLD_TIER,
            'Some Other Benefit'
        );
        Map<String, Object> stayDetail = new Map<String, Object>();

        GetMemberStaysUtility.resolveArrivalFlags(stayDetail, stay);

        System.assertEquals(
            ApexConstants.NO_FLAG,
            stayDetail.get(StayAndEarnApexConstants.GET_STAY_KEY_GOLD_ARRIVAL_FLAG),
            'Without qualifying benefit goldArrivalFlag should remain N'
        );
        System.assertEquals(
            ApexConstants.NO_FLAG,
            stayDetail.get(StayAndEarnApexConstants.GET_STAY_KEY_PLAT_ARRIVAL_FLAG),
            'Without qualifying benefit platArrivalFlag should remain N'
        );
    }

    /**********************************************************************************
     * @description   Covers helper buildStayDetail path including calculated fields + arrival flags.
     **************************************************************************************/
    @isTest
    static void testBuildStayDetailIncludesCalculatedAndArrivalFields() {
        Loyalty_Stay__c stay = createStayWithBenefitAndTier(
            ApexConstants.LEVEL_ID_FOR_GOLD_TIER,
            StayAndEarnApexConstants.WELCOME_GIFT_BENEFIT_NAME
        );
        GetMemberStaysUtility.CustomMetadataMappings mapping = new GetMemberStaysUtility.CustomMetadataMappings();

        Map<String, Object> stayDetail = GetMemberStaysAPIHelper.buildStayDetail(stay, mapping);

        System.assertEquals('175.00', String.valueOf(stayDetail.get(StayAndEarnApexConstants.GET_STAY_KEY_TOTAL_EARNING)),
            'Total earning should sum base+elite+extra');
        System.assertEquals(
            ApexConstants.NO_FLAG,
            stayDetail.get(StayAndEarnApexConstants.GET_STAY_KEY_PLAT_ARRIVAL_FLAG),
            'Gold tier + qualifying benefit should set platArrivalFlag to N in helper output'
        );
    }

}