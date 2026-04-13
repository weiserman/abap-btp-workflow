CLASS lhc_objecttype DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ObjectType RESULT result.
ENDCLASS.

CLASS lhc_objecttype IMPLEMENTATION.
  METHOD get_global_authorizations.
    result = VALUE #(
      %create = if_abap_behv=>auth-allowed
      %update = if_abap_behv=>auth-allowed
      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.
ENDCLASS.
