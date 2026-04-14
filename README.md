# Approval Workflow Rules Engine

**Package:** `ZWORKFLOW`
**Environment:** BTP ABAP Cloud (SAP BTP, ABAP environment)
**Stability:** Early-stage MVP — works end-to-end, still rough around some edges (see [Open items](#open-items))

For a phase-by-phase build history and gotchas, see [`local-reference/CHANGELOG-rules-engine.md`](local-reference/CHANGELOG-rules-engine.md). For a complete object inventory, see [`local-reference/INVENTORY.md`](local-reference/INVENTORY.md).

---

## 1. Purpose

`ZWORKFLOW` provides a **generic, configurable approval workflow** with a **condition-aware routing engine**. A consumer business object (e.g. a procurement plan, a purchase order) submits a request for approval; the engine decides **who should approve it** based on the object's type, level, and runtime context, then persists an approval instance through a state machine that supports submit / approve / reject / withdraw / resubmit and multi-level escalation.

It is deliberately agnostic about the consumer BO. The rule engine never imports consumer-specific types. It takes a generic `{field_name, field_value}` context map and returns `{agent_type, agent_id}`. Integration is via data (the consumer writes context rows tied to an approval instance) rather than via code.

### What you get
- A configuration UI for admins to define object types, routing rules, and conditions
- A runtime UI for approvers to see pending requests and act on them
- A pure ABAP API (`ZCL_APPR_RULE_ENGINE=>determine_agent`) you can call from anywhere
- A state machine baked into the Instance BO that handles level escalation
- End-to-end draft support, Fiori Elements rendering, and value helps wired to live tenant data

### What you don't get (scope boundaries)
- No workflow tasks / inbox integration (the "Assigned Agent" is just a string; no push notifications or task-list integration)
- No delegation / substitution (out, for now)
- No deadline management or SLA tracking
- No parallel approvals — the engine resolves ONE agent per level
- No conditional expressions beyond single-field comparisons (no "A AND B OR C")

---

## 2. Architectural overview

```
┌───────────────────────────────────────────────────────────────────-------──┐
│                      CONFIGURATION (admin-time)                            │
│                                                                            │
│  ZR_APPR_OBJ_TYPE  ──composition──▶  ZR_APPR_RULE                          │
│  (e.g. PROC_PLAN)                    (priority + agent binding)            │
│                                       │                                    │
│                                       └──composition──▶  ZR_APPR_CONDITION │
│                                                          (field/op/value)  │
└───────────────────────────────────────────────────────────────────-------──┘
                                   ▲
                                   │ reads at submit time
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                       ENGINE (pure ABAP class)                      │
│                                                                     │
│  zcl_appr_rule_engine=>determine_agent(                             │
│     iv_object_type, iv_level, it_context                            │
│  ) → { agent_type, agent_id }                                       │
│                                                                     │
│  Evaluates rules in priority order, matching the context against    │
│  each rule's conditions. First match wins. Raises                   │
│  ZCX_APPR_NO_RULE_FOUND if nothing matches.                         │
└─────────────────────────────────────────────────────────────────────┘
                                   ▲
                                   │ called on submit
                                   │
┌─────────────────────────────────────────────────────────────────────┐
│                       RUNTIME (user-time)                           │
│                                                                     │
│  ZR_APPR_INSTANCE  ──composition──▶  ZR_APPR_STEP (audit trail)     │
│                    └─composition──▶  ZR_APPR_INSTANCE_CTX           │
│                                      (the routing context)          │
│                                                                     │
│  State: DR → SB → (AP | RJ | WD) → (resubmit loops back to SB)      │
└─────────────────────────────────────────────────────────────────────┘
```

The three layers are decoupled:
- **Config layer** writes data admins rarely change
- **Engine** is stateless, pure functional
- **Runtime layer** holds per-request state and delegates routing decisions to the engine

---

## 3. Data model

### Configuration tables

| Table | Purpose |
|---|---|
| `ZAPPR_OBJ_TYPE` | Catalog of object types (`PROC_PLAN`, `PO`, `CONTRACT`, `CAPEX`, ...). Each has a code, name, description, and `is_active` flag |
| `ZAPPR_RULE` | Routing rules per object type. Key: `rule_id` (UUID). Fields: `object_type`, `rule_description`, `approver_level`, `priority`, `agent_type`, `agent_id`, `is_active` |
| `ZAPPR_CONDITION` | Conditions attached to a rule. Key: `condition_uuid` (UUID). Fields: `rule_uuid` (FK to `zappr_rule.rule_id`), `object_type` (denormalized for lock chain), `field_name`, `operator`, `value_low`, `value_high` |
| `ZAPPR_AGENT_TYPE` | Enumerated catalog for the `agent_type` value help. Two rows: `USER`, `ROLE` |

### Runtime tables

| Table | Purpose |
|---|---|
| `ZAPPR_INSTANCE` | One row per approval request. Tracks object reference, current status, current agent, audit columns |
| `ZAPPR_STEP` | Audit trail — one row per transition (submit, approve, reject, withdraw) |
| `ZAPPR_INST_CTX` | **The integration seam.** Key-value rows carrying the routing context for a specific approval instance. Consumer BOs write these when creating an instance |

### Draft tables (managed RAP)

Every active table has a matching `ZAPPR_D_*` draft table. They mirror the active shape plus the RAP `%admin` include. The `ZAPPR_INST_CTX` draft is `ZAPPR_D_CTX` (shortened — 16-char cloud table name limit).

### Important column notes

- **`ZAPPR_RULE.agent_type`** is `char(4)` — holds `USER` or `ROLE` (or whatever you add)
- **`ZAPPR_RULE.agent_id`** is `char(40)` — holds either a user technical ID (up to 12 chars in practice) or a business role ID
- **`ZAPPR_RULE.priority`** is `int4` — lower numbers win (priority 10 beats priority 99)
- **`ZAPPR_CONDITION.object_type`** is intentionally denormalized. RAP managed BO lock-master chains require a **direct association** from a child entity to the lock master; the parent chain (Condition → Rule → ObjectType) is not enough. Storing `object_type` on the condition lets the BDEF declare `lock dependent by _ObjectType` with a direct target
- **`ZAPPR_INSTANCE.approver_role`** is repurposed — it started life as a role name string, but now holds the rule engine's resolved `agent_id` (user ID or role name). The DDLX labels it "Assigned Agent" to reduce confusion. A clean rename to a proper `agent_id` column is a known piece of future work

### Key relationships

```
ZR_APPR_OBJ_TYPE (root, lock master)
  └── composition → ZR_APPR_RULE
                      └── composition → ZR_APPR_CONDITION
                                          └── association _ObjectType → ZR_APPR_OBJ_TYPE (direct, for lock/auth chain)

ZR_APPR_INSTANCE (root, separate lock master)
  ├── composition → ZR_APPR_STEP
  └── composition → ZR_APPR_INSTANCE_CTX
```

Two separate root BOs: the **config BO** (Object Type) and the **runtime BO** (Instance). They share no composition relationship. An Instance references an Object Type only by string (`object_type` column), not by BO association.

---

## 4. CDS view layer

### Naming convention
- `ZR_*` — interface (root) view entities, one per persistent table. Managed RAP BOs use these
- `ZC_*` — consumption projections over the interface views. Fiori Elements apps use these
- `ZI_*` — value help views
- `ZA_*` — abstract entities (action parameters)

### Value help views

| View | Source | Used by |
|---|---|---|
| `ZI_APPR_OBJ_TYPE_VH` | `zappr_obj_type` (filtered `is_active = 'X'`) | `ZC_APPR_INSTANCE.object_type` |
| `ZI_APPR_AGENT_TYPE_VH` | `zappr_agent_type` | `ZC_APPR_RULE.agent_type` |
| `ZI_APPR_ROLE_VH` | `I_IAMBusinessRole` + `I_IAMBusinessRoleText` join | As a source for the merged Agent VH |
| `ZI_APPR_AGENT_VH` | `UNION ALL` of `I_BusinessUserVH` and `ZI_APPR_ROLE_VH` | `ZC_APPR_RULE.agent_id` — single VH that offers both kinds |

The merged `ZI_APPR_AGENT_VH` is critical: Fiori Elements V4 does not reliably handle multiple `@Consumption.valueHelpDefinition` entries on a single field. UNION-merging both sources into one logical VH, with a tagged `agent_type` column, sidesteps the framework limitation. When a user picks any row, `agent_type` and `agent_id` are both populated via `additionalBinding`.

### Business role source
`I_IAMBusinessRole` is an SAP-released CDS view in package `SR_APS_IAM_VDM_BROLE`. Its ABAP language version tag says "standard" rather than "cloudDevelopment", but it IS consumable from Z cloud views — confirmed by activation. Don't let the tag fool you. This view lets us read **live tenant business roles** without caching, and without calling the contract-restricted `CL_IAM_BUSINESS_ROLE_FACTORY` API.

### Agent name text binding
`ZC_APPR_RULE.agent_id` has `@ObjectModel.text.element: ['user_name']` where `user_name` is a path expression `_User.PersonFullName`. Fiori renders user IDs as `CB9980000062 (busisiwe sibanyoni)`. ROLE agents have no text (null from the `_User` path) and render as plain IDs. A proper fix for ROLEs is a virtual element with a calculator class — not built yet.

---

## 5. Behavior definitions

Two managed RAP BOs, both draft-enabled:

### `ZR_APPR_OBJ_TYPE` BO
- Entities: `ObjectType`, `ApprovalRule`, `Condition`
- Lock master: `ZR_APPR_OBJ_TYPE`. Rule and Condition are `lock dependent by _ObjectType`
- Rule has `association _Condition { create; with draft; }` — conditions are created via composition
- Rule entity in the projection BDEF has `use update; use delete;` — rules are editable in the Fiori app, and the `@ObjectModel.representativeKey: 'rule_id'` annotation on the projection enables display-mode row-click navigation to the rule object page
- No behavior pool code — this BO is pure managed

### `ZR_APPR_INSTANCE` BO
- Entities: `ApprovalInstance`, `ApprovalStep`, `ApprovalContext`
- Lock master: `ZR_APPR_INSTANCE`. Step and Context are `lock dependent by _Instance`
- Instance has five custom actions: `submit`, `approve`, `reject`, `withdraw`, `resubmit`
- `validateObjectReference` runs on save to enforce `object_type` and `object_key` are set
- `setDefaults` determination fills `current_status = 'DR'`, `requested_by`, `requested_at` on create
- `generateApprovalNumber` determination generates `APR-YYYYMMDD-NNNN` on create
- Behavior pool **has** local class `lhc_ApprovalInstance` with handler code for all custom actions

The Instance BO's local class (`ZBP_R_APPR_INSTANCE` → CCIMP include) is the only place in the package that writes non-trivial ABAP handler code.

---

## 6. The rule engine

### Class: `ZCL_APPR_RULE_ENGINE`

```abap
TYPES: BEGIN OF ty_context_field,
         field_name  TYPE c LENGTH 30,
         field_value TYPE c LENGTH 100,
       END OF ty_context_field,
       ty_context TYPE SORTED TABLE OF ty_context_field
                  WITH UNIQUE KEY field_name.

TYPES: BEGIN OF ty_agent_result,
         agent_type  TYPE c LENGTH 4,
         agent_id    TYPE c LENGTH 40,
         rule_id     TYPE sysuuid_x16,
         description TYPE c LENGTH 80,
       END OF ty_agent_result.

CLASS-METHODS determine_agent
  IMPORTING iv_object_type   TYPE c
            iv_level         TYPE i
            it_context       TYPE ty_context
  RETURNING VALUE(rs_result) TYPE ty_agent_result
  RAISING   zcx_appr_no_rule_found.
```

### Algorithm

1. `SELECT rule_id, priority, agent_type, agent_id, rule_description FROM zappr_rule WHERE object_type = @iv_object_type AND approver_level = @iv_level AND is_active = @abap_true ORDER BY priority`
2. If no rules found → raise `ZCX_APPR_NO_RULE_FOUND`
3. For each rule in priority order:
   - Call `evaluate_conditions(rule_id, context)`
   - If it returns `abap_true`, return that rule as the result
4. If no rule's conditions match → raise `ZCX_APPR_NO_RULE_FOUND`

### Condition evaluation

`evaluate_conditions(rule_id, context)`:

1. `SELECT field_name, operator, value_low, value_high FROM zappr_condition WHERE rule_uuid = @iv_rule_id`
2. If the rule has **zero conditions** → return `true` (catch-all rule, always matches)
3. For each condition:
   - Look up `field_name` in the context table (sorted table with unique key, O(log n))
   - If the field is **not in the context** → return `false` (strict — missing context fails)
   - Call `compare(operator, context_value, value_low, value_high)`
   - If `compare` returns `false` → return `false` (all conditions must match — AND semantics)
4. All conditions matched → return `true`

### Operators

| Code | Meaning | Numeric behaviour | String behaviour |
|---|---|---|---|
| `EQ` | Equal | `ctx = low` | case-insensitive string equality |
| `NE` | Not equal | `ctx ≠ low` | case-insensitive inequality |
| `GT` | Greater than | `ctx > low` | string path not supported — returns false |
| `GE` | Greater or equal | `ctx ≥ low` | ditto |
| `LT` | Less than | `ctx < low` | ditto |
| `LE` | Less or equal | `ctx ≤ low` | ditto |
| `BT` | Between | `low ≤ ctx ≤ high` | ditto |
| `CP` | Character pattern | uses ABAP `CP` with `*`/`+` wildcards (case-insensitive) |

**Numeric coercion is automatic**: if both operands parse as `decfloat34`, numeric comparison runs. Otherwise falls back to case-insensitive string comparison. This means `TOTAL_AMOUNT GE 100000` works regardless of whether the context value is stored as `'100000'` or `'1.0E5'` — both parse numerically.

### Exception: `ZCX_APPR_NO_RULE_FOUND`

Subclass of `cx_static_check`. Carries `object_type` and `level` as read-only attributes. `get_text()` formats as `"No matching approval rule for <object_type> level <level>"`. Callers can catch and display directly.

---

## 7. Integration pattern — context-on-instance

This is the recommended way for consumer BOs to get routing from the engine.

### The flow

```
┌────────────────────┐       ┌──────────────────────┐       ┌─────────────────┐
│  Consumer BO       │       │  ZR_APPR_INSTANCE    │       │  Rule Engine    │
│  (ProcurementPlan, │  1    │  (managed RAP)       │  3    │  (stateless)    │
│   PurchaseOrder)   │ ───▶  │                      │ ───▶  │                 │
│                    │       │  submit action       │       │                 │
│  - creates Instance│       │  - reads ctx from    │       │                 │
│  - writes context  │  2    │    zappr_inst_ctx    │       │                 │
│    rows            │ ───▶  │  - calls engine      │       │                 │
│                    │       │  - stores result in  │  4    │                 │
│  - calls submit    │       │    approver_role     │ ◀───  │                 │
│                    │       │    + creates Step    │       │                 │
└────────────────────┘       └──────────────────────┘       └─────────────────┘
```

### Consumer responsibilities

1. **Create an Instance** — via EML `MODIFY ENTITIES OF zr_appr_instance ENTITY ApprovalInstance CREATE` or direct `INSERT zappr_instance`. Required fields: `object_type`, `object_key`, `object_name`, `description`
2. **Write context rows** — for each field the rules need (e.g. `DEPARTMENT`, `TOTAL_AMOUNT`, whatever you defined in the conditions for this object type), `INSERT zappr_inst_ctx FROM VALUE #( approval_id = ..., field_name = 'DEPARTMENT', field_value = 'FINANCE' )`
3. **Commit** (or stay in a draft session until the user saves)
4. **Execute submit** — via EML: `MODIFY ENTITIES OF zr_appr_instance ENTITY ApprovalInstance EXECUTE submit FROM VALUE #( ( approval_id = ... ) )`

The submit action's local handler (`lhc_ApprovalInstance~submit` via `resolve_via_engine`) reads the context rows directly from `zappr_inst_ctx`, builds a `ty_context` sorted table, calls `zcl_appr_rule_engine=>determine_agent(iv_object_type, iv_level=1, it_context)`, stores the returned `agent_id` in `zappr_instance.approver_role`, sets `current_status = 'SB'`, and creates an audit step. If the engine raises `ZCX_APPR_NO_RULE_FOUND`, the message is surfaced through the RAP `reported` table so Fiori displays it.

### Example (from `ZCL_APPR_E2E_DEMO`)

```abap
DATA(lv_id) = cl_system_uuid=>create_uuid_x16_static( ).

INSERT zappr_instance FROM @( VALUE #(
  approval_id     = lv_id
  approval_number = 'DEMO-FINANCE'
  object_type     = 'PROC_PLAN'
  object_key      = cl_system_uuid=>create_uuid_x16_static( )
  object_name     = 'Demo Plan - FINANCE'
  description     = 'E2E demo'
  current_status  = 'DR'
  requested_by    = cl_abap_context_info=>get_user_technical_name( ) ) ).

INSERT zappr_inst_ctx FROM TABLE @( VALUE #(
  ( approval_id = lv_id field_name = 'DEPARTMENT'   field_value = 'FINANCE' )
  ( approval_id = lv_id field_name = 'TOTAL_AMOUNT' field_value = '50000'   )
) ).

COMMIT WORK AND WAIT.

MODIFY ENTITIES OF zr_appr_instance
  ENTITY ApprovalInstance
    EXECUTE submit
    FROM VALUE #( ( approval_id = lv_id ) )
  FAILED DATA(ls_failed)
  REPORTED DATA(ls_reported).

COMMIT ENTITIES.
" → zappr_instance.approver_role is now 'FINANCE_MGR', status is 'SB'
```

### Why not a direct API call?

The previous (Phase 11) pattern was for consumers to call `zcl_appr_rule_engine=>determine_agent` directly in their own submit logic. The context-on-instance pattern is preferred because:
- Consumers don't import the rule engine class — less coupling
- The context is persisted alongside the instance, so auditors can see exactly what drove the routing decision
- The same context can be re-used when `approve` needs a level-2 resolution, or when `resubmit` rebuilds from level 1
- Fiori admins can edit context in draft mode via a UI section if something was wrong

### Where to build the context

Up to the consumer. Typical patterns:

- **In the consumer BO's own "submit for approval" action**: read fields off the business object, write them to `zappr_inst_ctx` immediately before executing submit on the approval instance
- **In a determination on the consumer BO**: every save updates the context
- **Via user input**: the admin UI of the approval app lets you edit context fields directly — useful for ad-hoc approvals

---

## 8. Approve / reject / resubmit / withdraw

The Instance BO's local handler implements all five state transitions:

| Action | Effect | Engine call? |
|---|---|---|
| `submit` | `DR` → `SB`. Calls engine to resolve level-1 agent | Yes |
| `approve` | At final level: `SB` → `AP`. Otherwise advances level and calls engine for next-level agent | Yes (for escalation) |
| `reject` | `SB` → `RJ`. Captures `decided_by`/`decided_at`/`decision_comment` | No |
| `withdraw` | `SB` → `WD`. Requester-only | No |
| `resubmit` | `RJ`/`WD` → `SB`. Resets decision fields, calls engine for level-1 agent again | Yes |

Every action creates a row in `ZAPPR_STEP` with `from_status`, `to_status`, `performed_by`, `performed_at`, `step_comment` for a full audit trail.

Authorization is stubbed — `check_user_has_role` always returns `true`. A real deployment would query the IAM API or check user group membership. That's intentional MVP scope.

---

## 9. Fiori apps

Two apps, bound to two separate service definitions. Each has its own service binding and renders as a separate tile in the Fiori Launchpad.

### App 1 — Approval Configuration (`ZUI_APPR_OBJ_TYPE_O4`)

Root service: `ZSD_APPR_OBJ_TYPE`. Exposes:
- `ObjectType` — list report of configurable object types
- `ApprovalRule` — sub-table on the Object Type page (Approval Chain)
- `RuleCondition` — sub-table on the Rule page (Conditions)
- `ApprovalInstance` — read-only sub-table on the Object Type page (Approval Requests), via `_Instance` association
- `ApprovalContext`, `RoleValueHelp`, `AgentTypeValueHelp` — supporting entities for VHs

**Use:** admin configures routing. They edit object types, define rules per object type with priority + agent binding + conditions, and can see which approval requests are currently open for each object type.

### App 2 — Approval Requests (`ZUI_APPR_INSTANCE_O4`)

Root service: `ZSD_APPR_INSTANCE`. Exposes:
- `ApprovalInstance` — list report of approval requests, with `submit` / `approve` / `reject` / `withdraw` / `resubmit` actions wired as object-page buttons
- `ApprovalStep` — sub-table on the Instance page (Approval History, read-only)
- `ApprovalContext` — sub-table on the Instance page (Routing Context, editable in draft)

**Use:** end users and approvers. Requesters create new approval instances and submit them. Approvers see incoming requests, add decision comments, and act. History and routing context are visible for audit.

### UI annotation key decisions

- **`@ObjectModel.representativeKey: 'rule_id'`** on `ZC_APPR_RULE` — unlocks display-mode row-click navigation from the Object Type's inline Approval Chain table to the Rule object page. Without this, Fiori Elements V4 treats composition-child inline tables as inline-edit-only and suppresses the navigation chevron in display mode. `@ObjectModel.semanticKey` would be preferred but is only valid on root projections
- **`@UI.textArrangement: #TEXT_LAST` + `@ObjectModel.text.element: ['user_name']`** on `agent_id` — shows `CB9980000062 (busisiwe sibanyoni)` in place of the raw ID. `user_name` is a simple path expression `_User.PersonFullName` — the only kind of computation projection views allow
- **`@UI.facet` with `#LINEITEM_REFERENCE` for sub-tables** — used for Rules under ObjectType, Conditions under Rule, Requests under ObjectType, Context + Steps under Instance. All one level deep; Fiori Elements V4 doesn't support nested inline tables
- **Admin fields hidden** via `@UI.hidden: true` on `created_by` etc. on the Rule DDLX — the fields aren't populated for seeded data, and showing them as "—" was ugly

### Value help flow

Editing a rule in the config app:

1. **Agent Type** dropdown → `ZI_APPR_AGENT_TYPE_VH` (two values: USER, ROLE)
2. **Agent ID** F4 dialog → `ZI_APPR_AGENT_VH`, a UNION ALL view that shows both real tenant users (6 rows from `I_BusinessUserVH` in the current demo tenant) and live business roles (6 rows from `I_IAMBusinessRole`). Each row is tagged with an `agent_type` column. `additionalBinding: [{ localElement: 'agent_type', element: 'agent_type' }]` on the VH annotation means selecting any row populates both `agent_id` AND `agent_type` in the rule simultaneously

Note: **no IAM API call** at runtime — `ZI_APPR_ROLE_VH` selects directly from `I_IAMBusinessRole`, avoiding the Surface-contract violation that blocks calling `CL_IAM_BUSINESS_ROLE_FACTORY` from a CDS query provider context.

---

## 10. Seed data (`ZCL_APPR_SEED`)

F9-runnable class that populates:
- **Agent types**: `USER`, `ROLE`
- **Object types**: 6 entries — `PROC_PLAN`, `PO`, `PR`, `CONTRACT`, `CAPEX`, `TRAVEL` (last one inactive)
- **Rules**: 4 rules, all `PROC_PLAN` and all USER-type
- **Conditions**: 4 conditions attached to the PROC_PLAN rules

### Seeded rules

| # | Level | Priority | Agent | Condition |
|---|---|---|---|---|
| 1 | 1 | 10 | USER / FINANCE_MGR | DEPARTMENT `EQ` FINANCE |
| 2 | 1 | 20 | USER / LOGISTICS_MGR | DEPARTMENT `EQ` LOGISTICS |
| 3 | 1 | 30 | USER / IT_MGR | DEPARTMENT `EQ` IT |
| 4 | 2 | 10 | USER / CFO_USER | TOTAL_AMOUNT `GE` 100000 |

**No catch-all rules.** If a request doesn't match any of the above, submit fails with `ZCX_APPR_NO_RULE_FOUND`. This is intentional for demo clarity — it forces you to think about which dept/amount combinations should be covered. Add your own catch-all `priority = 99` rules with no conditions to restore "default" routing.

**The Z-role-based rules from earlier phases were deliberately removed** because the user IDs like `FINANCE_MGR`, `CFO_USER` are synthetic (they don't exist in the IAM of the demo tenant) and the roles were synthetic too. Once you configure real rules via the Fiori app pointing at real tenant users/roles, everything works end-to-end.

---

## 11. Tests

### `ZCL_APPR_SMOKE_TEST` — engine-level test
F9-runnable. Exercises `ZCL_APPR_RULE_ENGINE=>determine_agent` directly with 7 hand-built context maps. Reports `[OK]` / `[FAIL]` against expected outcomes.

Tests 3 happy-path USER matches (FINANCE, LOGISTICS, IT), 1 high-amount L2 match (CFO), and 3 expected-exception cases (no L1 catch-all, no L2 catch-all, unknown object type).

Doesn't touch the Instance BO at all. Pure engine testing.

### `ZCL_APPR_E2E_DEMO` — integration test
F9-runnable. Proves the **context-on-instance integration end-to-end** by creating approval instances + context rows in the persistent tables, then calling `submit` via EML to trigger the full Instance BO handler path (read context → call engine → store agent → create step).

Three cases: FINANCE/50k (expects `FINANCE_MGR`), IT/150k (expects `IT_MGR`), MARKETING/10k (expects the exception — no rule for MARKETING). Each case prints the final state and any failure messages from `reported-approvalinstance`.

Run this after any change to `ZBP_R_APPR_INSTANCE` handler code to verify the full path still works.

---

## 12. Extension guide

### How to add a new object type

**Option A — via the Fiori Configuration app (interactive)**
1. Open the Approval Configuration app
2. Create a new Object Type with code + name
3. Drill into the new object type
4. Add rules via Approval Chain → Create
5. Set each rule's level, priority, agent type + agent (F4 picks from live users or roles)
6. Drill into each rule → add conditions via the Conditions sub-table

**Option B — via the seed class (reproducible)**
Edit `ZCL_APPR_SEED=>seed_object_types` to add a row, and `seed_rules` to add matching `insert_rule` + `insert_condition` calls. Re-run via F9.

### How to integrate a new consumer BO

1. Pick an `object_type` code (your new BO or an existing one)
2. Make sure at least one rule exists for it (via config app or seed)
3. In the consumer's "submit for approval" code path:
   - Create an approval instance (`ZR_APPR_INSTANCE` EML create or direct INSERT)
   - Write context rows to `zappr_inst_ctx` for each condition-relevant field (`DEPARTMENT`, `TOTAL_AMOUNT`, or whatever your rules reference)
   - Call `submit` via EML on the instance
4. Store the returned `approval_id` somewhere on your BO so you can show status back to the user

See `ZCL_APPR_E2E_DEMO` for a concrete example.

### How to add a new operator to the rule engine

`ZCL_APPR_RULE_ENGINE=>compare` is a `CASE iv_operator` block. Add a new `WHEN '<code>'` branch. Then optionally add it to:
- The `ZAPPR_CONDITION.operator` column — no schema change needed, it's just char(2)
- A value help view for the operator column (not currently built)
- Documentation

### How to add a new context field

None! The engine treats the context table as a generic `{name: value}` map. Whatever field names you put in the conditions and the instance context rows, the engine just looks them up by name. No schema change, no code change. Add a new condition via the Fiori app with `field_name = 'REGION'`, seed your instance with `REGION = 'EU'`, and it just works.

### How to add a new agent type (beyond USER and ROLE)

1. Add a row to `ZAPPR_AGENT_TYPE` via `ZCL_APPR_SEED=>seed_agent_types` (e.g., `TEAM`, `DELEGATE`)
2. If you want a dedicated F4 value help, build it as a view entity and UNION it into `ZI_APPR_AGENT_VH`
3. Update any downstream code that interprets `agent_type` (e.g., the consumer BO that reads `zappr_instance.approver_role` after submit). The engine itself is agnostic

### How to disable a rule temporarily

Set `is_active = ' '` (or blank) on the rule. The engine filters by `is_active = abap_true` so inactive rules are ignored. Useful for testing or during a migration.

---

## 13. Constraints and gotchas

Captured here so you don't spend an afternoon rediscovering them.

### Cloud ABAP constraints

- **Surface vs Read contracts** — the `CL_IAM_BUSINESS_ROLE_FACTORY` API is marked Surface-contract and **cannot be called from a RAP query provider** (which runs under Read contract). If you need IAM data in a VH, use `I_IAMBusinessRole` (a released CDS view) rather than the factory class
- **Projection views reject computed expressions** — no `CASE`, no `CAST`, no `COALESCE`, no `CONCAT`, no arithmetic. Only field rename and simple path expressions (`_Assoc.field as alias`). For computation, either do it in the interface view (with the draft-table constraint) or use virtual elements with a calculator class
- **Managed draft tables must mirror the view structure** — if your interface view has a computed field, the draft table needs a matching column or the BDEF activation fails with "not a suitable draft persistency". `virtual` elements are excluded
- **Table names are capped at 16 characters** — `ZAPPR_INSTANCE_CTX` was rejected; we used `ZAPPR_INST_CTX`. View names are capped at 30
- **RAP lock master chains require direct associations** — `lock dependent by _assoc` only works if `_assoc` points directly at the lock master. Multi-hop chains like Condition → Rule → ObjectType aren't allowed. We denormalized `object_type` onto `zappr_condition` to give Condition a direct association
- **`@ObjectModel.semanticKey`** is only valid on root view entities. For sub-entity projections, use `@ObjectModel.representativeKey` instead

### Fiori Elements V4 quirks

- **Multiple `@Consumption.valueHelpDefinition` entries on one field break silently** — the dropdown opens but returns no results. Always merge into a single VH view (e.g., via UNION ALL) with an `additionalBinding` to carry extra result fields
- **Composition-child inline tables need `@ObjectModel.representativeKey`** to get display-mode row click navigation. Without it, the chevron doesn't render
- **Empty `@UI.facet` sections show as "—"** — hide them with `@UI.hidden` on individual fields or remove the facet entirely

### Integration constraints

- **The rule engine is case-insensitive for string compares** — `FINANCE` and `finance` both match `DEPARTMENT EQ FINANCE`. Numeric compares are exact
- **Context field values are truncated to 100 characters** — `zappr_inst_ctx.field_value` is `char(100)`. Longer values silently lose data
- **Seeded synthetic names like `FINANCE_MGR` won't resolve** via the user VH's text binding — the display will show the raw ID because there's no matching user in IAM. Replace them with real user IDs via F4 in the Fiori app
- **RAP action parameters cannot carry runtime maps** — that's why context lives on the instance rather than being passed to `submit()` as an action parameter

### Tool quirks (MCP development environment)

These only matter if you're using the `mcp-abap-adt` MCP server to build on top of this:
- `UpdateLocalTypes` silently fails to activate. Always follow it with `ActivateObjects [{CLAS}]`
- `RuntimeRunClassWithProfiling` silently no-ops for the first run after a new table is created. Force-regenerate the class via `ActivateObjects` and retry
- `GetSqlQuery` cannot preview `P_`-prefixed SAP views or tables outside the customer package

---

## 14. File reference

All sources live in package `ZWORKFLOW`. Local mirror at `local-reference/` tracks them for context management.

### Tables
- `ZAPPR_OBJ_TYPE`, `ZAPPR_D_OBJTYP` — object types (config)
- `ZAPPR_RULE`, `ZAPPR_D_RULE` — routing rules
- `ZAPPR_CONDITION`, `ZAPPR_D_COND` — rule conditions
- `ZAPPR_AGENT_TYPE` — agent type enum (2 rows)
- `ZAPPR_INSTANCE`, `ZAPPR_D_INST` — approval instances (runtime)
- `ZAPPR_STEP`, `ZAPPR_D_STEP` — audit trail
- `ZAPPR_INST_CTX`, `ZAPPR_D_CTX` — routing context rows

### Interface views
- `ZR_APPR_OBJ_TYPE`, `ZR_APPR_RULE`, `ZR_APPR_CONDITION`
- `ZR_APPR_INSTANCE`, `ZR_APPR_STEP`, `ZR_APPR_INSTANCE_CTX`

### Consumption projections
- `ZC_APPR_OBJ_TYPE`, `ZC_APPR_RULE`, `ZC_APPR_CONDITION`
- `ZC_APPR_INSTANCE`, `ZC_APPR_STEP`, `ZC_APPR_INSTANCE_CTX`

### Value help views
- `ZI_APPR_OBJ_TYPE_VH`, `ZI_APPR_AGENT_TYPE_VH`
- `ZI_APPR_ROLE_VH`, `ZI_APPR_AGENT_VH`

### BDEFs
- `ZR_APPR_OBJ_TYPE` / `ZC_APPR_OBJ_TYPE` — config BO
- `ZR_APPR_INSTANCE` / `ZC_APPR_INSTANCE` — runtime BO

### Classes
- `ZCL_APPR_RULE_ENGINE` — the engine
- `ZCX_APPR_NO_RULE_FOUND` — engine exception
- `ZBP_R_APPR_OBJ_TYPE` — empty behavior pool (managed BO)
- `ZBP_R_APPR_INSTANCE` — behavior pool with local-type custom action handlers
- `ZCL_APPR_SEED` — F9-runnable seed for config + rules
- `ZCL_APPR_SMOKE_TEST` — F9-runnable engine test
- `ZCL_APPR_E2E_DEMO` — F9-runnable integration test

### Service definitions + bindings
- `ZSD_APPR_OBJ_TYPE` → `ZUI_APPR_OBJ_TYPE_O4` — Configuration app
- `ZSD_APPR_INSTANCE` → `ZUI_APPR_INSTANCE_O4` — Requests app

### Abstract entities + DDLX
- `ZA_APPR_DECISION_COMMENT` — action parameter type
- `ZC_APPR_*` DDLX for each consumption projection — Fiori layout annotations

---

## 15. Open items

Known gaps for future phases:

- **Proper agent_id / agent_type columns on `zappr_instance`** — currently repurposing `approver_role`. Clean rename + schema change to remove semantic drift
- **Virtual element for agent name on ROLE agents** — USER agents get a name via `_User.PersonFullName` path expression, ROLE agents show raw ID. A calculator class would handle both
- **Conditions count / summary column** on the Approval Chain line item — so admins can audit routing rules at a glance without drilling into each
- **Field-name value help** on the Context + Condition entry — currently free text, easy to typo `DEPT` vs `DEPARTMENT` and silently miss the rule
- **Parallel approvals** — the engine resolves ONE agent per level. Multi-agent parallel approval would need a different Instance BO shape
- **Workflow task / inbox integration** — the "Assigned Agent" is currently just a string. Real delivery would push a task to the agent's Fiori inbox
- **Deadline / SLA tracking** — no time-based state transitions
- **RAP validation on rule save** — enforce `agent_id` exists in the corresponding catalog (user VH or role VH) at save time
- **Real ProcurementPlan BO as a reference consumer** — the `ZCL_APPR_E2E_DEMO` fakes it via direct inserts. A real BO with its own draft/state/UI would be a useful reference implementation

---

## Related documents

- **[`local-reference/INVENTORY.md`](local-reference/INVENTORY.md)** — complete object inventory with per-object notes
- **[`local-reference/CHANGELOG-rules-engine.md`](local-reference/CHANGELOG-rules-engine.md)** — build history by phase, with gotchas and decisions
- **[`CLAUDE.md`](CLAUDE.md)** — project rules and local-reference refresh policy
