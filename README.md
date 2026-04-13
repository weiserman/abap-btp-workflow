# RAP Approval Workflow Engine

A self-contained, reusable approval workflow engine built entirely in ABAP RAP (RESTful Application Programming). Designed as a generic engine where the first use case is procurement plan approval, but extensible to any business object requiring configurable approval processes.

## Why Not SAP Build Process Automation?

This engine keeps everything in the ABAP stack — no external runtime dependencies, no BPA subscription, no Integration Suite. The state machine, routing rules, and feature control are all standard RAP patterns that ABAP developers already know.

## Architecture

```
+---------------------------------------------------------------+
|  Fiori Elements (List Report + Object Page)                   |
|  Service Bindings: ZUI_APPR_INSTANCE_O4, ZUI_APPR_OBJ_TYPE_O4|
+---------------------------------------------------------------+
|  Service Definitions: ZSD_APPR_INSTANCE, ZSD_APPR_OBJ_TYPE    |
+---------------------------------------------------------------+
|  CDS Projections (C_)        |  Metadata Extensions (DDLX)    |
|  ZC_APPR_INSTANCE            |  ZC_APPR_INSTANCE annotations  |
|  ZC_APPR_STEP                |  ZC_APPR_STEP annotations      |
|  ZC_APPR_OBJ_TYPE            |  ZC_APPR_OBJ_TYPE annotations  |
|  ZC_APPR_RULE                |  ZC_APPR_RULE annotations      |
+---------------------------------------------------------------+
|  CDS Interface (R_)          |  Behavior Definitions (BDEF)    |
|  ZR_APPR_INSTANCE            |  Actions: submit, approve,      |
|  ZR_APPR_STEP                |  reject, withdraw, resubmit     |
|  ZR_APPR_OBJ_TYPE            |  Instance feature control       |
|  ZR_APPR_RULE                |  Draft handling                 |
+---------------------------------------------------------------+
|  Database Tables                                              |
|  ZAPPR_INSTANCE | ZAPPR_STEP | ZAPPR_RULE | ZAPPR_OBJ_TYPE   |
|  ZAPPR_D_INST   | ZAPPR_D_STEP | ZAPPR_D_OBJTYP | ZAPPR_D_RULE|
+---------------------------------------------------------------+
```

## How It Works

The engine implements a **state-machine pattern**:

1. A workflow instance is created and linked to a source business object via `object_type` + `object_key`
2. The instance moves through statuses: **Draft → Submitted → Approved / Rejected / Withdrawn**
3. Routing rules determine which business role approves at each level
4. Instance feature control drives the Fiori UI — only relevant actions are shown
5. Every status transition is recorded as an audit step
6. Multi-level approval is supported by chaining rules at increasing levels
7. Self-approval prevention enforces separation of duties

### Status Flow

```
  Draft ──submit──> Submitted ──approve──> Approved
                        │
                        ├──reject──> Rejected ──resubmit──> Submitted
                        │
                        └──withdraw──> Withdrawn ──resubmit──> Submitted
```

### Feature Control Matrix

| Status    | Requestor        | Approver Role Holder | Other |
|-----------|------------------|---------------------|-------|
| Draft     | Submit           | —                   | —     |
| Submitted | Withdraw         | Approve, Reject     | —     |
| Approved  | —                | —                   | —     |
| Rejected  | Resubmit         | —                   | —     |
| Withdrawn | Resubmit         | —                   | —     |

## Two Fiori Apps

### 1. Approval Workflow (ZUI_APPR_INSTANCE_O4)

The main app for requestors and approvers:
- **List Report**: All approval requests with status coloring, filters by status/requestor/object type
- **Object Page**: Request details, business object reference, current approval status, decision, approval history trail
- **Actions**: Submit, Approve (with comment dialog), Reject (with comment dialog), Withdraw, Resubmit

### 2. Workflow Admin (ZUI_APPR_OBJ_TYPE_O4)

Configuration app for administrators:
- **List Report**: All supported object types (Procurement Plan, Purchase Order, Contract, etc.)
- **Object Page**: Object type details + inline approval chain showing routing rules per level
- **CRUD**: Create/edit/delete object types and their routing rules

