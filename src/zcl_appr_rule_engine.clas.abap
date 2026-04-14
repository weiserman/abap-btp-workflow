CLASS zcl_appr_rule_engine DEFINITION
  PUBLIC FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

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

    CLASS-METHODS evaluate_conditions
      IMPORTING iv_rule_id      TYPE sysuuid_x16
                it_context      TYPE ty_context
      RETURNING VALUE(rv_match) TYPE abap_bool.

  PRIVATE SECTION.

    CLASS-METHODS compare
      IMPORTING iv_operator     TYPE c
                iv_context_val  TYPE c
                iv_low          TYPE c
                iv_high         TYPE c
      RETURNING VALUE(rv_match) TYPE abap_bool.

ENDCLASS.


CLASS zcl_appr_rule_engine IMPLEMENTATION.

  METHOD determine_agent.

    SELECT rule_id, priority, agent_type, agent_id, rule_description
      FROM zappr_rule
      WHERE object_type    = @iv_object_type
        AND approver_level = @iv_level
        AND is_active      = @abap_true
      ORDER BY priority
      INTO TABLE @DATA(lt_rules).

    IF lt_rules IS INITIAL.
      RAISE EXCEPTION NEW zcx_appr_no_rule_found(
        object_type = iv_object_type
        level       = iv_level ).
    ENDIF.

    LOOP AT lt_rules INTO DATA(ls_rule).
      IF evaluate_conditions( iv_rule_id = ls_rule-rule_id
                              it_context = it_context ).
        rs_result = VALUE #(
          agent_type  = ls_rule-agent_type
          agent_id    = ls_rule-agent_id
          rule_id     = ls_rule-rule_id
          description = ls_rule-rule_description ).
        RETURN.
      ENDIF.
    ENDLOOP.

    RAISE EXCEPTION NEW zcx_appr_no_rule_found(
      object_type = iv_object_type
      level       = iv_level ).

  ENDMETHOD.


  METHOD evaluate_conditions.

    SELECT field_name, operator, value_low, value_high
      FROM zappr_condition
      WHERE rule_uuid = @iv_rule_id
      INTO TABLE @DATA(lt_conditions).

    IF lt_conditions IS INITIAL.
      rv_match = abap_true.
      RETURN.
    ENDIF.

    LOOP AT lt_conditions INTO DATA(ls_cond).

      READ TABLE it_context
        WITH TABLE KEY field_name = ls_cond-field_name
        INTO DATA(ls_ctx).

      IF sy-subrc <> 0.
        rv_match = abap_false.
        RETURN.
      ENDIF.

      IF compare( iv_operator    = ls_cond-operator
                  iv_context_val = ls_ctx-field_value
                  iv_low         = ls_cond-value_low
                  iv_high        = ls_cond-value_high ) = abap_false.
        rv_match = abap_false.
        RETURN.
      ENDIF.

    ENDLOOP.

    rv_match = abap_true.

  ENDMETHOD.


  METHOD compare.

    DATA lv_ctx_num    TYPE decfloat34.
    DATA lv_low_num    TYPE decfloat34.
    DATA lv_high_num   TYPE decfloat34.
    DATA lv_is_numeric TYPE abap_bool VALUE abap_false.

    TRY.
        lv_ctx_num = iv_context_val.
        lv_low_num = iv_low.
        IF iv_high IS NOT INITIAL.
          lv_high_num = iv_high.
        ENDIF.
        lv_is_numeric = abap_true.
      CATCH cx_sy_conversion_no_number.
        lv_is_numeric = abap_false.
    ENDTRY.

    CASE iv_operator.

      WHEN 'EQ'.
        IF lv_is_numeric = abap_true.
          rv_match = xsdbool( lv_ctx_num = lv_low_num ).
        ELSE.
          rv_match = xsdbool( to_upper( iv_context_val ) = to_upper( iv_low ) ).
        ENDIF.

      WHEN 'NE'.
        IF lv_is_numeric = abap_true.
          rv_match = xsdbool( lv_ctx_num <> lv_low_num ).
        ELSE.
          rv_match = xsdbool( to_upper( iv_context_val ) <> to_upper( iv_low ) ).
        ENDIF.

      WHEN 'GT'.
        rv_match = xsdbool( lv_is_numeric = abap_true AND lv_ctx_num > lv_low_num ).

      WHEN 'GE'.
        rv_match = xsdbool( lv_is_numeric = abap_true AND lv_ctx_num >= lv_low_num ).

      WHEN 'LT'.
        rv_match = xsdbool( lv_is_numeric = abap_true AND lv_ctx_num < lv_low_num ).

      WHEN 'LE'.
        rv_match = xsdbool( lv_is_numeric = abap_true AND lv_ctx_num <= lv_low_num ).

      WHEN 'BT'.
        rv_match = xsdbool( lv_is_numeric = abap_true
                            AND lv_ctx_num >= lv_low_num
                            AND lv_ctx_num <= lv_high_num ).

      WHEN 'CP'.
        rv_match = xsdbool( to_upper( iv_context_val ) CP to_upper( iv_low ) ).

      WHEN OTHERS.
        rv_match = abap_false.

    ENDCASE.

  ENDMETHOD.

ENDCLASS.
