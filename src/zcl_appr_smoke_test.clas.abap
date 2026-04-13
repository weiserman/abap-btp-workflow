CLASS zcl_appr_smoke_test DEFINITION PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_appr_smoke_test IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( '=== Approval Workflow Smoke Test ===' ).
    out->write( '' ).

    " Step 1: Create
    out->write( '--- Step 1: Create Draft Instance ---' ).

    MODIFY ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance
        CREATE FIELDS ( object_type object_key object_name description justification )
        WITH VALUE #( (
          %cid        = 'TEST1'
          object_type = 'PROC_PLAN'
          object_key  = cl_system_uuid=>create_uuid_x16_static( )
          object_name = 'Test Procurement Plan 2026'
          description = 'Annual procurement plan for IT equipment'
          justification = 'Budget approved in Q1 planning' ) )
      MAPPED DATA(mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF failed-approvalinstance IS NOT INITIAL.
      out->write( 'CREATE FAILED!' ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES.

    DATA(lv_approval_id) = mapped-approvalinstance[ 1 ]-approval_id.
    out->write( |Created instance: { lv_approval_id }| ).

    READ ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance
        ALL FIELDS WITH VALUE #( ( approval_id = lv_approval_id ) )
      RESULT DATA(lt_read).

    IF lt_read IS NOT INITIAL.
      DATA(ls_inst) = lt_read[ 1 ].
      out->write( |  Approval#: { ls_inst-approval_number }| ).
      out->write( |  Status: { ls_inst-current_status }| ).
      out->write( |  Requested By: { ls_inst-requested_by }| ).
    ENDIF.
    out->write( '' ).

    " Step 2: Submit
    out->write( '--- Step 2: Submit ---' ).

    MODIFY ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance
        EXECUTE submit FROM VALUE #( ( approval_id = lv_approval_id ) )
      FAILED DATA(failed_s)
      REPORTED DATA(reported_s).

    IF failed_s-approvalinstance IS NOT INITIAL.
      out->write( 'SUBMIT FAILED!' ).
      RETURN.
    ENDIF.

    COMMIT ENTITIES.

    READ ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance
        ALL FIELDS WITH VALUE #( ( approval_id = lv_approval_id ) )
      RESULT DATA(lt_sub).

    IF lt_sub IS NOT INITIAL.
      ls_inst = lt_sub[ 1 ].
      out->write( |  Status: { ls_inst-current_status }| ).
      out->write( |  Approver Role: { ls_inst-approver_role }| ).
      out->write( |  Approver Level: { ls_inst-approver_level }| ).
    ENDIF.
    out->write( '' ).

    " Step 3: Approve
    out->write( '--- Step 3: Approve (Level 1) ---' ).
    out->write( '(Will fail with self-approval prevention if same user)' ).

    MODIFY ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance
        EXECUTE approve FROM VALUE #( (
          approval_id = lv_approval_id
          %param = VALUE #( decision_comment = 'Approved at L1' ) ) )
      FAILED DATA(failed_a)
      REPORTED DATA(reported_a).

    IF failed_a-approvalinstance IS NOT INITIAL.
      out->write( 'APPROVE blocked (expected: self-approval prevention)' ).
    ELSE.
      COMMIT ENTITIES.
      out->write( 'APPROVE succeeded' ).
    ENDIF.

    READ ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance
        ALL FIELDS WITH VALUE #( ( approval_id = lv_approval_id ) )
      RESULT DATA(lt_apr).

    IF lt_apr IS NOT INITIAL.
      ls_inst = lt_apr[ 1 ].
      out->write( |  Status: { ls_inst-current_status }| ).
      out->write( |  Approver Role: { ls_inst-approver_role }| ).
      out->write( |  Decided By: { ls_inst-decided_by }| ).
    ENDIF.
    out->write( '' ).

    " Step 4: Audit trail
    out->write( '--- Step 4: Audit Trail ---' ).

    READ ENTITIES OF zr_appr_instance
      ENTITY ApprovalInstance BY \_Step
        ALL FIELDS WITH VALUE #( ( approval_id = lv_approval_id ) )
      RESULT DATA(lt_steps).

    SORT lt_steps BY sequence.
    LOOP AT lt_steps INTO DATA(ls_step).
      out->write( |  Step { ls_step-sequence }: { ls_step-from_status }->{ ls_step-to_status } by { ls_step-performed_by } role={ ls_step-approver_role }| ).
    ENDLOOP.

    out->write( '' ).
    out->write( '=== Smoke Test Complete ===' ).

  ENDMETHOD.

ENDCLASS.
