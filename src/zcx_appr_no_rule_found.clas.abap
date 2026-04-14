CLASS zcx_appr_no_rule_found DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA object_type TYPE c LENGTH 30 READ-ONLY.
    DATA level       TYPE i READ-ONLY.

    METHODS constructor
      IMPORTING object_type TYPE c OPTIONAL
                level       TYPE i OPTIONAL
                previous    TYPE REF TO cx_root OPTIONAL.

    METHODS if_message~get_text REDEFINITION.

ENDCLASS.


CLASS zcx_appr_no_rule_found IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->object_type = object_type.
    me->level       = level.
  ENDMETHOD.

  METHOD if_message~get_text.
    result = |No matching approval rule for { object_type } level { level }|.
  ENDMETHOD.

ENDCLASS.
