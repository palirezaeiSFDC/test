flowchart TD
    Start(["Process Start"]) --> Rule1["Rule 1: Calculate Event Member Earnings (per Event TJ)"]

    Rule1 --> R1Gate{"JournalType=Accrual AND JournalSubType=Event AND Loyalty_Event_Id__c != null?"}
    R1Gate -->|No| EndSkip(["Skip Processing"])
    R1Gate -->|Yes| A1["Action 1: Resolve runtime parameters<br/>EVENT_BASE_POINTS_PER_DOLLAR, EVENT_BASE_POINTS_CAP_SINGLE,<br/>EVENT_TOTAL_POINTS_CAP, EVENT_EQN_CAP, EVENT_EQN_ROOM_RATIO"]

    A1 --> A2["Action 2: Resolve Event parent context<br/>EventTotalGuestRooms, EventEarningsIsSplit"]
    A2 --> A3["Action 3: Resolve and set BasePointsMultiplierValue = 1 / 2 / 3"]

    A3 --> A4["Action 4: Resolve tier context<br/>LoyaltyMemberTierRecord, TierBonusEarnPercentage"]
    A4 --> A5["Action 5: Calculate base raw<br/>CalculatedBasePointsRaw = TransactionAmount * EVENT_BASE_POINTS_PER_DOLLAR"]
    A5 --> BaseCap{"CalculatedBasePointsRaw > EVENT_BASE_POINTS_CAP_SINGLE?"}

    BaseCap -->|Yes| A6["Action 6: CalculatedBasePoints = EVENT_BASE_POINTS_CAP_SINGLE"]
    BaseCap -->|No| A7["Action 7: CalculatedBasePoints = CalculatedBasePointsRaw"]
    A6 --> A6b["Action 6b: Set cap warning<br/>Reward is over max allowed, so max will be awarded."]
    A6b --> A8
    A7 --> A8["Action 8: CalculatedEliteBonusPoints = ROUND((CalculatedBasePoints * TierBonusEarnPercentage)/100, 0)"]

    A8 --> A10["Action 9: ExtraPointsToAward = Quantity (default 0)"]
    A10 --> A11["Action 10: TotalPointsToCredit = (CalculatedBasePoints * BasePointsMultiplierValue) + CalculatedEliteBonusPoints + ExtraPointsToAward"]
    A11 --> TotalCap{"TotalPointsToCredit > EVENT_TOTAL_POINTS_CAP?"}

    TotalCap -->|Yes| Rj2["Hard-failure output:<br/>ValidationFailed=true, validationCode, validationMessage,<br/>OverageAmount=TotalPointsToCredit - EVENT_TOTAL_POINTS_CAP"]
    TotalCap -->|No| A12["Action 11: Calculate EQS (typically TransactionAmount;<br/>apply Ambassador exclusion if applicable)"]

    A12 --> A13["Action 12: RawEQN = EventTotalGuestRooms / EVENT_EQN_ROOM_RATIO"]
    A13 --> A14["Action 13: RoundedRawEQN (standard rounding)"]
    A14 --> Split{"EventEarningsIsSplit = true?"}

    Split -->|Yes| A15["Action 14: FinalEQNToCredit = MIN(RoundedRawEQN, EVENT_EQN_CAP / 2)"]
    Split -->|No| A16["Action 15: FinalEQNToCredit = MIN(RoundedRawEQN, EVENT_EQN_CAP)"]
    A15 --> A16b{"EQN cap reached?"}
    A16 --> A16b
    A16b -->|Yes| A16c["Action 16: Append EQN cap warning to Notes output"]
    A16b -->|No| A17["Action 17: Return wrapper output<br/>isSuccess, validationFailed, validationCode,<br/>validationMessage, warningMessage, transactionJournalId"]
    A16c --> A17

    Rule2["Rule 2: Credit Member and Update TJ (only if Rule 1 passed)"]
    A17 --> Rule2
    Rule2 --> R2Gate{"validationFailed = true?"}
    R2Gate -->|Yes| Rule3
    R2Gate -->|No| A18["Action 18: Credit Points = TotalPointsToCredit"]
    A18 --> A19["Action 19: Credit EQN = FinalEQNToCredit"]
    A19 --> A20["Action 20: Credit EQS = CalculatedEQS"]
    A20 --> A21["Action 21: Update TJ fields<br/>Base_Points__c, Elite_Bonus_Points__c, Extra_Points__c, Notes__c, status/outcome"]
    A21 --> Rule3

    Rule3["Rule 3: API all-or-none transaction boundary in Apex"]
    Rj2 --> Rule3
    Rule3 --> AnyFail{"Any TJ returned validationFailed=true?"}
    AnyFail -->|Yes| Rollback["Rollback savepoint<br/>Event parent + all Event TJs + in-transaction side effects"]
    AnyFail -->|No| Commit["Commit transaction"]

    Rollback --> EndErr(["Return controlled error response"])
    Commit --> Rule4["Rule 4: Post-commit async post-processing"]

    Rule4 --> A22["Action 22: Publish processor event per committed TJ/member"]
    A22 --> A23["Action 23: Route Event_Id__c path to NonStayPostProcessingService.processEvents"]
    A23 --> A24["Action 24: Read processed TJ + LoyaltyLedger final awarded values"]
    A24 --> A25["Action 25: Update Member_Monthly_Balance by member + activity period"]
    A25 --> A26["Action 26: Upsert parent member outcomes (Primary_Member_*, Secondary_Member_*)"]
    A26 --> A27["Action 27: Recompute parent aggregates from persisted TJ/Ledger data"]
    A27 --> A28["Action 28: Publish tier assessment per qualifying member (Operation_Type__c='Event')"]
    A28 --> A29["Action 29: Apply idempotency key (member + period + source TJ)"]
    A29 --> A30["Action 30: Skip stay-only behavior paths"]
    A30 --> EndOk(["Return success response"])

    classDef conditionStyle fill:#ffb3ba,stroke:#ff8c94,stroke-width:1.5px,color:#8b0000
    classDef actionStyle fill:#ffd4a3,stroke:#ffb366,stroke-width:1.5px,color:#8b4513
    classDef startEndStyle fill:#fff4a3,stroke:#ffd700,stroke-width:1.5px,color:#8b6914
    classDef ruleStyle fill:#b3d9ff,stroke:#66b3ff,stroke-width:2px,color:#003366
    classDef rejectStyle fill:#ff9aa2,stroke:#d62839,stroke-width:2px,color:#5c0000
    classDef asyncStyle fill:#d9f7be,stroke:#52c41a,stroke-width:2px,color:#135200

    class R1Gate,BaseCap,TotalCap,Split,A16b,R2Gate,AnyFail conditionStyle
    class A1,A2,A3,A4,A5,A6,A6b,A7,A8,A10,A11,A12,A13,A14,A15,A16,A16c,A17,A18,A19,A20,A21 actionStyle
    class A22,A23,A24,A25,A26,A27,A28,A29,A30 asyncStyle
    class Start,EndSkip,EndErr,EndOk startEndStyle
    class Rule1,Rule2,Rule3,Rule4 ruleStyle
    class Rj2,Rollback rejectStyle
