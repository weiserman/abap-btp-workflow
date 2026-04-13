CLASS zcl_appr_seed_rules DEFINITION PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_appr_seed_rules IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " Delete existing rules first (idempotent)
    DELETE FROM zappr_rule WHERE object_type = 'PROC_PLAN'.
    out->write( |Cleared existing PROC_PLAN rules. Rows deleted: { sy-dbcnt }| ).

    " Level 1: Procurement Plan Approver
    INSERT zappr_rule FROM @(
      VALUE #( rule_id          = cl_system_uuid=>create_uuid_x16_static( )
               object_type      = 'PROC_PLAN'
               rule_description = 'Procurement Plan - Level 1 Approval'
               approver_role    = 'ZPROCPLAN_APPROVER'
               approver_level   = 1
               is_active        = abap_true ) ).

    IF sy-subrc = 0.
      out->write( 'Level 1 rule inserted: ZPROCPLAN_APPROVER' ).
    ELSE.
      out->write( 'Level 1 rule insert FAILED' ).
    ENDIF.

    " Level 2: Finance Sign-off
    INSERT zappr_rule FROM @(
      VALUE #( rule_id          = cl_system_uuid=>create_uuid_x16_static( )
               object_type      = 'PROC_PLAN'
               rule_description = 'Procurement Plan - Finance Sign-off'
               approver_role    = 'ZPROCPLAN_FINANCE'
               approver_level   = 2
               is_active        = abap_true ) ).

    IF sy-subrc = 0.
      out->write( 'Level 2 rule inserted: ZPROCPLAN_FINANCE' ).
    ELSE.
      out->write( 'Level 2 rule insert FAILED' ).
    ENDIF.

    " Verify
    SELECT COUNT(*) FROM zappr_rule
      WHERE object_type = 'PROC_PLAN'
        AND is_active   = @abap_true
      INTO @DATA(lv_count).

    out->write( |Done. Active PROC_PLAN rules: { lv_count }| ).

  ENDMETHOD.

ENDCLASS.
