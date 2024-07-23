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


CLASS cost_center IMPLEMENTATION.

  METHOD constructor.
    IF cost_center IS INITIAL.
      RAISE EXCEPTION TYPE invalid_cost_center.
    ENDIF.
    me->cost_center = cost_center.
  ENDMETHOD.

  METHOD from_purchase_requisition_item.
    DATA(psp) = VALUE #( item_accounts[ preq_item = item-preq_item ]-wbs_element+5(6) OPTIONAL ).
    TRY.
        result = NEW #( CONV #( psp ) ).
      CATCH invalid_cost_center.
        result = cost_center=>from_user( username = item-created_by endpoint = endpoint ).
    ENDTRY.
  ENDMETHOD.

  METHOD from_user.
    DATA: BEGIN OF ls_crud_imp,
            user LIKE sy-uname,
          END OF ls_crud_imp,
          BEGIN OF ls_crud_exp,
            kostl TYPE kostl,
          END OF ls_crud_exp.

    ls_crud_imp-user = username.

    endpoint->get_external_data( EXPORTING iv_action   = 'KostlFromUser'
                                           iv_object   = 'BEN_DATA'
                                           iv_data     = ls_crud_imp
                                 IMPORTING ev_data     = ls_crud_exp ).

    TRY.
        result = NEW #( ls_crud_exp-kostl ).
      CATCH invalid_cost_center INTO DATA(error).
        RAISE EXCEPTION TYPE missing_user_configuration
          EXPORTING
            previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD internal_value.
    result = |{ cost_center ALPHA = IN }|.
  ENDMETHOD.

  METHOD external_value.
    result = |{ cost_center ALPHA = OUT }|.
  ENDMETHOD.

ENDCLASS.


CLASS fake_endpoint DEFINITION CREATE PUBLIC INHERITING FROM /benmsg/cl_wsi_obj_cust_data.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS get_external_data REDEFINITION.
    DATA cost_center TYPE kostl.

ENDCLASS.

CLASS fake_endpoint IMPLEMENTATION.

  METHOD constructor.
    super->constructor(
      iv_customer_id = 'TEST'
      iv_cust_sys_id = 'TEST'
      iv_remote_sys  = 'TEST' ).
  ENDMETHOD.

  METHOD get_external_data.
    DATA: BEGIN OF result,
            kostl TYPE kostl,
          END OF result.
    result-kostl = me->cost_center.
    ev_data = result.
  ENDMETHOD.

ENDCLASS.
