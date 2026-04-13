CLASS lhc_ApprovalInstance DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS: BEGIN OF cs_status,
      draft     TYPE zappr_instance-current_status VALUE 'DR',
      submitted TYPE zappr_instance-current_status VALUE 'SB',
      approved  TYPE zappr_instance-current_status VALUE 'AP',
      rejected  TYPE zappr_instance-current_status VALUE 'RJ',
      withdrawn TYPE zappr_instance-current_status VALUE 'WD',
    END OF cs_status.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ApprovalInstance RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ApprovalInstance RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION ApprovalInstance~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION ApprovalInstance~reject RESULT result.

    METHODS resubmit FOR MODIFY
      IMPORTING keys FOR ACTION ApprovalInstance~resubmit RESULT result.

    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION ApprovalInstance~submit RESULT result.

    METHODS withdraw FOR MODIFY
      IMPORTING keys FOR ACTION ApprovalInstance~withdraw RESULT result.

    METHODS generateApprovalNumber FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ApprovalInstance~generateApprovalNumber.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ApprovalInstance~setDefaults.

    METHODS validateObjectReference FOR VALIDATE ON SAVE
      IMPORTING keys FOR ApprovalInstance~validateObjectReference.

    METHODS create_step
      IMPORTING iv_approval_id   TYPE zappr_instance-approval_id
                iv_from_status   TYPE zappr_instance-current_status
                iv_to_status     TYPE zappr_instance-current_status
                iv_approver_role TYPE zappr_instance-approver_role OPTIONAL
                iv_comment       TYPE string OPTIONAL.

    METHODS resolve_approver_role
      IMPORTING iv_object_type    TYPE zappr_instance-object_type
                iv_object_key     TYPE zappr_instance-object_key
                iv_level          TYPE zappr_rule-approver_level DEFAULT 1
      EXPORTING ev_approver_role  TYPE zappr_rule-approver_role
                ev_approver_level TYPE zappr_rule-approver_level.

    METHODS check_user_has_role
      IMPORTING iv_role          TYPE zappr_instance-approver_role
      RETURNING VALUE(rv_result) TYPE abap_bool.

ENDCLASS.

