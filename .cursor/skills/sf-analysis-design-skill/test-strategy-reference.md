# Test Strategy Reference

## Test Architecture

Every Apex test suite should follow this structure:

| Component | Purpose |
|---|---|
| `TestDataFactory` class | Central factory for creating test records; shared across all test classes |
| `@TestSetup` method | Runs once per test class; creates shared records via TestDataFactory |
| Unit test methods | Test one behavior each; follow the Arrange-Act-Assert pattern |
| Mock classes | Simulate callouts (HttpCalloutMock, WebServiceMock) |

---

## TestDataFactory Pattern

```apex
@isTest
public class TestDataFactory {
    public static LoyaltyProgram createLoyaltyProgram(Boolean doInsert) {
        LoyaltyProgram lp = new LoyaltyProgram(
            Name = 'Test Bonvoy Program',
            Program_Code__c = 'TEST001',
            Status = 'Active'
        );
        if (doInsert) insert lp;
        return lp;
    }

    public static List<LoyaltyProgramMember> createMembers(
        Id programId, Integer count, Boolean doInsert
    ) {
        List<LoyaltyProgramMember> members = new List<LoyaltyProgramMember>();
        for (Integer i = 0; i < count; i++) {
            members.add(new LoyaltyProgramMember(
                Name = 'Test Member ' + i,
                LoyaltyProgramId = programId,
                MemberStatus = 'Active'
            ));
        }
        if (doInsert) insert members;
        return members;
    }
}
```

---

## Required Test Scenarios (Non-Negotiable)

| Scenario | What It Tests | Why |
|---|---|---|
| **Bulk (200+ records)** | Governor limit safety | Triggers and handlers must work at batch size 200 |
| **Null / empty input** | Null safety | Collections should not throw NPE on empty or null |
| **Negative / error path** | Error handling | Exception paths and addError() must be exercised |
| **Permission-based** | FLS / CRUD enforcement | `System.runAs(user)` with restricted profile/permission set |
| **Positive / happy path** | Core functionality | Minimum: one end-to-end success scenario |

---

## Bulk Test Pattern

```apex
@isTest
static void testBulkInsert_200Members() {
    LoyaltyProgram lp = TestDataFactory.createLoyaltyProgram(true);
    List<LoyaltyProgramMember> members = TestDataFactory.createMembers(lp.Id, 200, false);

    Test.startTest();
    insert members; // Fires trigger; must stay within governor limits
    Test.stopTest();

    List<LoyaltyProgramMember> inserted = [
        SELECT Id, BonvoyID__c FROM LoyaltyProgramMember WHERE LoyaltyProgramId = :lp.Id
    ];
    System.assertEquals(200, inserted.size(), 'All 200 members should be inserted');
    for (LoyaltyProgramMember m : inserted) {
        System.assertNotEquals(null, m.BonvoyID__c, 'BonvoyID should be populated on insert');
    }
}
```

---

## Callout Mock Pattern

```apex
@isTest
global class LoyaltyCalloutMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"status":"success","transactionId":"TXN-001"}');
        res.setStatusCode(200);
        return res;
    }
}

@isTest
static void testCalloutSuccess() {
    Test.setMock(HttpCalloutMock.class, new LoyaltyCalloutMock());
    Test.startTest();
    LoyaltyIntegrationUtils.processStayAccrual(stayId);
    Test.stopTest();
}
```

---

## Permission-Based Test Pattern

```apex
@isTest
static void testFLSEnforcement_ReadOnlyUser() {
    Profile readOnly = [SELECT Id FROM Profile WHERE Name = 'Read Only' LIMIT 1];
    User testUser = new User(
        Alias = 'tstuser', Email = 'testuser@example.com',
        EmailEncodingKey = 'UTF-8', LastName = 'Test',
        LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
        ProfileId = readOnly.Id, TimeZoneSidKey = 'America/New_York',
        UserName = 'testuser' + System.currentTimeMillis() + '@example.com'
    );
    insert testUser;

    System.runAs(testUser) {
        try {
            LoyaltyJournalActions.createJournal(testData);
            System.assert(false, 'Should have thrown an exception due to insufficient access');
        } catch (SecurityException e) {
            System.assert(e.getMessage().contains('Insufficient'), 'Correct exception type');
        }
    }
}
```

---

## Assertion Quality Standards

| Do | Don't |
|---|---|
| `System.assertEquals(expected, actual, 'Message explaining what failed')` | `System.assert(true)` — coverage padding |
| Assert on field values, record counts, and state changes | Assert only that no exception was thrown |
| Assert negative outcomes (record should NOT exist, field should NOT be set) | Only assert positive outcomes |
| Use `System.assertNotEquals(null, value, 'Field should be populated')` | Ignore null checks |

---

## Test Anti-Patterns (Flag as Warning in Code Review)

- `@isTest(SeeAllData=true)` without documented justification — fragile, environment-dependent
- No `Test.startTest()` / `Test.stopTest()` around async invocations — limits are not reset
- `System.debug` in test assertions — not a substitute for `System.assert`
- Hardcoded IDs (e.g., `Id profileId = '00e...'`) — fails in different orgs
- All test methods share a single monolithic test method — blocks isolating failures
- Test class with only one method testing everything — masks which scenario fails