## Artifacts

### Approval Instance BO

| Type | Name | Description |
|------|------|-------------|
| Table | `ZAPPR_INSTANCE` | Approval workflow instance |
| Table | `ZAPPR_STEP` | Approval step (audit trail) |
| Draft Table | `ZAPPR_D_INST` | Draft for instance |
| Draft Table | `ZAPPR_D_STEP` | Draft for step |
| CDS View | `ZR_APPR_INSTANCE` | Root interface view |
| CDS View | `ZR_APPR_STEP` | Child interface view |
| CDS Projection | `ZC_APPR_INSTANCE` | Root projection |
| CDS Projection | `ZC_APPR_STEP` | Child projection |
| Abstract Entity | `ZA_APPR_DECISION_COMMENT` | Action parameter for approve/reject |
| BDEF | `ZR_APPR_INSTANCE` | Interface behavior (managed + draft) |
| BDEF | `ZC_APPR_INSTANCE` | Projection behavior |
| Class | `ZBP_R_APPR_INSTANCE` | Behavior implementation |
| DCL | `ZR_APPR_INSTANCE` | Access control (placeholder) |
| DCL | `ZR_APPR_STEP` | Access control (placeholder) |
| DDLX | `ZC_APPR_INSTANCE` | Metadata extension |
| DDLX | `ZC_APPR_STEP` | Metadata extension |
| SRVD | `ZSD_APPR_INSTANCE` | Service definition |
| SRVB | `ZUI_APPR_INSTANCE_O4` | Service binding (OData V4 UI) |

### Object Type Config BO

| Type | Name | Description |
|------|------|-------------|
| Table | `ZAPPR_OBJ_TYPE` | Supported object types |
| Table | `ZAPPR_RULE` | Routing rules |
| Draft Table | `ZAPPR_D_OBJTYP` | Draft for object type |
| Draft Table | `ZAPPR_D_RULE` | Draft for rule |
| CDS View | `ZR_APPR_OBJ_TYPE` | Root interface view |
| CDS View | `ZR_APPR_RULE` | Child interface view |
| CDS View | `ZI_APPR_OBJ_TYPE_VH` | Value help for object type |
| CDS Projection | `ZC_APPR_OBJ_TYPE` | Root projection |
| CDS Projection | `ZC_APPR_RULE` | Child projection |
| BDEF | `ZR_APPR_OBJ_TYPE` | Interface behavior |
| BDEF | `ZC_APPR_OBJ_TYPE` | Projection behavior |
| Class | `ZBP_R_APPR_OBJ_TYPE` | Behavior implementation |
| DDLX | `ZC_APPR_OBJ_TYPE` | Metadata extension |
| DDLX | `ZC_APPR_RULE` | Metadata extension |
| SRVD | `ZSD_APPR_OBJ_TYPE` | Service definition |
| SRVB | `ZUI_APPR_OBJ_TYPE_O4` | Service binding (OData V4 UI) |

### Utility Classes

| Name | Description |
|------|-------------|
| `ZCL_APPR_SEED_OBJ_TYPES` | Seeds object types and routing rules |
| `ZCL_APPR_SMOKE_TEST` | Creates test instances across all statuses |
| `ZCL_APPR_SEED_RULES` | Legacy seed program for routing rules |
| `ZCL_APPR_CLEANUP` | Cleans up test data |

## Seed Data

### Object Types

| Code | Name | Active |
|------|------|--------|
| PROC_PLAN | Procurement Plan | Yes |
| PO | Purchase Order | Yes |
| PR | Purchase Request | Yes |
| CONTRACT | Contract | Yes |
| CAPEX | Capital Expenditure | Yes |
| TRAVEL | Travel Request | No |

### Routing Rules

| Object Type | Level | Approver Role | Description |
|-------------|-------|---------------|-------------|
| PROC_PLAN | 1 | ZPROCPLAN_APPROVER | Manager Approval |
| PROC_PLAN | 2 | ZPROCPLAN_FINANCE | Finance Sign-off |
| PO | 1 | ZPO_APPROVER | Purchasing Manager |
| PR | 1 | ZPR_APPROVER | Department Head |
| CONTRACT | 1 | ZCONTRACT_LEGAL | Legal Review |
| CONTRACT | 2 | ZCONTRACT_CFO | CFO Approval |
| CAPEX | 1 | ZCAPEX_FINANCE | Finance Controller |
| CAPEX | 2 | ZCAPEX_BOARD | Board Approval |

