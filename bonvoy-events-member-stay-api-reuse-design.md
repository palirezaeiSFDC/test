# Marriott Bonvoy Events - Member Stay API Reuse Assessment

## Purpose

This document evaluates whether Marriott Bonvoy Events processing should leverage the current Member Stay API and whether Events should be modeled as a new object, a new `Loyalty_Stay__c` record type, or as Transaction Journal-only processing.

## Recommendation

Use a dedicated non-stay Transaction Journal API for Bonvoy Events and reuse only the proven patterns from the Member Stay API.

Do not model Bonvoy Events as a new record type of `Loyalty_Stay__c`.

For Q2, keep Events as TransactionJournal-only processing with `JournalType = Accrual` and `JournalSubType = Events`. Create a dedicated Event object only if the business later needs a persistent Event parent lifecycle outside the Transaction Journal.

## Current Member Stay API Fit

The current Member Stay API is stay-centric. It supports:

- `POST /services/apexrest/loyalty/{programName}/earn/sf-stay`
- `PUT /services/apexrest/loyalty/{programName}/earn/sf-stay/{stayId}`
- `PATCH /services/apexrest/loyalty/{programName}/earn/sf-stay/{stayId}`
- `GET /services/apexrest/loyalty/{programName}/earn/sf-stay`

The implementation assumes a stay parent record:

- `MemberStayService` creates one `Loyalty_Stay__c` record per request.
- All submitted TJs are treated as children of one stay.
- `MemberStayValidator` extracts stay-level data from the first TJ.
- Validation includes stay-specific rules such as dates, age, property, rate plan, duplicate stays, overlapping stays, host multiple, back-to-back, and CEC stay behavior.
- Post-processing updates stay totals and stay status, then publishes stay-related events.

Bonvoy Events do not fit those assumptions. Events are non-stay accruals, do not create `Loyalty_Stay__c`, and are driven by event revenue, split handling, cap rules, EQN rules, and purchased bonus points.

## What We Should Reuse

The Events implementation should reuse the design patterns and selected shared utilities from the Member Stay API, not the Stay endpoint itself.

Recommended reuse:

- REST controller pattern with explicit request parsing and response serialization.
- Loyalty program validation from the URI.
- Member lookup and status validation patterns.
- Property lookup by MARSHA/property code.
- Consistent API error response style.
- Savepoint and rollback pattern for controlled transaction boundaries.
- Existing asynchronous post-processing event pattern.
- Existing monthly balance aggregation concepts, adapted to source from `LoyaltyLedger` or Event TJs instead of `Loyalty_Stay__c`.

Recommended not to reuse directly:

- `MemberStayService.createStayTransactions`.
- `MemberStayValidator` stay validation chain.
- `MemberStayMapper` stay parent mapping.
- Stay duplicate and overlap logic.
- Stay status lifecycle.
- Stay post-processing behavior that updates `Loyalty_Stay__c`.
- Property EQN multiplier logic used for stays.

## Object Model Options

### Option 1: TransactionJournal-Only

Use `TransactionJournal` as the primary persisted record for each Event earning transaction.

Each member receives one Event TJ:

- `JournalType = Accrual`
- `JournalSubType = Events`
- `TransactionAmount = qualifying event revenue`
- `TJ_Processing_Directive__c = SINGLE` or `SPLIT`
- `Additional_Details__c` stores serialized event attributes
- `Total_Guest_Rooms__c` supports EQN calculation
- `Points_Multiplier__c` supports double/triple points

This is the recommended Q2 model.

Benefits:

- Matches the existing design decision that Events do not create Stay records.
- Avoids polluting stay history with non-stay activity.
- Keeps stay processing stable for high-volume stay traffic.
- Keeps Events aligned with CLM earning, ledger, and cap processing.
- Supports future non-stay subtypes through the same processor pattern.

Tradeoffs:

- There is no separate parent Event record for grouping split-member TJs.
- Reporting that needs full Event context must read TJ fields and `Additional_Details__c`.
- Adjustments or cancellations may need a clear lookup key such as quote number plus member number.

### Option 2: New Event Object

Create a dedicated custom object, for example `Bonvoy_Event__c`, as a parent to one or more Event TJs.

This should be considered only if CLM needs an Event lifecycle independent of earning TJs.

Use this option if future requirements include:

- Event-level status before earning is posted.
- Parent-child grouping for split members.
- Event cancellation or adjustment workflows independent of individual TJs.
- Event-level audit, approval, ownership, or operational reporting.
- Multiple earning records tied to one quote/event.
- Rich searchable fields that should not live in `Additional_Details__c`.

Benefits:

