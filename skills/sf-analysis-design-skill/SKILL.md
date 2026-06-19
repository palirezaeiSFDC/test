---
name: sf-analysis-design-skill
description: Analyzes Salesforce solutions, reviews Apex/LWC code for best practices and governor limits, and suggests metadata design changes for given problems. Use when working with Salesforce, Apex, Lightning Web Components, metadata, triggers, flows, or when the user asks for Salesforce analysis, design, or architecture review.
---

# Salesforce Analysis & Design

## Quick Start

Apply this skill when the user mentions: Salesforce, Apex, LWC, metadata, triggers, flows, data model, integration, governor limits, or solution design.

**Decision tree:**
- **Solution design** → Architecture, data model, integration patterns → use sections below
- **Code analysis** → Apex/LWC review, best practices, governor limits → use sections below
- **Flow review** → Load [flow-analysis-reference.md](flow-analysis-reference.md) for full checklist
- **Test strategy** → Load [test-strategy-reference.md](test-strategy-reference.md) for patterns and templates
- **WAF review / output templates** → Load [well-architected-reference.md](well-architected-reference.md)
- **Impact assessment** → Load [impact-assessment-reference.md](impact-assessment-reference.md)
- **Apex design patterns** (trigger framework, service/selector) → Load [impact-assessment-reference.md](impact-assessment-reference.md)

---

## Solution Design

### Architecture Patterns

- **Record-triggered flows vs triggers**: Prefer flows for declarative logic; use Apex when flows cannot meet requirements (complex logic, callouts, platform events).
- **Async vs sync**: Use `@future`, Queueable, or Batch for callouts, heavy processing, or operations that exceed sync limits.
- **One trigger per object**: Use a single trigger that delegates to a handler class.

### Data Model

- Normalize where reuse matters; denormalize for reporting or performance.
- Prefer standard objects when they fit; use custom objects for domain-specific entities.
- Consider relationship types: lookup vs master-detail (cascade delete, sharing).

### Integration

- REST for external systems; Platform Events for decoupled, event-driven flows.
- Use callouts for outbound; consider limits (100 callouts per transaction).
- For LDV, async, and integration pattern depth → load `.cursor/skills/sf-integration-patterns-skill/SKILL.md`.

---

## Code Analysis

For mechanical code review criteria (bulkification, SOQL/DML in loops, FLS/CRUD enforcement, naming conventions, test class patterns, LWC patterns, governor limit hotspots), use **sf-review-agent**'s built-in checklist.

This skill covers **architecture patterns and design decisions** — not line-by-line mechanical review.

For performance patterns, async pattern selection, and LDV optimization, load `.cursor/skills/sf-integration-patterns-skill/SKILL.md`.

---

## Metadata Design

- **New object vs fields**: New object when entity is distinct; extend standard/custom object when attributes belong to existing entity.
- **Validation rules vs triggers vs flows**: Validation rules for declarative field rules; flows for multi-step logic; triggers for complex or callout-dependent logic.
- **Flow vs Apex**: Flow for admins, simpler logic, no code; Apex for complex logic, callouts, platform events.
- **Flow review** → load [flow-analysis-reference.md](flow-analysis-reference.md) for bulkification risk, checklist, and convert-to-Apex criteria.

Before generating metadata files, use `Salesforce DX` code-analysis tools (`scan_apex_class_for_antipatterns`, `run_code_analyzer`, `describe_code_analyzer_rule`) or `WebFetch` from the [Metadata API Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_intro.htm) to ensure correct structure.

---

## Reference Files

Load these on demand — do not load all at once unless the task explicitly requires all sections:

| File | Load when |
|---|---|
| [flow-analysis-reference.md](flow-analysis-reference.md) | Reviewing flows, assessing bulkification risk, fault paths, flow-to-Apex conversion |
| [test-strategy-reference.md](test-strategy-reference.md) | Reviewing test classes, writing test strategy, identifying anti-patterns |
| [well-architected-reference.md](well-architected-reference.md) | WAF pillar review, producing output with review templates, design recommendations |
| [impact-assessment-reference.md](impact-assessment-reference.md) | Impact assessment, Apex design patterns (trigger framework, service/selector), MCP routing |
| [reference.md](reference.md) | Governor limits table, security review checklist |
| [examples.md](examples.md) | Before/after code examples |

---

## Additional Resources

- For LDV and integration patterns, see `.cursor/skills/sf-integration-patterns-skill/SKILL.md`
- For workflow orchestration templates, see `.cursor/skills/sf-workflow-templates-skill/SKILL.md`
- For shared MCP routing, error handling, and documentation URLs, see `.cursor/skills/sf-shared-reference/SKILL.md`