## Installation

### Prerequisites

- SAP ABAP 7.58+ or BTP ABAP Environment
- ABAP Development Tools (ADT) in Eclipse

### Deployment Sequence

1. **Tables**: Activate `ZAPPR_INSTANCE`, `ZAPPR_STEP`, `ZAPPR_RULE`, `ZAPPR_OBJ_TYPE` and their draft tables
2. **CDS Interface Views**: Activate `ZR_APPR_STEP` → `ZR_APPR_INSTANCE` → `ZR_APPR_RULE` → `ZR_APPR_OBJ_TYPE`
3. **Abstract Entity**: `ZA_APPR_DECISION_COMMENT`
4. **Value Help**: `ZI_APPR_OBJ_TYPE_VH`
5. **Access Control**: `ZR_APPR_INSTANCE`, `ZR_APPR_STEP`, `ZR_APPR_RULE` (placeholder DCL)
6. **BDEFs**: `ZR_APPR_INSTANCE` → `ZR_APPR_OBJ_TYPE`
7. **Behavior Classes**: Generate from BDEFs in ADT, paste local types from `src/` files
8. **CDS Projections**: `ZC_APPR_STEP` → `ZC_APPR_INSTANCE` → `ZC_APPR_RULE` → `ZC_APPR_OBJ_TYPE`
9. **Projection BDEFs**: `ZC_APPR_INSTANCE` → `ZC_APPR_OBJ_TYPE`
10. **Service Definitions**: `ZSD_APPR_INSTANCE`, `ZSD_APPR_OBJ_TYPE`
11. **Service Bindings**: Create manually in ADT as OData V4 UI, publish
12. **Metadata Extensions**: Create DDLXs manually in ADT from `src/*.ddlx.asddlxs` files
13. **Seed Data**: Run `ZCL_APPR_SEED_OBJ_TYPES` (F9) then `ZCL_APPR_SMOKE_TEST` (F9)

### Important Notes

- **Behavior implementation classes** must be generated from the BDEF in ADT (right-click BDEF → generate). The handler code goes in the **Local Types** tab.
- **Service bindings** and **metadata extensions** must be created manually in ADT — they cannot be deployed via MCP tools.
- **Authorization** is deferred — `check_user_has_role` always returns `abap_true`. Enable by uncommenting the `AUTHORITY-CHECK` in the handler and configuring authorization object `ZAPPR_AUTH`.
- **`COMMENT`** is a reserved word in CDS — the step table uses `step_comment` and the abstract entity uses `decision_comment`.

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Authorization deferred | Simplifies first deployment; IAM setup is manual |
| D2 | Explicit draft tables | Full control over draft table structure |
| D3 | Simple COUNT(*) for approval numbers | Acceptable for MVP |
| D4 | Procurement plan BO integration as TODO | Source BO doesn't exist yet |
| D5 | Proper UTC timestamps | Correct data type alignment for tzntstmpl fields |
| D6 | No Fiori UI for rule maintenance (now added) | Originally config-only, now has full admin app |
| D7 | Placeholder DCL files | Unrestricted access for now |

## Future Enhancements

- **Conditional routing**: Evaluate `condition_field`/`operator`/`value` against source BO data (e.g. amount thresholds)
- **Authorization**: Enable `ZAPPR_AUTH` with role-based access control
- **EML callbacks**: Update source BO status on approve/reject
- **Email notifications**: Notify approvers when a request is submitted
- **Delegation**: Allow approvers to delegate to another user
- **Escalation**: Auto-escalate if not acted on within SLA

## Package & Transport

- **Package**: `ZWORKFLOW`
- **Transport**: `A4HK900112`

## Generated By

This project was scaffolded using [RAP Forge](https://forge.decabase.com) for the Kiro IDE, with the AI-DLC (AI-Driven Development Life Cycle) workflow.