- Clean domain model for Events.
- Stronger reporting and audit model.
- Easier split-member grouping.
- Clear future path for Event adjustments and reconciliation.

Tradeoffs:

- More custom object ownership and lifecycle logic.
- More triggers, validation, sharing, tests, and monitoring.
- Additional joins between Event, TJ, Ledger, and member balance.
- More scope than Q2 needs if Events are only submitted after eligibility is finalized by TIP.

### Option 3: New Record Type on `Loyalty_Stay__c`

Create an Event record type on `Loyalty_Stay__c` and store Bonvoy Events as stay-like records.

This is not recommended.

Reasons:

- Events are not stays and should not appear in stay history as stay records.
- Existing stay services assume reservation, folio, check-in, checkout, visit type, rate plan, stay status, and property stay behavior.
- Stay validations such as duplicate/overlap, host multiple, back-to-back, CEC stay rules, and stay age rules do not apply to Events.
- Existing stay post-processing updates `Loyalty_Stay__c` totals and applies stay-only behavior that Events must skip.
- Record-type branching would spread Events conditions across stay validators, mappers, post-processing, reports, and triggers.
- The Stay API is high-volume and should not take regression risk from lower-volume non-stay transaction logic.

## Proposed Events API Model

Use a dedicated endpoint:

```http
POST /services/apexrest/loyalty/{programName}/lyt/sf-transaction-journals
```

Recommended responsibilities:

- `TJBatchApiController`: REST entry point, program validation, request parsing, response writing, transaction boundary.
- `TJBatchRequest`: typed payload wrapper.
- `TJBatchResponse`: stable response shape for TIP.
- `ITJSubTypeProcessor`: processor contract.
- `TJProcessorFactory`: subtype router.
- `EventsTJProcessor`: Event-specific cap, split, multiplier, EQN, and post-processing behavior.

Important transaction behavior:

- For single-member Events, process one Event TJ.
- For split Events, TIP submits two Event TJs.
- The request should be all-or-none for split Events.
- If either member fails validation or the 200k total cap, roll back the full request.

## Processing Model

For Events, CLM should:

1. Validate request structure and required Event fields.
2. Validate loyalty program, member, property, and earning preference.
3. Create Event TJ in `Pending` status.
4. Apply Event earning rules.
5. Apply split allocation when `TJ_Processing_Directive__c = SPLIT`.
6. Apply base points cap.
7. Apply double/triple points multiplier.
8. Calculate elite bonus on capped base points.
9. Add purchased bonus points from `Quantity` when `Quantity_Unit__c = Points`.
10. Reject and roll back if total points exceed 200,000.
11. Calculate EQN from `Total_Guest_Rooms__c` and `ActivityDate`.
12. Post through Loyalty Process and update status.
13. Publish non-stay post-processing event.

## Post-Processing Recommendation

Reuse the asynchronous processor event pattern, but route Events separately from stays.

Recommended event fields:

- `Activity_Type__c`: `Stay`, `Events`, or future `EBonus`.
- `Stay_Id__c`: populated for Stay only.
- `Transaction_Journal_Id__c`: populated for Events.
- `Membership_Number__c`: populated using the existing event convention.

Routing:

- `Activity_Type__c = Stay` routes to `StayPostProcessingService.processStayEvents`.
- `Activity_Type__c = Events` routes to `NonStayPostProcessingService.processEvents`.

Events post-processing should source final awarded values from `LoyaltyLedger` where possible because the ledger reflects caps, multiplier, elite bonus, purchased points, and final posted outcome.

Events post-processing must skip:

- `Loyalty_Stay__c` updates.
- Stay status updates.
- Stay total aggregation.
- Property EQN multiplier logic.
- Loyalty stay event publishing.

## Decision Summary

| Decision | Recommendation |
| --- | --- |
| Reuse current Member Stay API endpoint | No |
| Reuse current Member Stay API patterns/utilities | Yes |
| Create Event as `Loyalty_Stay__c` record type | No |
| Create new Event object for Q2 | No, unless an Event parent lifecycle is required |
| Use TransactionJournal-only Events model | Yes |
| Use separate non-stay TJ endpoint | Yes |
| Route post-processing through stay service | No |
| Reuse async post-processing pattern with activity routing | Yes |

## Final Answer

It does not make sense to make Bonvoy Events a record type of `Loyalty_Stay__c`. The object name, validation rules, post-processing behavior, and reporting semantics are all stay-specific.

For Q2, the cleanest model is TransactionJournal-only with `JournalSubType = Events`. If Events later need a parent lifecycle, create a dedicated Event object rather than extending `Loyalty_Stay__c`.

