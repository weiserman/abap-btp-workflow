CLASS zcl_appr_smoke_test DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_appr_smoke_test IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    out->write( '=== Creating Test Approval Instances ===' ).

    " Clean up
    DELETE FROM zappr_step.
    DELETE FROM zappr_instance.
    out->write( 'Cleaned previous data.' ).

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_ts).

    " Instance 1: Procurement Plan - Submitted (level 1)
    DATA(lv_id1) = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zappr_instance FROM @( VALUE #(
      approval_id = lv_id1  approval_number = 'APR-20260413-0001'
      object_type = 'PROC_PLAN'  object_key = cl_system_uuid=>create_uuid_x16_static( )
      object_name = 'IT Equipment Plan Q3 2026'
      description = 'Quarterly procurement plan for laptops, monitors and peripherals'
      justification = 'Approved in annual budget. 45 new hires expected in Q3.'
      current_status = 'SB'  approver_role = 'ZPROCPLAN_APPROVER'  approver_level = 1
      requested_by = lv_user  requested_at = lv_ts
      created_by = lv_user  created_at = lv_ts  last_changed_by = lv_user  last_changed_at = lv_ts  local_last_changed = lv_ts ) ).
    out->write( |1. Procurement Plan (Submitted L1): { sy-subrc }| ).

    INSERT zappr_step FROM @( VALUE #(
      step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id1
      sequence = 1  from_status = 'DR'  to_status = 'SB'
      approver_role = 'ZPROCPLAN_APPROVER'  performed_by = lv_user  performed_at = lv_ts
      step_comment = 'Submitted for manager approval'  local_last_changed = lv_ts ) ).

    " Instance 2: Purchase Order - Submitted
    DATA(lv_id2) = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zappr_instance FROM @( VALUE #(
      approval_id = lv_id2  approval_number = 'APR-20260413-0002'
      object_type = 'PO'  object_key = cl_system_uuid=>create_uuid_x16_static( )
      object_name = 'PO-2026-00142 Dell Technologies'
      description = 'Purchase order for 50x Dell Latitude 5550 laptops'
      justification = 'Replacement cycle for engineering team. Vendor selected via RFP.'
      current_status = 'SB'  approver_role = 'ZPO_APPROVER'  approver_level = 1
      requested_by = lv_user  requested_at = lv_ts
      created_by = lv_user  created_at = lv_ts  last_changed_by = lv_user  last_changed_at = lv_ts  local_last_changed = lv_ts ) ).
    out->write( |2. Purchase Order (Submitted): { sy-subrc }| ).

    INSERT zappr_step FROM @( VALUE #(
      step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id2
      sequence = 1  from_status = 'DR'  to_status = 'SB'
      approver_role = 'ZPO_APPROVER'  performed_by = lv_user  performed_at = lv_ts
      step_comment = 'Submitted for purchasing manager review'  local_last_changed = lv_ts ) ).

    " Instance 3: Contract - Withdrawn
    DATA(lv_id3) = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zappr_instance FROM @( VALUE #(
      approval_id = lv_id3  approval_number = 'APR-20260413-0003'
      object_type = 'CONTRACT'  object_key = cl_system_uuid=>create_uuid_x16_static( )
      object_name = 'MSA-2026-AWS Cloud Services'
      description = 'Master service agreement for AWS cloud infrastructure'
      justification = '3-year commitment with 15% volume discount. Legal review required.'
      current_status = 'WD'  approver_role = 'ZCONTRACT_LEGAL'  approver_level = 1
      requested_by = lv_user  requested_at = lv_ts
      created_by = lv_user  created_at = lv_ts  last_changed_by = lv_user  last_changed_at = lv_ts  local_last_changed = lv_ts ) ).
    out->write( |3. Contract (Withdrawn): { sy-subrc }| ).

    INSERT zappr_step FROM TABLE @( VALUE #(
      ( step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id3
        sequence = 1  from_status = 'DR'  to_status = 'SB'
        approver_role = 'ZCONTRACT_LEGAL'  performed_by = lv_user  performed_at = lv_ts
        step_comment = 'Submitted for legal review'  local_last_changed = lv_ts )
      ( step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id3
        sequence = 2  from_status = 'SB'  to_status = 'WD'
        approver_role = 'ZCONTRACT_LEGAL'  performed_by = lv_user  performed_at = lv_ts
        step_comment = 'Withdrawn - terms need renegotiation'  local_last_changed = lv_ts )
    ) ).

    " Instance 4: CapEx - Draft
    DATA(lv_id4) = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zappr_instance FROM @( VALUE #(
      approval_id = lv_id4  approval_number = 'APR-20260413-0004'
      object_type = 'CAPEX'  object_key = cl_system_uuid=>create_uuid_x16_static( )
      object_name = 'CAPEX-2026-DC-Expansion'
      description = 'Data center expansion - new server racks and cooling'
      justification = 'Current capacity at 92%. Projected to exceed by Q4 2026.'
      current_status = 'DR'
      requested_by = lv_user  requested_at = lv_ts
      created_by = lv_user  created_at = lv_ts  last_changed_by = lv_user  last_changed_at = lv_ts  local_last_changed = lv_ts ) ).
    out->write( |4. CapEx (Draft): { sy-subrc }| ).

    " Instance 5: Purchase Request - Approved
    DATA(lv_id5) = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zappr_instance FROM @( VALUE #(
      approval_id = lv_id5  approval_number = 'APR-20260413-0005'
      object_type = 'PR'  object_key = cl_system_uuid=>create_uuid_x16_static( )
      object_name = 'PR-2026-Marketing Campaign Materials'
      description = 'Purchase request for Q3 marketing campaign print materials'
      justification = 'Campaign approved by CMO. Budget allocated from marketing fund.'
      current_status = 'AP'  approver_role = 'ZPR_APPROVER'  approver_level = 1
      requested_by = lv_user  requested_at = lv_ts
      decided_by = 'MANAGER1'  decided_at = lv_ts  decision_comment = 'Approved - within budget allocation'
      created_by = lv_user  created_at = lv_ts  last_changed_by = lv_user  last_changed_at = lv_ts  local_last_changed = lv_ts ) ).
    out->write( |5. Purchase Request (Approved): { sy-subrc }| ).

    INSERT zappr_step FROM TABLE @( VALUE #(
      ( step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id5
        sequence = 1  from_status = 'DR'  to_status = 'SB'
        approver_role = 'ZPR_APPROVER'  performed_by = lv_user  performed_at = lv_ts
        step_comment = 'Submitted for department head approval'  local_last_changed = lv_ts )
      ( step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id5
        sequence = 2  from_status = 'SB'  to_status = 'AP'
        approver_role = 'ZPR_APPROVER'  performed_by = 'MANAGER1'  performed_at = lv_ts
        step_comment = 'Approved - within budget allocation'  local_last_changed = lv_ts )
    ) ).

    " Instance 6: Procurement Plan - Rejected
    DATA(lv_id6) = cl_system_uuid=>create_uuid_x16_static( ).
    INSERT zappr_instance FROM @( VALUE #(
      approval_id = lv_id6  approval_number = 'APR-20260413-0006'
      object_type = 'PROC_PLAN'  object_key = cl_system_uuid=>create_uuid_x16_static( )
      object_name = 'Office Furniture Refresh 2026'
      description = 'Complete office furniture replacement for floors 3-5'
      justification = 'Furniture is 8 years old. Ergonomic assessment recommends replacement.'
      current_status = 'RJ'  approver_role = 'ZPROCPLAN_APPROVER'  approver_level = 1
      requested_by = lv_user  requested_at = lv_ts
      decided_by = 'MANAGER1'  decided_at = lv_ts  decision_comment = 'Rejected - defer to next fiscal year. Budget constraints.'
      created_by = lv_user  created_at = lv_ts  last_changed_by = lv_user  last_changed_at = lv_ts  local_last_changed = lv_ts ) ).
    out->write( |6. Procurement Plan (Rejected): { sy-subrc }| ).

    INSERT zappr_step FROM TABLE @( VALUE #(
      ( step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id6
        sequence = 1  from_status = 'DR'  to_status = 'SB'
        approver_role = 'ZPROCPLAN_APPROVER'  performed_by = lv_user  performed_at = lv_ts
        step_comment = 'Submitted for approval'  local_last_changed = lv_ts )
      ( step_id = cl_system_uuid=>create_uuid_x16_static( )  approval_id = lv_id6
        sequence = 2  from_status = 'SB'  to_status = 'RJ'
        approver_role = 'ZPROCPLAN_APPROVER'  performed_by = 'MANAGER1'  performed_at = lv_ts
        step_comment = 'Rejected - defer to next fiscal year. Budget constraints.'  local_last_changed = lv_ts )
    ) ).

    COMMIT WORK AND WAIT.

    " Summary
    out->write( '' ).
    SELECT COUNT(*) FROM zappr_instance INTO @DATA(lv_total).
    SELECT COUNT(*) FROM zappr_step INTO @DATA(lv_steps).
    out->write( |=== Done: { lv_total } instances, { lv_steps } audit steps ===| ).

  ENDMETHOD.
ENDCLASS.
