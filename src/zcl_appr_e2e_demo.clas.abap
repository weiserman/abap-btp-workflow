CLASS zcl_appr_e2e_demo DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    METHODS run_case
      IMPORTING out             TYPE REF TO if_oo_adt_classrun_out
                iv_label        TYPE string
                iv_department   TYPE c
                iv_total_amount TYPE c.
ENDCLASS.


CLASS zcl_appr_e2e_demo IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( '=== Approval E2E Demo ===' ).
    out->write( 'Create instance + context, submit, verify routing.' ).
    out->write( '' ).

    " Clean previous demo runs
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    SELECT approval_id FROM zappr_instance
      WHERE object_type = 'PROC_PLAN'
        AND requested_by = @lv_user
        AND approval_number LIKE 'DEMO-%'
      INTO TABLE @DATA(lt_old).

    LOOP AT lt_old INTO DATA(ls_old).
      DELETE FROM zappr_step     WHERE approval_id = @ls_old-approval_id.
      DELETE FROM zappr_inst_ctx WHERE approval_id = @ls_old-approval_id.
      DELETE FROM zappr_instance WHERE approval_id = @ls_old-approval_id.
    ENDLOOP.
    IF lt_old IS NOT INITIAL.
      COMMIT WORK AND WAIT.
      out->write( |Cleaned { lines( lt_old ) } previous demo instances.| ).
      out->write( '' ).
    ENDIF.

    run_case(
      out             = out
      iv_label        = 'Case 1 - FINANCE dept, 50k (expect FINANCE_MGR at L1)'
      iv_department   = 'FINANCE'
      iv_total_amount = '50000' ).

    run_case(
      out             = out
      iv_label        = 'Case 2 - IT dept, 150k (expect IT_MGR at L1)'
      iv_department   = 'IT'
      iv_total_amount = '150000' ).

    run_case(
      out             = out
      iv_label        = 'Case 3 - MARKETING dept (no rule, expect submit failure)'
      iv_department   = 'MARKETING'
      iv_total_amount = '10000' ).

    out->write( '' ).
    out->write( '=== Done ===' ).

  ENDMETHOD.


  METHOD run_case.

    out->write( iv_label ).

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_ts).
    DATA(lv_appr_id) = cl_system_uuid=>create_uuid_x16_static( ).

    INSERT zappr_instance FROM @( VALUE #(
      approval_id        = lv_appr_id
      approval_number    = |DEMO-{ iv_department }|
      object_type        = 'PROC_PLAN'
      object_key         = cl_system_uuid=>create_uuid_x16_static( )
      object_name        = |Demo Plan - { iv_department }|
      description        = |E2E demo for { iv_department } dept at { iv_total_amount }|
      justification      = 'Automated demo run'
      current_status     = 'DR'
      requested_by       = lv_user
      requested_at       = lv_ts
      created_by         = lv_user
      created_at         = lv_ts
      last_changed_by    = lv_user
      last_changed_at    = lv_ts
      local_last_changed = lv_ts ) ).

    INSERT zappr_inst_ctx FROM TABLE @( VALUE #(
      ( approval_id = lv_appr_id field_name = 'DEPARTMENT'   field_value = iv_department )
      ( approval_id = lv_appr_id field_name = 'TOTAL_AMOUNT' field_value = iv_total_amount )
    ) ).

    COMMIT WORK AND WAIT.

    MODIFY ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance
        EXECUTE submit
        FROM VALUE #( ( approval_id = lv_appr_id ) )
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    COMMIT ENTITIES.

    SELECT SINGLE current_status, approver_role, approver_level
      FROM zappr_instance
      WHERE approval_id = @lv_appr_id
      INTO ( @DATA(lv_status), @DATA(lv_agent), @DATA(lv_level) ).

    IF lv_status = 'SB'.
      out->write( |  [OK] Submitted → agent={ lv_agent }, level={ lv_level }| ).
    ELSE.
      out->write( |  [FAIL/EXPECTED] status={ lv_status }, failed rows={ lines( ls_failed-approvalinstance ) }| ).
      LOOP AT ls_reported-approvalinstance INTO DATA(ls_r).
        IF ls_r-%msg IS BOUND.
          out->write( |    msg: { ls_r-%msg->if_message~get_text( ) }| ).
        ENDIF.
      ENDLOOP.
    ENDIF.
    out->write( '' ).

  ENDMETHOD.

ENDCLASS.
