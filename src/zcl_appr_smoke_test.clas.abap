CLASS zcl_appr_smoke_test DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    METHODS run_case
      IMPORTING out         TYPE REF TO if_oo_adt_classrun_out
                iv_label    TYPE string
                iv_object   TYPE c
                iv_level    TYPE i
                it_context  TYPE zcl_appr_rule_engine=>ty_context
                iv_expected TYPE string OPTIONAL.
ENDCLASS.


CLASS zcl_appr_smoke_test IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( '=== Rule Engine Smoke Test ===' ).
    out->write( '' ).

    run_case(
      out        = out
      iv_label   = 'Test 1 L1 - FINANCE dept'
      iv_object  = 'PROC_PLAN'
      iv_level   = 1
      it_context = VALUE #(
        ( field_name = 'DEPARTMENT'   field_value = 'FINANCE' )
        ( field_name = 'TOTAL_AMOUNT' field_value = '50000' ) )
      iv_expected = 'USER/FINANCE_MGR' ).

    run_case(
      out        = out
      iv_label   = 'Test 2 L1 - LOGISTICS dept'
      iv_object  = 'PROC_PLAN'
      iv_level   = 1
      it_context = VALUE #(
        ( field_name = 'DEPARTMENT'   field_value = 'LOGISTICS' )
        ( field_name = 'TOTAL_AMOUNT' field_value = '25000' ) )
      iv_expected = 'USER/LOGISTICS_MGR' ).

    run_case(
      out        = out
      iv_label   = 'Test 3 L1 - IT dept'
      iv_object  = 'PROC_PLAN'
      iv_level   = 1
      it_context = VALUE #(
        ( field_name = 'DEPARTMENT'   field_value = 'IT' )
        ( field_name = 'TOTAL_AMOUNT' field_value = '10000' ) )
      iv_expected = 'USER/IT_MGR' ).

    run_case(
      out        = out
      iv_label   = 'Test 4 L1 - MARKETING (catch-all)'
      iv_object  = 'PROC_PLAN'
      iv_level   = 1
      it_context = VALUE #(
        ( field_name = 'DEPARTMENT'   field_value = 'MARKETING' )
        ( field_name = 'TOTAL_AMOUNT' field_value = '10000' ) )
      iv_expected = 'ROLE/ZPROCPLAN_APPROVER' ).

    run_case(
      out        = out
      iv_label   = 'Test 5 L2 - high amount (>=100k)'
      iv_object  = 'PROC_PLAN'
      iv_level   = 2
      it_context = VALUE #(
        ( field_name = 'DEPARTMENT'   field_value = 'FINANCE' )
        ( field_name = 'TOTAL_AMOUNT' field_value = '150000' ) )
      iv_expected = 'USER/CFO_USER' ).

    run_case(
      out        = out
      iv_label   = 'Test 6 L2 - normal amount (catch-all)'
      iv_object  = 'PROC_PLAN'
      iv_level   = 2
      it_context = VALUE #(
        ( field_name = 'DEPARTMENT'   field_value = 'IT' )
        ( field_name = 'TOTAL_AMOUNT' field_value = '30000' ) )
      iv_expected = 'ROLE/ZPROCPLAN_FINANCE' ).

    run_case(
      out        = out
      iv_label   = 'Test 7 - Unknown object type (expect exception)'
      iv_object  = 'UNKNOWN'
      iv_level   = 1
      it_context = VALUE #(
        ( field_name = 'DEPARTMENT' field_value = 'X' ) )
      iv_expected = 'EXCEPTION' ).

    run_case(
      out        = out
      iv_label   = 'Test 8 L1 - PO role-based'
      iv_object  = 'PO'
      iv_level   = 1
      it_context = VALUE #( )
      iv_expected = 'ROLE/ZPO_APPROVER' ).

    out->write( '' ).
    out->write( '=== Done ===' ).

  ENDMETHOD.


  METHOD run_case.

    TRY.
        DATA(ls_result) = zcl_appr_rule_engine=>determine_agent(
          iv_object_type = iv_object
          iv_level       = iv_level
          it_context     = it_context ).

        DATA(lv_actual) = |{ ls_result-agent_type }/{ ls_result-agent_id }|.
        DATA(lv_ok)     = COND string(
          WHEN iv_expected IS INITIAL OR lv_actual = iv_expected
          THEN '[OK] '
          ELSE '[FAIL] ' ).
        out->write( |{ lv_ok }{ iv_label }: { lv_actual } — { ls_result-description }| ).

      CATCH zcx_appr_no_rule_found INTO DATA(lx).
        DATA(lv_exc_ok) = COND string(
          WHEN iv_expected = 'EXCEPTION'
          THEN '[OK] '
          ELSE '[FAIL] ' ).
        out->write( |{ lv_exc_ok }{ iv_label }: { lx->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
