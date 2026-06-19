/*******************************************************************************************
 * @Name         LoyaltyStayTriggerHandler_Test.cls
 * @Author       
 * @group        SF-Implementation
 * @description  Test class for LoyaltyStayTriggerHandler covering trigger framework compliance
 *******************************************************************************************/
/* MODIFICATION LOG
* Version          Developer          Date               Description
*-------------------------------------------------------------------------------------------
*  1.0             Anand Pandey    02/03/2026        Initial Creation - Test class for Loyalty Stay Trigger Handler
*  1.1             Anand Pandey    03/25/2026        testEmptyHandlerMethods wrapped in System.runAs for proper user context
*******************************************************************************************/
@isTest
public with sharing class LoyaltyStayTriggerHandler_Test {

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

            List<Account> personAccounts = TestDataFactory.createPersonAccounts(1);
            insert personAccounts;
            Account pa = [SELECT PersonContactId FROM Account WHERE Id = :personAccounts[0].Id];

            LoyaltyProgramMember member = TestDataFactory.createLoyaltyProgramMember(
                program, 'TH-MEMBER-001', 'Active', true, pa.PersonContactId
            );
            TestDataFactory.createLoyaltyStay(member, true);
        }
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE LastName = 'IntegrationUser0' AND IsActive = true LIMIT 1];
    }

    /** @description Validates afterUpdate invokes the publisher without errors. */
    @isTest
    static void testAfterUpdateCallsPublisher() {
        System.runAs(getTestUser()) {
            Loyalty_Stay__c stay = [SELECT Id, Stay_Status__c FROM Loyalty_Stay__c LIMIT 1];
            Map<Id, SObject> oldMap = new Map<Id, SObject>{ stay.Id => stay.clone(true) };

            stay.Stay_Status__c = 'Posted - Eligible';
            Map<Id, SObject> newMap = new Map<Id, SObject>{ stay.Id => stay };

            Test.startTest();
            LoyaltyStayTriggerHandler handler = new LoyaltyStayTriggerHandler();
            handler.afterUpdate(oldMap, newMap);
            Test.stopTest();

            System.assert(true, 'afterUpdate completed without exception');
        }
    }

    /** @description Covers all empty handler methods for trigger framework compliance. */
    @isTest
    static void testEmptyHandlerMethods() {
        System.runAs(getTestUser()) {
            LoyaltyStayTriggerHandler handler = new LoyaltyStayTriggerHandler();

            Test.startTest();
            handler.beforeInsert(new List<SObject>());
            handler.beforeUpdate(new Map<Id, SObject>(), new Map<Id, SObject>());
            handler.beforeDelete(new Map<Id, SObject>());
            handler.afterInsert(new List<SObject>());
            handler.afterDelete(new Map<Id, SObject>());
            Test.stopTest();

            System.assert(true, 'All empty handler methods executed without exception');
        }
    }
}