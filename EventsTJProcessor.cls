/*******************************************************************************************
 * @Name         EventsTJProcessor.cls
 * @Author       Salesforce
 * @Date         04/30/2026
 * @Group        SF-Implementation
 * @Description  ITJSubTypeProcessor implementation for JournalSubType = Events.
 *               Handles Marriott Bonvoy Events earning rules:
 *                 - Base points: 2 pts per $1, max 60,000 per member per event
 *                 - Double/Triple points (DBPT/TRPT) applied on capped base
 *                 - Elite bonus: applied on capped base (not on promoted amount)
 *                 - Purchase bonus: property-submitted bonus points (TJ.Quantity)
 *                 - 200,000 total points cap – hard reject (TJ rolled back by controller)
 *                 - EQN: 1 per 20 actualized rooms, max 10 per member, year = EndDate year
 *                 - Event spend excluded from Ambassador Elite $20k requirement
 *
 *               Called by TJBatchApiController after TJ is created in Pending status.
 *******************************************************************************************/
/* MODIFICATION LOG
 * Version          Developer          Date               Description
 *-------------------------------------------------------------------------------------------
 *  1.0             Pegah.Alirezaei    04/30/2026         Initial Creation - LYLT-363
 *******************************************************************************************/
public with sharing class EventsTJProcessor implements ITJSubTypeProcessor {

    private static final Decimal BASE_RATE              = 2;
    private static final Decimal BASE_CAP               = 60000;   // per member, no split
    private static final Decimal BASE_CAP_SPLIT         = 30000;   // per member, split (60k ÷ 2)
    private static final Decimal TOTAL_CAP              = 200000;
    private static final Integer EQN_ROOMS_DIVISOR      = 20;
    private static final Integer EQN_CAP_SINGLE         = 20;      // max EQN, no split
    private static final Integer EQN_CAP_SPLIT          = 10;      // max EQN per member, split
    private static final Decimal SPLIT_DIVISOR          = 2;
    private static final Integer DEFAULT_MULTIPLIER     = 1;       // no promotion

    private static final String WARN_BASE_CAP_APPLIED =
        'Reward is over max allowed, so max will be awarded.';
    private static final String ERR_TOTAL_CAP_EXCEEDED =
        'You must correct the following error(s) before proceeding: ' +
        'Earned Points plus Purchased Points cannot exceed 200,000 points, ' +
        'please adjust Purchased Point Value.';

    // ──────────────────────────────────────────────────────────────────────────
    // ITJSubTypeProcessor implementation
    // ──────────────────────────────────────────────────────────────────────────

    public TJBatchResponse.TJResult process(Id tjId, TJBatchRequest.TJInput input) {

        Boolean isSplit      = (input.isSplit == true);
        Decimal effectiveCap = isSplit ? BASE_CAP_SPLIT : BASE_CAP;   // 30k or 60k

        // ── 1. Base points ────────────────────────────────────────────────────
        // Both TJs carry the full qualifying revenue; when isSplit = true CLM
        // halves the raw base before applying the per-member cap.
        Decimal rawBase    = (input.TransactionAmount ?? 0) * BASE_RATE;
        Decimal memberBase = isSplit ? rawBase / SPLIT_DIVISOR : rawBase;
        Boolean capApplied = memberBase > effectiveCap;
        if (capApplied) {
            memberBase = effectiveCap;
        }

        // ── 2. Points multiplier (DBPT = 2, TRPT = 3, none = 1) ──────────────
        // Applied on capped base. Uses the numeric pointsMultiplier field directly;
        // falls back to DEFAULT_MULTIPLIER (1) when absent.
        Integer multiplier  = input.Additional_Details__c?.pointsMultiplier ?? DEFAULT_MULTIPLIER;
        Decimal promotedPts = memberBase * multiplier;

        // ── 3. Elite bonus (on capped base, NOT on promoted amount) ──────────
        Decimal eliteBonus = getEliteBonusPoints(input.MemberId, memberBase);

        // ── 4. Purchase bonus ─────────────────────────────────────────────────
        Decimal purchaseBonus = input.Quantity ?? 0;

        // ── 5. 200k total cap validation ──────────────────────────────────────
        Decimal totalPts = promotedPts + eliteBonus + purchaseBonus;
        if (totalPts > TOTAL_CAP) {
            Decimal overage = totalPts - TOTAL_CAP;
            return new TJBatchResponse.TJResult(
                ERR_TOTAL_CAP_EXCEEDED + ' Overage: ' + overage.intValue()
            );
            // TJBatchApiController rolls back the TJ record when result.Status = Error
        }

        // ── 6. EQN calculation ────────────────────────────────────────────────
        Integer rooms    = Integer.valueOf(input.FlightNumber ?? 0);
        Integer totalEqn = (Integer) Math.floor(rooms / EQN_ROOMS_DIVISOR);
        Integer memberEqn;
        Integer eqnCap;
        if (isSplit) {
            // Each TJ receives its rounded half of the total EQN
            memberEqn = roundHalf(totalEqn);
            eqnCap    = EQN_CAP_SPLIT;    // 10 per member
        } else {
            memberEqn = totalEqn;
            eqnCap    = EQN_CAP_SINGLE;   // 20 per member (single)
        }
        memberEqn = Math.min(memberEqn, eqnCap);

        // ── 7. Post earnings via Loyalty Process ──────────────────────────────
        // EQN year = year of ActivityDate (agreed with TIP — not EndDate)
        triggerLoyaltyProcess(tjId, input, totalPts, memberEqn);

        // ── 8. Update TJ to Processed ─────────────────────────────────────────
        updateTJStatus(tjId, STATUS_PROCESSED);

        // ── 9. Build result (include cap warning when base was capped) ─────────
        TransactionJournal created = [SELECT Id, Name FROM TransactionJournal WHERE Id = :tjId LIMIT 1];
        String warning = capApplied ? WARN_BASE_CAP_APPLIED : null;
        return new TJBatchResponse.TJResult(created.Id, created.Name, warning);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Loyalty Process trigger
    // Replace with actual ConnectApi / Process Builder / Flow invocation
    // ──────────────────────────────────────────────────────────────────────────

    @TestVisible
    private void triggerLoyaltyProcess(
        Id                      tjId,
        TJBatchRequest.TJInput  input,
        Decimal                 totalPts,
        Integer                 memberEqn
    ) {
        // TODO: invoke the Events Loyalty Process
        // e.g. ConnectApi.LoyaltyManagement.processTransaction(programName, tjId, processContext);
        // EQN year = year of input.ActivityDate  (agreed with TIP — not EndDate)
        // Event spend must NOT increment Elite Qualifying Spend (Ambassador Elite exclusion)
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Elite bonus lookup
    // Returns elite bonus points based on member tier configured in CLM
    // ──────────────────────────────────────────────────────────────────────────

    @TestVisible
    private Decimal getEliteBonusPoints(String memberId, Decimal memberBase) {
        // TODO: query member tier and return memberBase × elite bonus %
        // e.g. Basic = 0%, Silver = 10%, Gold = 25%, Platinum = 50%, Titanium = 75%
        return 0;
    }

    // ──────────────────────────────────────────────────────────────────────────
    // EQN rounding for 50/50 split – applied per independent TJ.
    // Policy examples (total → each member):
    //   1 EQN total (0.5 each) → round(0.5) = 1 → each member gets 1
    //   2 EQN total (1.0 each) → round(1.0) = 1 → each member gets 1
    //   3 EQN total (1.5 each) → round(1.5) = 2 → each member gets 2
    // Apex Math.round() uses HALF_UP (rounds 0.5 up) – matches policy.
    // ──────────────────────────────────────────────────────────────────────────

    @TestVisible
    private Integer roundHalf(Integer total) {
        Decimal half = Decimal.valueOf(total) / SPLIT_DIVISOR;
        return (Integer) half.round(System.RoundingMode.HALF_UP);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // TJ status update
    // ──────────────────────────────────────────────────────────────────────────

    private void updateTJStatus(Id tjId, String status) {
        update new TransactionJournal(Id = tjId, Status = status); // NOPMD
    }

    private static final String STATUS_PROCESSED = TJBatchApiController.STATUS_PROCESSED;
}
