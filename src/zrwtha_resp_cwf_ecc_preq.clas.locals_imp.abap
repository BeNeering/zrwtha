CLASS responsibility DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      all            TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_ALL',
      technical      TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_PG_TECHNISCH',
      purchasing     TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_KAUFM',
      material_group TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_WARENGRP',
      subject_matter TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_SACHLICH'.

    METHODS constructor
      IMPORTING
        value TYPE /benmsg/swf_bd_step-responsibility
      RAISING
        invalid_resposibility.

    METHODS is_material_group_related
      RETURNING
        VALUE(result) TYPE abap_bool.

    DATA value TYPE /benmsg/swf_bd_step-responsibility READ-ONLY.
ENDCLASS.

CLASS responsibility IMPLEMENTATION.

  METHOD constructor.
    CASE value.
      WHEN  me->all
      OR    me->technical
      OR    me->purchasing
      OR    me->material_group
      OR    me->subject_matter.
        me->value = value.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE invalid_resposibility.
    ENDCASE.
  ENDMETHOD.

  METHOD is_material_group_related.
    IF me->value = me->material_group.
      result = abap_true.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


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
    DATA(purchase_requisition_requester) = VALUE #( item[ delete_ind = abap_false ]-preq_name OPTIONAL ).
    DATA(mycart_creator) = mycart-created_by.
    IF purchase_requisition_requester IS INITIAL AND mycart_creator IS INITIAL.
      RAISE EXCEPTION TYPE empty_requester.
    ELSE.
      result = NEW requester( COND #(
        WHEN purchase_requisition_requester IS NOT INITIAL
        THEN purchase_requisition_requester
        ELSE mycart_creator ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
