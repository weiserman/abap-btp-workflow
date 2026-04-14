CLASS zcl_appr_seed DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    METHODS seed_agent_types  IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
    METHODS seed_object_types IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
    METHODS seed_rules        IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
    METHODS insert_rule
      IMPORTING iv_object_type TYPE zappr_rule-object_type
                iv_level       TYPE zappr_rule-approver_level
                iv_priority    TYPE zappr_rule-priority
                iv_agent_type  TYPE zappr_rule-agent_type
                iv_agent_id    TYPE zappr_rule-agent_id
                iv_description TYPE zappr_rule-rule_description
      RETURNING VALUE(rv_rule_id) TYPE sysuuid_x16.
    METHODS insert_condition
      IMPORTING iv_rule_id     TYPE sysuuid_x16
                iv_object_type TYPE zappr_condition-object_type
                iv_field_name  TYPE zappr_condition-field_name
                iv_operator    TYPE zappr_condition-operator
                iv_value_low   TYPE zappr_condition-value_low
                iv_value_high  TYPE zappr_condition-value_high OPTIONAL.
ENDCLASS.


CLASS zcl_appr_seed IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    seed_agent_types( out ).
    out->write( '' ).
    seed_object_types( out ).
    out->write( '' ).
    seed_rules( out ).
    COMMIT WORK AND WAIT.
    out->write( '' ).
    out->write( '=== Seed Complete ===' ).
  ENDMETHOD.


  METHOD seed_agent_types.

    out->write( '=== Seeding Agent Types ===' ).
    DELETE FROM zappr_agent_type.
    INSERT zappr_agent_type FROM TABLE @( VALUE #(
      ( agent_type = 'USER' description = 'Named User'    is_active = abap_true )
      ( agent_type = 'ROLE' description = 'Business Role' is_active = abap_true )
    ) ).
    out->write( |Inserted { sy-dbcnt } agent types.| ).

  ENDMETHOD.


  METHOD seed_object_types.

    out->write( '=== Seeding Object Types ===' ).
    DELETE FROM zappr_obj_type.
    INSERT zappr_obj_type FROM TABLE @( VALUE #(
      ( object_type = 'PROC_PLAN' object_type_name = 'Procurement Plan'
        object_description = 'Annual or quarterly procurement plans requiring budget approval'
        is_active = abap_true )
      ( object_type = 'PO'        object_type_name = 'Purchase Order'
        object_description = 'Purchase orders above threshold requiring management sign-off'
        is_active = abap_true )
      ( object_type = 'PR'        object_type_name = 'Purchase Request'
        object_description = 'Internal purchase requests from department heads'
        is_active = abap_true )
      ( object_type = 'CONTRACT'  object_type_name = 'Contract'
        object_description = 'Vendor contracts and framework agreements'
        is_active = abap_true )
      ( object_type = 'CAPEX'     object_type_name = 'Capital Expenditure'
        object_description = 'Capital expenditure requests for assets and infrastructure'
        is_active = abap_true )
      ( object_type = 'TRAVEL'    object_type_name = 'Travel Request'
        object_description = 'Business travel approval requests'
        is_active = abap_false )
    ) ).
    out->write( |Inserted { sy-dbcnt } object types.| ).

  ENDMETHOD.


  METHOD seed_rules.

    out->write( '=== Seeding Rules & Conditions ===' ).
    DELETE FROM zappr_condition.
    DELETE FROM zappr_rule.

    " ── PROC_PLAN Level 1: department-based user routing ──
    DATA(lv_r) = insert_rule(
      iv_object_type = 'PROC_PLAN' iv_level = 1 iv_priority = 10
      iv_agent_type  = 'USER' iv_agent_id = 'FINANCE_MGR'
      iv_description = 'PROC_PLAN L1 - Finance Dept Manager' ).
    insert_condition(
      iv_rule_id = lv_r iv_object_type = 'PROC_PLAN'
      iv_field_name = 'DEPARTMENT' iv_operator = 'EQ' iv_value_low = 'FINANCE' ).

    lv_r = insert_rule(
      iv_object_type = 'PROC_PLAN' iv_level = 1 iv_priority = 20
      iv_agent_type  = 'USER' iv_agent_id = 'LOGISTICS_MGR'
      iv_description = 'PROC_PLAN L1 - Logistics Dept Manager' ).
    insert_condition(
      iv_rule_id = lv_r iv_object_type = 'PROC_PLAN'
      iv_field_name = 'DEPARTMENT' iv_operator = 'EQ' iv_value_low = 'LOGISTICS' ).

    lv_r = insert_rule(
      iv_object_type = 'PROC_PLAN' iv_level = 1 iv_priority = 30
      iv_agent_type  = 'USER' iv_agent_id = 'IT_MGR'
      iv_description = 'PROC_PLAN L1 - IT Dept Manager' ).
    insert_condition(
      iv_rule_id = lv_r iv_object_type = 'PROC_PLAN'
      iv_field_name = 'DEPARTMENT' iv_operator = 'EQ' iv_value_low = 'IT' ).

    " ── PROC_PLAN Level 2: amount-based escalation ──
    lv_r = insert_rule(
      iv_object_type = 'PROC_PLAN' iv_level = 2 iv_priority = 10
      iv_agent_type  = 'USER' iv_agent_id = 'CFO_USER'
      iv_description = 'PROC_PLAN L2 - CFO for high-value plans (>=100k)' ).
    insert_condition(
      iv_rule_id = lv_r iv_object_type = 'PROC_PLAN'
      iv_field_name = 'TOTAL_AMOUNT' iv_operator = 'GE' iv_value_low = '100000' ).

    SELECT COUNT(*) FROM zappr_rule      INTO @DATA(lv_rules).
    SELECT COUNT(*) FROM zappr_condition INTO @DATA(lv_conds).
    out->write( |Inserted { lv_rules } rules and { lv_conds } conditions.| ).

  ENDMETHOD.


  METHOD insert_rule.

    rv_rule_id = cl_system_uuid=>create_uuid_x16_static( ).

    INSERT zappr_rule FROM @( VALUE #(
      rule_id          = rv_rule_id
      object_type      = iv_object_type
      rule_description = iv_description
      approver_level   = iv_level
      priority         = iv_priority
      agent_type       = iv_agent_type
      agent_id         = iv_agent_id
      is_active        = abap_true ) ).

  ENDMETHOD.


  METHOD insert_condition.

    INSERT zappr_condition FROM @( VALUE #(
      condition_uuid = cl_system_uuid=>create_uuid_x16_static( )
      rule_uuid      = iv_rule_id
      object_type    = iv_object_type
      field_name     = iv_field_name
      operator       = iv_operator
      value_low      = iv_value_low
      value_high     = iv_value_high ) ).

  ENDMETHOD.

ENDCLASS.
