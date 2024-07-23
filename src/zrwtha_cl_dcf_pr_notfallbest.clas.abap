CLASS zrwtha_cl_dcf_pr_notfallbest DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_dcf_runtime .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS :
      BEGIN OF mv_item_type,
        limit   TYPE string VALUE 'L',
        service TYPE string VALUE 'D',
        product TYPE string VALUE 'P',
      END OF mv_item_type.
ENDCLASS.



CLASS zrwtha_cl_dcf_pr_notfallbest IMPLEMENTATION.


  METHOD /benmsg/if_dcf_runtime~change.

    DATA: lv_itemtype       TYPE string,
          lv_price          TYPE decfloat34,
          lv_expected_value TYPE decfloat34,
          lv_matgroup       TYPE string,
          BEGIN OF ls_supplier,
            lifnr TYPE string,
            mcod1 TYPE string,
          END OF ls_supplier,
          ls_custom_panel TYPE io_helper->ts_attributes-custom_panel.


    CHECK io_helper IS BOUND.

    DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                    iv_trigger        = iv_trigger
                                                    iv_form_id        = iv_form_id
                                                    iv_event          = iv_event
                                                    io_helper         = io_helper
                                                    iv_context_status = iv_context_status
                                                    is_employee_data  = is_employee_data ).

    io_helper->get_value( EXPORTING iv_name  = 'ITEM_TYPE' IMPORTING ev_value = lv_itemtype ).
    io_helper->get_value( EXPORTING iv_name  = 'PRICE_C_PRICE' IMPORTING ev_value = lv_price ).
    io_helper->get_value( EXPORTING iv_name  = 'PRODUCT_CATEGORY' IMPORTING ev_value = lv_matgroup ).

    "SES Demo implementation
    CASE lv_itemtype.
      WHEN mv_item_type-service.
        io_helper->set_attr( EXPORTING iv_name  = 'LIMITS'              iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
        io_helper->set_attr( EXPORTING iv_name  = 'EXPECTED_VALUE'      iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
        io_helper->set_attr( EXPORTING iv_name  = 'VALUE_LIMIT'         iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
        io_helper->set_attr( EXPORTING iv_name  = 'ORDER_UNIT'          iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_true ).
        io_helper->set_attr( EXPORTING iv_name  = 'QUANTITY'            iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_true ).
        IF iv_trigger EQ 'PRICE_C' OR iv_trigger EQ 'ITEM_TYPE'.
          io_helper->get_value( EXPORTING iv_name  = 'PRICE_C_PRICE' IMPORTING ev_value = lv_price ).
          IF lv_price IS NOT INITIAL.
            io_helper->set_value( EXPORTING iv_name  = 'EXPECTED_VALUE' iv_value = lv_price ).
            io_helper->set_value( EXPORTING iv_name  = 'VALUE_LIMIT'    iv_value = lv_price ).
          ENDIF.
        ENDIF.

        IF iv_trigger EQ 'EXPECTED_VALUE'.
          io_helper->get_value( EXPORTING iv_name  = 'EXPECTED_VALUE' IMPORTING ev_value = lv_expected_value ).
          IF lv_expected_value IS NOT INITIAL.
            io_helper->set_value( EXPORTING iv_name  = 'PRICE_C_PRICE' iv_value = lv_expected_value ).
          ENDIF.
        ENDIF.
      WHEN OTHERS.
        io_helper->set_attr( EXPORTING iv_name  = 'LIMITS'              iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_true ).
        io_helper->set_attr( EXPORTING iv_name  = 'EXPECTED_VALUE'      iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_true ).
        io_helper->set_attr( EXPORTING iv_name  = 'VALUE_LIMIT'         iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_true ).
        io_helper->set_attr( EXPORTING iv_name  = 'ORDER_UNIT'          iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
        io_helper->set_attr( EXPORTING iv_name  = 'QUANTITY'            iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).

    ENDCASE.

    IF ( iv_trigger EQ 'PRODUCT_CATEGORY' OR iv_trigger EQ 'PRICE_C' ) AND lv_price IS NOT INITIAL AND lv_matgroup IS NOT INITIAL.
      IF iv_context_status = 'UPDATE'.
        lo_dcf_helper->set_ekgrp_from_matkl( iv_matkl = lv_matgroup iv_price = lv_price ).
      ENDIF.
    ENDIF.

*    io_helper->get_attr(
*      EXPORTING
*        iv_name  = 'DESCRIPTION'
*        iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-custom_panel
*      IMPORTING
*        ev_value = ls_custom_panel
*    ).
*
*    IF lv_price > 100.
*      ls_custom_panel-is_disabled = abap_true.
*    ELSE.
*      ls_custom_panel-is_disabled = abap_false.
*    ENDIF.
*
*    io_helper->set_attr(
*      EXPORTING
*        iv_name  = 'DESCRIPTION'
*        iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-custom_panel
*        iv_value = ls_custom_panel
*    ).

*    IF iv_trigger EQ 'DESCRIPTION' OR iv_trigger EQ 'PRODUCT_CATEGORY'.
*
*      io_helper->get_value( EXPORTING iv_name  = 'PRODUCT_CATEGORY' IMPORTING ev_value = lv_matgroup ).
*      IF lv_matgroup LE 29000000.
*        ls_supplier-lifnr = '100005'.
*        ls_supplier-mcod1 = 'BENEERING TEST'.
*        io_helper->set_value( EXPORTING iv_name  = 'SUPPLIER' iv_value = ls_supplier ).
*      ELSE.
*        ls_supplier-lifnr = '100006'.
*        ls_supplier-mcod1 = 'BENEERING TEST'.
*        io_helper->set_value( EXPORTING iv_name  = 'SUPPLIER' iv_value = ls_supplier ).
*      ENDIF.
*    ENDIF.

    "EDIT and DISPLAY
    DATA(lo_prod) = io_context->get_product( ).
    CHECK lo_prod IS BOUND.

    IF lo_prod->get_id( ) IS NOT INITIAL.
      io_helper->set_attr( EXPORTING  iv_name  = 'ADD_TO_CART'    iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr( EXPORTING  iv_name  = 'ATTACHMENTS_FU' iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr( EXPORTING  iv_name  = 'NOTE'           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr( EXPORTING  iv_name  = 'ITXT'           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
    ENDIF.



  ENDMETHOD.


  METHOD /benmsg/if_dcf_runtime~check.
    DATA: lv_price          TYPE decfloat34,
          lv_quantity       TYPE decfloat34,
          lv_expected_value TYPE string,
          lv_value_limit    TYPE string,
          lv_total_value    TYPE decfloat34,
          ls_message        TYPE /benmsg/cl_dcf_mdl=>ts_form_message,
          lt_docfields      TYPE /benmsg/cl_dc4_models=>tt_name_value,
          lv_appr_thresh    TYPE string.

    io_helper->get_value( EXPORTING iv_name  = 'PRICE_C_PRICE'  IMPORTING ev_value = lv_price ).
    io_helper->get_value( EXPORTING iv_name  = 'EXPECTED_VALUE' IMPORTING ev_value = lv_expected_value ).
    io_helper->get_value( EXPORTING iv_name  = 'VALUE_LIMIT'    IMPORTING ev_value = lv_value_limit ).
    io_helper->get_value( EXPORTING iv_name  = 'QUANTITY'       IMPORTING ev_value = lv_quantity ).

    DATA(lo_prod) = io_context->get_product( ).
    CHECK lo_prod IS BOUND.

    DATA(lo_doc) = lo_prod->get_doc( ).
    CHECK lo_doc IS BOUND.

    lt_docfields = lo_doc->get_doc_fields( ).
    SELECT SINGLE cust_value FROM zrwtha_cust WHERE cust = 'NOT_APPR' INTO @lv_appr_thresh.

    IF lv_quantity IS NOT INITIAL.
      lv_total_value = lv_quantity * lv_price.
      IF lv_total_value GE lv_appr_thresh.
        CLEAR ls_message.
        ls_message-type = io_helper->/benmsg/if_dcf_cons~mc_component-message-type-warning.
        ls_message-message = |Ab einem Bestellwert von { lv_appr_thresh }€ wird der Vorgang in eine Genehmigung laufen.|.
        io_helper->add_form_message( is_message = ls_message ).
      ENDIF.
    ELSE.
      IF lv_expected_value GE lv_appr_thresh OR lv_value_limit GE lv_appr_thresh.
        CLEAR ls_message.
        ls_message-type = io_helper->/benmsg/if_dcf_cons~mc_component-message-type-warning.
        ls_message-message = |Ab einem Bestellwert von { lv_appr_thresh }€ wird der Vorgang in eine Genehmigung laufen.|.
        io_helper->add_form_message( is_message = ls_message ).
      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD /benmsg/if_dcf_runtime~init.

    DATA: lv_itemtype       TYPE string,
          lv_currency       TYPE string,
          lv_expected_value TYPE string.


    CHECK io_helper IS BOUND.

    io_helper->set_attr(  EXPORTING iv_name  = 'ITEM_TYPE' iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_disabled iv_value = abap_false ).
    io_helper->get_value( EXPORTING iv_name  = 'ITEM_TYPE' IMPORTING ev_value = lv_itemtype ).

    IF lv_itemtype IS INITIAL.
      lv_itemtype = me->mv_item_type-product.

      io_helper->set_value(
        EXPORTING
          iv_name  = 'ITEM_TYPE'    " Unique component's tech name
          iv_value = lv_itemtype    " Value
      ).
    ENDIF.

    IF lv_itemtype EQ me->mv_item_type-product.
      io_helper->set_attr(  EXPORTING iv_name   = 'PRICE'                    iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
      io_helper->set_attr(  EXPORTING iv_name   = 'EXPECTED_DELIVERY_DATE'   iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
      io_helper->set_attr(  EXPORTING iv_name   = 'ORDER_UNIT'               iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
      io_helper->set_attr(  EXPORTING iv_name   = 'QUANTITY'                 iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
      io_helper->set_attr(  EXPORTING iv_name   = 'EXPECTED_VALUE'           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr(  EXPORTING iv_name   = 'VALUE_LIMIT'              iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr(  EXPORTING iv_name   = 'LIMITS'                    iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
    ELSE.
      io_helper->set_attr(  EXPORTING iv_name   = 'EXPECTED_VALUE'           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
      io_helper->set_attr(  EXPORTING iv_name   = 'VALUE_LIMIT'              iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
      io_helper->set_attr(  EXPORTING iv_name   = 'LIMITS'                    iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden iv_value = abap_false ).
    ENDIF.

    io_helper->get_value( EXPORTING iv_name  = 'CURRENCY' IMPORTING ev_value = lv_currency ).
    IF lv_currency IS INITIAL.
      io_helper->set_value( EXPORTING iv_name  = 'CURRENCY' iv_value = is_employee_data-currency ).
    ENDIF.

    "EDIT and DISPLAY
    DATA(lo_prod) = io_context->get_product( ).
    CHECK lo_prod IS BOUND.

    IF lo_prod->get_id( ) IS NOT INITIAL.
      io_helper->set_attr( EXPORTING  iv_name  = 'ADD_TO_CART'    iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr( EXPORTING  iv_name  = 'ATTACHMENTS_FU' iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr( EXPORTING  iv_name  = 'NOTE'           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_attr( EXPORTING  iv_name  = 'ITXT'           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
      io_helper->set_label( EXPORTING iv_name  = 'SECTION1'       iv_value = '').
    ENDIF.

    IF iv_event EQ io_helper->/benmsg/if_dcf_cons~mc_event-edit.
      io_helper->set_attr(  EXPORTING iv_name   = 'ITEM_TYPE'     iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_disabled  ).
    ENDIF.



  ENDMETHOD.


  METHOD /benmsg/if_dcf_runtime~submit.
    DATA: lv_itemtype TYPE string,
          lv_price    TYPE string,
          lv_matgroup TYPE string.

    DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                    iv_trigger        = iv_trigger
                                                    iv_form_id        = iv_form_id
                                                    iv_event          = iv_event
                                                    io_helper         = io_helper
                                                    iv_context_status = iv_context_status
                                                    is_employee_data  = is_employee_data ).

    io_helper->get_value( EXPORTING iv_name = 'PRICE_BRUTTO_PRICE' IMPORTING ev_value = lv_price ).
    io_helper->get_value( EXPORTING iv_name = 'PRODUCT_CATEGORY' IMPORTING ev_value = lv_matgroup ).


    io_helper->get_value( EXPORTING iv_name  = 'ITEM_TYPE' IMPORTING ev_value = lv_itemtype ).
    DATA(lo_prod) = io_context->get_product( ).
    CHECK lo_prod IS BOUND.

    DATA(lo_doc) = lo_prod->get_doc( ).
    CHECK lo_doc IS BOUND.
    IF lv_itemtype EQ mv_item_type-service.
      lo_doc->set_quantity( iv_quantity = 1 ).
    ELSEIF lv_itemtype EQ mv_item_type-product.
      lo_doc->set_product_type( iv_product_type = '' ).
    ENDIF.

    IF iv_context_status = 'NEW' AND lv_price IS NOT INITIAL AND lv_matgroup IS NOT INITIAL.
      TRY.
          lo_dcf_helper->set_ekgrp_from_matkl( iv_matkl = lv_matgroup iv_price = CONV #( lv_price ) ).
        CATCH cx_sy_conversion_no_number.
          " its fine to do nothing here
      ENDTRY.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
