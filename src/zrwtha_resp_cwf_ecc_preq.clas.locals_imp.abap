CLASS agents DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    CLASS-METHODS unique
      IMPORTING
        table         TYPE tswhactor
      RETURNING
        VALUE(result) TYPE hashed_tswhactor.
ENDCLASS.

CLASS agents IMPLEMENTATION.

  METHOD unique.
    LOOP AT table ASSIGNING FIELD-SYMBOL(<item>).
      INSERT <item> INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS rule_parameter DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF all_parameter_values,
             all_process_ids            TYPE r_process_id,
             emergency_order            TYPE r_process_id,
             excluding_emergency_orders TYPE r_process_id,
             under_500                  TYPE r_value,
             between_500_and_1k         TYPE r_value,
             between_1k_and_10k         TYPE r_value,
             over_10k                   TYPE r_value,
             any_value                  TYPE r_value,
             role_00                    TYPE r_roles,
             roles_03_04_05             TYPE r_roles,
             all_roles                  TYPE r_roles,
             one_step_workflow          TYPE r_responsibility,
             three_step_workflow        TYPE r_responsibility,
             four_step_workflow         TYPE r_responsibility,
             five_step_workflow         TYPE r_responsibility,
             true                       TYPE r_abap_bool,
             false                      TYPE r_abap_bool,
             true_or_false              TYPE r_abap_bool,
           END OF all_parameter_values.

    CLASS-METHODS value
      RETURNING
        VALUE(result) TYPE all_parameter_values.

ENDCLASS.

CLASS rule_parameter IMPLEMENTATION.

  METHOD value.
    " empty ranges are used as 'include everything'
    result = VALUE #(
      all_process_ids = VALUE #( )
      emergency_order = VALUE #( ( sign = 'I' option = 'EQ' low = 'NOT' ) )
      excluding_emergency_orders  = VALUE #( ( sign = 'I' option = 'NE' low = 'NOT' ) )
      under_500 = VALUE #( ( sign = 'I' option = 'LT' low = 500 ) )
      between_500_and_1k = VALUE #( ( sign = 'I' option = 'BT' low = 500 high = 1000 ) )
      between_1k_and_10k = VALUE #( ( sign = 'I' option = 'BT' low = 1000 high = 10000 ) )
      over_10k = VALUE #( ( sign = 'I' option = 'GT' low = 10000 ) )
      any_value = VALUE #( )
      role_00 = VALUE #( ( sign = 'I' option = 'EQ' low = 'Z_GHBS:00_ANFORDERUNG' ) )
      roles_03_04_05 = VALUE #(
        ( sign = 'I' option = 'EQ' low = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' )
        ( sign = 'I' option = 'EQ' low = 'Z_GHBS:04_GENEHMIGUNG-FACHL' )
        ( sign = 'I' option = 'EQ' low = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' ) )
      all_roles = VALUE #( )
      one_step_workflow = VALUE #( ( sign = 'I' option = 'EQ' low = 'ZRWTHA_ALL' ) )
      three_step_workflow = VALUE #(
        ( sign = 'I' option = 'EQ' low = 'ZRWTHA_KAUFM' )
        ( sign = 'I' option = 'EQ' low = 'ZRWTHA_SACHLICH' )
        ( sign = 'I' option = 'EQ' low = 'ZRWTHA_WARENGRP' ) )
      four_step_workflow = VALUE #( ( sign = 'I' option = 'NE' low = 'ZRWTHA_ALL' ) )
      five_step_workflow = VALUE #( )
      true = VALUE #( ( sign = 'I' option = 'EQ' low = abap_true ) )
      false = VALUE #( ( sign = 'I' option = 'EQ' low = abap_false ) )
      true_or_false = VALUE #( ) ).
  ENDMETHOD.

ENDCLASS.
