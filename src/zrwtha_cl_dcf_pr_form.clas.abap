CLASS zrwtha_cl_dcf_pr_form DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_dcf_runtime .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_dcf_pr_form IMPLEMENTATION.
  METHOD /benmsg/if_dcf_runtime~change.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~check.
    " CHANGE ADDED BY BARTHO BEFORE VAC, COMMENT OUT IF CAUSING ISSUES
    " NOT > 1.000,00 €    Nicht erlaubt -> Meldung: "Beschaffung nicht erlaubt, bitte Anforderung aufteilen." Bedarf darf nicht zu BANF werden
    " CAT > 3.000,00 €    Nicht erlaubt -> Meldung: "Beschaffung nicht erlaubt, bitte Anforderung aufteilen." Bedarf darf nicht zu BANF werden
    DATA lv_not      TYPE abap_bool                           VALUE abap_false.
    DATA lv_cat      TYPE abap_bool                           VALUE abap_false.
    DATA ls_message  TYPE /benmsg/cl_dcf_mdl=>ts_form_message.
    DATA lv_pr_value TYPE decfloat34.

    DATA(lt_products) = io_context->get_my_cart( )->get_products( ).
    LOOP AT lt_products ASSIGNING FIELD-SYMBOL(<prod>).
      DATA(index) = sy-tabix.
      TRY.
          DATA(lv_line_value) = <prod>->get_price( ) / <prod>->get_price_quantity( ) * <prod>->get_quantity( ).
          lv_pr_value = lv_pr_value + lv_line_value.
        CATCH cx_sy_zerodivide.
          " its fine to do nothing here
      ENDTRY.

      DATA(lv_current_product_type) = <prod>->get_doc( )->get_doc_field( iv_name = 'PROCESS_ID' ).
      IF index = 1.
        DATA(first_product_type) = lv_current_product_type.
        DATA(material_group) = <prod>->get_material_group( )-id.
        DATA(purchasing_grp) = <prod>->get_purchasing_grp( )-id.
      ENDIF.
      IF lv_current_product_type <> first_product_type.
        DATA(product_types_differ) = abap_true.
      ENDIF.
      IF lv_current_product_type = 'NOT'.
        lv_not = abap_true.
      ELSEIF lv_current_product_type = 'CAT'.
        lv_cat = abap_true.
      ENDIF.

    ENDLOOP.

    " TODO add to customizing table later
    IF ( lv_pr_value > 1000 AND lv_not = abap_true ) OR ( lv_pr_value > 3000 AND lv_cat = abap_true ).
      ls_message-type = io_helper->/benmsg/if_dcf_cons~mc_component-message-type-error.
      ls_message-message = |Beschaffung nicht erlaubt, bitte Anforderung aufteilen.|.
      io_helper->add_form_message( is_message = ls_message ).
    ENDIF.
    " END CHANGE

    IF product_types_differ = abap_true.
      ls_message-type    = io_helper->/benmsg/if_dcf_cons~mc_component-message-type-error.
      ls_message-message = |Unterschiedliche Prozess IDs im Warenkorb nicht erlaubt.|.
      io_helper->add_form_message( is_message = ls_message ).
    ENDIF.

    " Adjust Document Type
    " TODO add to customizing table later
    DATA(switch_bsart) = abap_false.
    IF lv_pr_value > 10000 AND ( lv_current_product_type = 'FRE' OR lv_current_product_type = 'RVA' OR lv_current_product_type = 'DIK' OR lv_current_product_type = 'PEV' ).
      switch_bsart = abap_true.
    ELSEIF lv_current_product_type = 'FRE'.
      " TODO: variable is assigned but never used (ABAP cleaner)
      DATA lv_ekgrp TYPE ekgrp.
      DATA lv_hse   TYPE xfeld.
      DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                      iv_trigger        = iv_trigger
                                                      iv_form_id        = iv_form_id
                                                      iv_event          = iv_event
                                                      io_helper         = io_helper
                                                      iv_context_status = iv_context_status
                                                      is_employee_data  = is_employee_data ).
      lo_dcf_helper->get_hse_ekgrp_from_matkl( EXPORTING iv_matkl = material_group
                                               IMPORTING ev_ekgrp = lv_ekgrp
                                                         ev_hse   = lv_hse ).
      IF lv_hse IS INITIAL.
        switch_bsart = abap_true.
      ENDIF.

    ENDIF.

    IF switch_bsart = abap_true AND purchasing_grp IS NOT INITIAL.
      CASE purchasing_grp.
        WHEN '100'.
          DATA(bsart) = CONV char4( 'ZNB' ).
        WHEN '400'.
          bsart = 'ZNW'.
        WHEN '500'.
          bsart = 'ZFM'.
      ENDCASE.

      IF bsart IS NOT INITIAL.
        io_context->get_my_cart( )->set_document_type( iv_document_type = bsart ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~init.

    DATA(lo_cart) = io_context->get_my_cart( ).
    IF lo_cart IS BOUND.
      DATA(lt_prod) = lo_cart->get_products( ).
    ENDIF.

    " if we open a PR we need to set the org data on header lvl since we cant use scr/target mapping due its on position lvl
    IF lo_cart->get_obj_id( ) IS NOT INITIAL AND lt_prod IS NOT INITIAL.
      TRY.
          DATA(lt_tech_txt) = lt_prod[ 1 ]->get_doc( )->get_tech_txt( ).
          io_helper->set_value( iv_name  = 'PROJ_NUMBER'  iv_value = lt_tech_txt[ key = 'PROJ_NUMBER' ]-value[ 1 ] ).

        CATCH cx_sy_itab_line_not_found.
          " its fine to do nothing here
      ENDTRY.
    ENDIF.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~submit.
    DATA lv_str TYPE string.

    DATA(lo_card) = io_context->get_my_cart( ).
    IF lo_card IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(lt_prod) = lo_card->get_products( ).
    LOOP AT lt_prod ASSIGNING FIELD-SYMBOL(<line>).

      DATA(lo_doc) = <line>->get_doc( ).
      " map header data to item since on header level here are no additional fields, later on this data will be reused in zrwtha_cl_wsi_obj_ecc_pr
      DATA(lt_tech_text) = lo_doc->get_tech_txt( ).

      io_helper->get_value( EXPORTING iv_name  = 'PROJ_NUMBER'
                            IMPORTING ev_value = lv_str ).
      zrwtha_cl_dcf_helper=>change_tech_txt( EXPORTING iv_name     = 'PROJ_NUMBER'
                                                       iv_value    = lv_str
                                             CHANGING  ct_tech_txt = lt_tech_text ).

      lo_doc->set_tech_txt( lt_tech_text ).

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
