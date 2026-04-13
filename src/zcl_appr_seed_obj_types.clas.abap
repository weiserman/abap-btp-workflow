CLASS zcl_appr_seed_obj_types DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_appr_seed_obj_types IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    out->write( '=== Seeding Object Types ===' ).
    DELETE FROM zappr_obj_type.
    INSERT zappr_obj_type FROM TABLE @( VALUE #(
      ( object_type = 'PROC_PLAN'  object_type_name = 'Procurement Plan'   object_description = 'Annual or quarterly procurement plans requiring budget approval'  is_active = abap_true )
      ( object_type = 'PO'         object_type_name = 'Purchase Order'     object_description = 'Purchase orders above threshold requiring management sign-off'    is_active = abap_true )
      ( object_type = 'PR'         object_type_name = 'Purchase Request'   object_description = 'Internal purchase requests from department heads'                  is_active = abap_true )
      ( object_type = 'CONTRACT'   object_type_name = 'Contract'           object_description = 'Vendor contracts and framework agreements'                         is_active = abap_true )
      ( object_type = 'CAPEX'      object_type_name = 'Capital Expenditure' object_description = 'Capital expenditure requests for assets and infrastructure'      is_active = abap_true )
      ( object_type = 'TRAVEL'     object_type_name = 'Travel Request'     object_description = 'Business travel approval requests'                                 is_active = abap_false )
    ) ).
    out->write( |Inserted { sy-dbcnt } object types.| ).

    out->write( '' ).
    out->write( '=== Seeding Routing Rules ===' ).
    DELETE FROM zappr_rule.
    INSERT zappr_rule FROM TABLE @( VALUE #(
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'PROC_PLAN' rule_description = 'Procurement Plan - Manager Approval'
        approver_role = 'ZPROCPLAN_APPROVER' approver_level = 1 is_active = abap_true )
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'PROC_PLAN' rule_description = 'Procurement Plan - Finance Sign-off'
        approver_role = 'ZPROCPLAN_FINANCE' approver_level = 2 is_active = abap_true )
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'PO' rule_description = 'Purchase Order - Purchasing Manager'
        approver_role = 'ZPO_APPROVER' approver_level = 1 is_active = abap_true )
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'PR' rule_description = 'Purchase Request - Department Head'
        approver_role = 'ZPR_APPROVER' approver_level = 1 is_active = abap_true )
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'CONTRACT' rule_description = 'Contract - Legal Review'
        approver_role = 'ZCONTRACT_LEGAL' approver_level = 1 is_active = abap_true )
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'CONTRACT' rule_description = 'Contract - CFO Approval'
        approver_role = 'ZCONTRACT_CFO' approver_level = 2 is_active = abap_true )
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'CAPEX' rule_description = 'CapEx - Finance Controller'
        approver_role = 'ZCAPEX_FINANCE' approver_level = 1 is_active = abap_true )
      ( rule_id = cl_system_uuid=>create_uuid_x16_static( ) object_type = 'CAPEX' rule_description = 'CapEx - Board Approval'
        approver_role = 'ZCAPEX_BOARD' approver_level = 2 is_active = abap_true )
    ) ).
    out->write( |Inserted { sy-dbcnt } routing rules.| ).

    out->write( '' ).
    SELECT object_type, object_type_name, is_active FROM zappr_obj_type INTO TABLE @DATA(lt_types).
    LOOP AT lt_types INTO DATA(ls_type).
      out->write( |  { ls_type-object_type WIDTH = 15 } { ls_type-object_type_name WIDTH = 25 } active={ ls_type-is_active }| ).
    ENDLOOP.

    out->write( '' ).
    SELECT object_type, rule_description, approver_role, approver_level FROM zappr_rule INTO TABLE @DATA(lt_rules).
    LOOP AT lt_rules INTO DATA(ls_rule).
      out->write( |  { ls_rule-object_type WIDTH = 15 } L{ ls_rule-approver_level } { ls_rule-approver_role WIDTH = 25 } { ls_rule-rule_description }| ).
    ENDLOOP.

    out->write( '' ).
    out->write( '=== Seed Complete ===' ).

  ENDMETHOD.
ENDCLASS.