CLASS lhc_ApprovalInstance IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #(
      %create          = if_abap_behv=>auth-allowed
      %update          = if_abap_behv=>auth-allowed
      %action-submit   = if_abap_behv=>auth-allowed
      %action-approve  = if_abap_behv=>auth-allowed
      %action-reject   = if_abap_behv=>auth-allowed
      %action-withdraw = if_abap_behv=>auth-allowed
      %action-resubmit = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance
        FIELDS ( current_status requested_by approver_role )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt)
      FAILED failed.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    result = VALUE #( FOR ls IN lt
      LET r = xsdbool( ls-requested_by = lv_user )
          a = check_user_has_role( ls-approver_role )
          s = xsdbool( ls-requested_by = lv_user )
          d = xsdbool( ls-current_status = cs_status-draft )
          b = xsdbool( ls-current_status = cs_status-submitted )
          j = xsdbool( ls-current_status = cs_status-rejected )
          w = xsdbool( ls-current_status = cs_status-withdrawn )
      IN
      ( %tky = ls-%tky
        %action-submit = COND #(
          WHEN d = abap_true AND r = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-approve = COND #(
          WHEN b = abap_true AND a = abap_true AND s = abap_false
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-reject = COND #(
          WHEN b = abap_true AND a = abap_true AND s = abap_false
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-withdraw = COND #(
          WHEN b = abap_true AND r = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-resubmit = COND #(
          WHEN ( j = abap_true OR w = abap_true ) AND r = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD check_user_has_role.
    IF iv_role IS INITIAL.
      rv_result = abap_false.
      RETURN.
    ENDIF.
    " Deferred authorization — always grant for MVP
    rv_result = abap_true.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance
        FIELDS ( current_status requested_by requested_at )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_ts).

    MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance
        UPDATE FIELDS ( current_status requested_by requested_at )
        WITH VALUE #( FOR i IN lt
          ( %tky           = i-%tky
            current_status = cs_status-draft
            requested_by   = lv_user
            requested_at   = lv_ts ) )
      REPORTED DATA(rep).
  ENDMETHOD.

  METHOD generateApprovalNumber.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance
        FIELDS ( approval_number )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    SELECT COUNT(*) FROM zappr_instance INTO @DATA(lv_cnt).
    lv_cnt += 1.

    MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance
        UPDATE FIELDS ( approval_number )
        WITH VALUE #( FOR i IN lt WHERE ( approval_number IS INITIAL )
          ( %tky            = i-%tky
            approval_number = |APR-{ lv_date+0(8) }-{ lv_cnt ALIGN = RIGHT PAD = '0' WIDTH = 4 }| ) )
      REPORTED DATA(rep).
  ENDMETHOD.

  METHOD validateObjectReference.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance
        FIELDS ( object_type object_key )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    LOOP AT lt INTO DATA(i).
      IF i-object_type IS INITIAL.
        APPEND VALUE #( %tky = i-%tky ) TO failed-approvalinstance.
        APPEND VALUE #( %tky = i-%tky
          %msg = new_message_with_text(
            text     = 'Object type is required'
            severity = if_abap_behv_message=>severity-error )
          %element-object_type = if_abap_behv=>mk-on
        ) TO reported-approvalinstance.
      ENDIF.
      IF i-object_key IS INITIAL.
        APPEND VALUE #( %tky = i-%tky ) TO failed-approvalinstance.
        APPEND VALUE #( %tky = i-%tky
          %msg = new_message_with_text(
            text     = 'Object key is required'
            severity = if_abap_behv_message=>severity-error )
          %element-object_key = if_abap_behv=>mk-on
        ) TO reported-approvalinstance.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD submit.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    LOOP AT lt INTO DATA(i).
      resolve_approver_role(
        EXPORTING iv_object_type = i-object_type
                  iv_object_key  = i-object_key
                  iv_level       = 1
        IMPORTING ev_approver_role  = DATA(lv_role)
                  ev_approver_level = DATA(lv_lvl) ).

      IF lv_role IS INITIAL.
        APPEND VALUE #( %tky = i-%tky ) TO failed-approvalinstance.
        APPEND VALUE #( %tky = i-%tky
          %msg = new_message_with_text(
            text     = 'No approval rule found for this object type'
            severity = if_abap_behv_message=>severity-error )
        ) TO reported-approvalinstance.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
        ENTITY ApprovalInstance
          UPDATE FIELDS ( current_status approver_role approver_level )
          WITH VALUE #( (
            %tky           = i-%tky
            current_status = cs_status-submitted
            approver_role  = lv_role
            approver_level = lv_lvl ) )
        REPORTED DATA(rep).

      create_step(
        iv_approval_id   = i-approval_id
        iv_from_status   = cs_status-draft
        iv_to_status     = cs_status-submitted
        iv_approver_role = lv_role ).
    ENDLOOP.

    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(res).
    result = VALUE #( FOR r IN res ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD approve.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    LOOP AT lt INTO DATA(i).
      IF check_user_has_role( i-approver_role ) = abap_false.
        APPEND VALUE #( %tky = i-%tky ) TO failed-approvalinstance.
        APPEND VALUE #( %tky = i-%tky
          %msg = new_message_with_text(
            text     = 'You are not authorized to approve in this role'
            severity = if_abap_behv_message=>severity-error )
        ) TO reported-approvalinstance.
        CONTINUE.
      ENDIF.

      DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
      IF i-requested_by = lv_user.
        APPEND VALUE #( %tky = i-%tky ) TO failed-approvalinstance.
        APPEND VALUE #( %tky = i-%tky
          %msg = new_message_with_text(
            text     = 'You cannot approve your own request'
            severity = if_abap_behv_message=>severity-error )
        ) TO reported-approvalinstance.
        CONTINUE.
      ENDIF.

      DATA lv_cmt TYPE string.
      READ TABLE keys WITH KEY approval_id = i-approval_id INTO DATA(ls_key).
      IF sy-subrc = 0.
        lv_cmt = ls_key-%param-decision_comment.
      ENDIF.

      DATA(lv_nxt) = i-approver_level + 1.
      resolve_approver_role(
        EXPORTING iv_object_type = i-object_type
                  iv_object_key  = i-object_key
                  iv_level       = lv_nxt
        IMPORTING ev_approver_role  = DATA(lv_nr)
                  ev_approver_level = DATA(lv_nl) ).

      GET TIME STAMP FIELD DATA(lv_ts).

      IF lv_nr IS NOT INITIAL.
        MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
          ENTITY ApprovalInstance
            UPDATE FIELDS ( approver_role approver_level )
            WITH VALUE #( (
              %tky           = i-%tky
              approver_role  = lv_nr
              approver_level = lv_nl ) )
          REPORTED DATA(rn).
        create_step(
          iv_approval_id   = i-approval_id
          iv_from_status   = cs_status-submitted
          iv_to_status     = cs_status-submitted
          iv_approver_role = i-approver_role
          iv_comment       = |Approved at level { i-approver_level }. { lv_cmt }| ).
      ELSE.
        MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
          ENTITY ApprovalInstance
            UPDATE FIELDS ( current_status decided_by decided_at decision_comment )
            WITH VALUE #( (
              %tky             = i-%tky
              current_status   = cs_status-approved
              decided_by       = lv_user
              decided_at       = lv_ts
              decision_comment = lv_cmt ) )
          REPORTED DATA(rf).
        create_step(
          iv_approval_id   = i-approval_id
          iv_from_status   = cs_status-submitted
          iv_to_status     = cs_status-approved
          iv_approver_role = i-approver_role
          iv_comment       = lv_cmt ).
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(res).
    result = VALUE #( FOR r IN res ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD reject.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    LOOP AT lt INTO DATA(i).
      IF check_user_has_role( i-approver_role ) = abap_false.
        APPEND VALUE #( %tky = i-%tky ) TO failed-approvalinstance.
        APPEND VALUE #( %tky = i-%tky
          %msg = new_message_with_text(
            text     = 'You are not authorized to reject in this role'
            severity = if_abap_behv_message=>severity-error )
        ) TO reported-approvalinstance.
        CONTINUE.
      ENDIF.

      DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
      IF i-requested_by = lv_user.
        APPEND VALUE #( %tky = i-%tky ) TO failed-approvalinstance.
        APPEND VALUE #( %tky = i-%tky
          %msg = new_message_with_text(
            text     = 'You cannot reject your own request'
            severity = if_abap_behv_message=>severity-error )
        ) TO reported-approvalinstance.
        CONTINUE.
      ENDIF.

      DATA lv_cmt TYPE string.
      READ TABLE keys WITH KEY approval_id = i-approval_id INTO DATA(ls_key).
      IF sy-subrc = 0.
        lv_cmt = ls_key-%param-decision_comment.
      ENDIF.

      GET TIME STAMP FIELD DATA(lv_ts).

      MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
        ENTITY ApprovalInstance
          UPDATE FIELDS ( current_status decided_by decided_at decision_comment )
          WITH VALUE #( (
            %tky             = i-%tky
            current_status   = cs_status-rejected
            decided_by       = lv_user
            decided_at       = lv_ts
            decision_comment = lv_cmt ) )
        REPORTED DATA(rep).

      create_step(
        iv_approval_id   = i-approval_id
        iv_from_status   = cs_status-submitted
        iv_to_status     = cs_status-rejected
        iv_approver_role = i-approver_role
        iv_comment       = lv_cmt ).
    ENDLOOP.

    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(res).
    result = VALUE #( FOR r IN res ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD withdraw.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    LOOP AT lt INTO DATA(i).
      MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
        ENTITY ApprovalInstance
          UPDATE FIELDS ( current_status )
          WITH VALUE #( (
            %tky           = i-%tky
            current_status = cs_status-withdrawn ) )
        REPORTED DATA(rep).

      create_step(
        iv_approval_id   = i-approval_id
        iv_from_status   = cs_status-submitted
        iv_to_status     = cs_status-withdrawn
        iv_approver_role = i-approver_role ).
    ENDLOOP.

    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(res).
    result = VALUE #( FOR r IN res ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD resubmit.
    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt).

    LOOP AT lt INTO DATA(i).
      resolve_approver_role(
        EXPORTING iv_object_type = i-object_type
                  iv_object_key  = i-object_key
                  iv_level       = 1
        IMPORTING ev_approver_role  = DATA(lv_role)
                  ev_approver_level = DATA(lv_lvl) ).

      MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
        ENTITY ApprovalInstance
          UPDATE FIELDS ( current_status approver_role approver_level
                          decided_by decided_at decision_comment )
          WITH VALUE #( (
            %tky             = i-%tky
            current_status   = cs_status-submitted
            approver_role    = lv_role
            approver_level   = lv_lvl
            decided_by       = ''
            decided_at       = '00000000000000'
            decision_comment = '' ) )
        REPORTED DATA(rep).

      create_step(
        iv_approval_id   = i-approval_id
        iv_from_status   = i-current_status
        iv_to_status     = cs_status-submitted
        iv_approver_role = lv_role ).
    ENDLOOP.

    READ ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(res).
    result = VALUE #( FOR r IN res ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD create_step.
    SELECT COUNT(*) FROM zappr_step
      WHERE approval_id = @iv_approval_id
      INTO @DATA(lv_cnt).

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD DATA(lv_ts).

    MODIFY ENTITIES OF zr_appr_instance IN LOCAL MODE
      ENTITY ApprovalInstance
        CREATE BY \_Step
        FIELDS ( sequence from_status to_status approver_role
                 performed_by performed_at step_comment )
        WITH VALUE #( (
          approval_id = iv_approval_id
          %target = VALUE #( (
            %cid          = |STEP_{ lv_cnt + 1 }|
            sequence      = lv_cnt + 1
            from_status   = iv_from_status
            to_status     = iv_to_status
            approver_role = iv_approver_role
            performed_by  = lv_user
            performed_at  = lv_ts
            step_comment  = iv_comment ) ) ) ).
  ENDMETHOD.

  METHOD resolve_approver_role.
    CLEAR: ev_approver_role, ev_approver_level.
    SELECT SINGLE approver_role, approver_level
      FROM zappr_rule
      WHERE object_type    = @iv_object_type
        AND is_active      = @abap_true
        AND approver_level = @iv_level
      INTO ( @ev_approver_role, @ev_approver_level ).
  ENDMETHOD.

ENDCLASS.
