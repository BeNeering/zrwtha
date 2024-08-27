CONSTANTS: BEGIN OF responsibility,
             all            TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_ALL',
             tech           TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_PG_TECHNISCH',
             kauf           TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_KAUFM',
             material_group TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_WARENGRP',
             sach           TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_SACHLICH',
           END OF responsibility.

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


CLASS requester_role_ranges DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF role_ranges,
             role_00        TYPE r_roles,
             roles_03_04_05 TYPE r_roles,
           END OF role_ranges.

    CLASS-METHODS value
      RETURNING
        VALUE(result) TYPE role_ranges.

ENDCLASS.

CLASS requester_role_ranges IMPLEMENTATION.

  METHOD value.
    result = VALUE #(
      role_00 = VALUE #( ( sign = 'I' option = 'EQ' low = 'Z_GHBS:00_ANFORDERUNG' ) )
      roles_03_04_05 = VALUE #(
        ( sign = 'I' option = 'EQ' low = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' )
        ( sign = 'I' option = 'EQ' low = 'Z_GHBS:04_GENEHMIGUNG-FACHL' )
        ( sign = 'I' option = 'EQ' low = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' ) ) ).
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
    result = NEW #( CONV #( VALUE #( item_accounts[ preq_item = item-preq_item ]-wbs_element+5(6) OPTIONAL ) ) ).
  ENDMETHOD.

  METHOD internal_value.
    result = |{ cost_center ALPHA = IN }|.
  ENDMETHOD.

  METHOD external_value.
    result = |{ cost_center ALPHA = OUT }|.
  ENDMETHOD.

  METHOD from_requester.
    DATA: BEGIN OF request,
            user LIKE sy-uname,
          END OF request,
          BEGIN OF response,
            kostl TYPE kostl,
          END OF response.

    request-user = requester->user_name.

    customer_wf_customizing->get_external_data(
      EXPORTING
        iv_object   = 'BEN_DATA'
        iv_action   = 'KostlFromUser'
        iv_data     = request
      IMPORTING
        ev_data     = response ).

    TRY.
        result = NEW #( response-kostl ).
      CATCH invalid_cost_center INTO DATA(error).
        RAISE EXCEPTION TYPE missing_user_configuration
          EXPORTING
            previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD from_item_or_requester.
    TRY.
        result = cost_center=>from_purchase_requisition_item( item = item item_accounts = item_accounts ).
      CATCH invalid_cost_center.
        result = cost_center=>from_requester( requester = requester customer_wf_customizing = customer_wf_customizing ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.



CLASS requester IMPLEMENTATION.

  METHOD constructor.
    IF user_name IS INITIAL.
      RAISE EXCEPTION TYPE empty_requester.
    ENDIF.
    me->user_name = user_name.
  ENDMETHOD.

  METHOD from_purchase_requisition_item.
    DATA(purchase_requsition_requester) = VALUE #( item[ delete_ind = abap_false ]-preq_name OPTIONAL ).
    DATA(mycart_creator) = mycart-created_by.
    IF purchase_requsition_requester IS INITIAL AND mycart_creator IS INITIAL.
      RAISE EXCEPTION TYPE empty_requester.
    ELSE.
      result = NEW requester( COND #(
        WHEN purchase_requsition_requester IS NOT INITIAL
        THEN purchase_requsition_requester
        ELSE mycart_creator ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.



CLASS material_group IMPLEMENTATION.

  METHOD constructor.
    IF material_group IS INITIAL.
      RAISE EXCEPTION TYPE empty_material_group.
    ENDIF.
    me->material_group = material_group.
  ENDMETHOD.

  METHOD requires_approval.
    IF me->approver(
      cost_center = cost_center
      customer_wf_customizing = customer_wf_customizing ) IS NOT INITIAL.
      result = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD approver.
    DATA: BEGIN OF request,
            kostl TYPE kostl,
            matkl TYPE matkl,
          END OF request,
          BEGIN OF response,
            freig TYPE xubname,
          END OF response.

    request-kostl = cost_center->internal_value( ).
    request-matkl = me->material_group.

    customer_wf_customizing->get_external_data(
      EXPORTING
        iv_object   = 'BEN_DATA'
        iv_action   = 'FreigFromKostlMatkl'
        iv_data     = request
      IMPORTING
        ev_data     = response ).
    result = response-freig.
  ENDMETHOD.

ENDCLASS.
