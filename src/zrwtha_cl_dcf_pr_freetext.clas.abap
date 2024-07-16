CLASS zrwtha_cl_dcf_pr_freetext DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_dcf_runtime .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.

ENDCLASS.



CLASS zrwtha_cl_dcf_pr_freetext IMPLEMENTATION.
  METHOD /benmsg/if_dcf_runtime~change.
    DATA lv_hse_checkbox TYPE abap_bool.
*          lv_price        TYPE string,
    DATA lv_price        TYPE decfloat34.
    DATA lv_hse_resp     TYPE abap_bool.
    DATA lv_matgroup     TYPE string.
    " TODO: variable is never used (ABAP cleaner)
    DATA: BEGIN OF ls_crud_imp_resp,
            matgroup     TYPE string,
            brutto_preis TYPE string,
          END OF ls_crud_imp_resp.
    " TODO: variable is never used (ABAP cleaner)
    DATA: BEGIN OF ls_crud_exp_resp,
            zustaendigkeit TYPE string,
          END OF ls_crud_exp_resp.
    DATA lv_non_contract TYPE abap_bool.
    DATA ls_event        TYPE /benmsg/cl_dcf_change_bdi_h=>ts_event.
    DATA lv_rfx_process  TYPE string.
    DATA lv_external_id  TYPE string.
    DATA lv_uvgo         TYPE string.
*          BEGIN OF ls_zrwtha_cust,
*            cust           TYPE string,
*            cust_min_range TYPE string,
*            cust_max_range TYPE string,
*            cust_value     TYPE string,
*          END OF ls_zrwtha_cust,
*          lt_zrwtha_cust LIKE TABLE OF ls_zrwtha_cust WITH EMPTY KEY,
    DATA lt_zrwtha_cust  TYPE STANDARD TABLE OF zrwtha_cust WITH EMPTY KEY.
    DATA ls_zrwtha_cust  LIKE LINE OF lt_zrwtha_cust.
    DATA lv_desc         TYPE string.
    DATA lv_note         TYPE string.

    DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                    iv_trigger        = iv_trigger
                                                    iv_form_id        = iv_form_id
                                                    iv_event          = iv_event
                                                    io_helper         = io_helper
                                                    iv_context_status = iv_context_status
                                                    is_employee_data  = is_employee_data ).

    io_helper->get_value( EXPORTING iv_name  = 'HSE_ASE'
                          IMPORTING ev_value = lv_hse_checkbox ).
    io_helper->get_value( EXPORTING iv_name  = 'HSE_VERGABE'
                          IMPORTING ev_value = lv_uvgo ).
    io_helper->get_value( EXPORTING iv_name  = 'NON_CONTRACT'
                          IMPORTING ev_value = lv_non_contract ).
    io_helper->get_value( EXPORTING iv_name  = 'PRICE_NETTO_PRICE'
                          IMPORTING ev_value = lv_price ).
    io_helper->get_value( EXPORTING iv_name  = 'PRODUCT_CATEGORY'
                          IMPORTING ev_value = lv_matgroup ).
    io_helper->get_value( EXPORTING iv_name  = 'DESCRIPTION'
                          IMPORTING ev_value = lv_desc ).
    io_helper->get_value( EXPORTING iv_name  = 'NOTE'
                          IMPORTING ev_value = lv_note ).

    " Anzeige weiterer Felder Zuständigkeit HSE
    IF lv_hse_checkbox IS NOT INITIAL.
      io_helper->set_attr( iv_name  = 'HSE_ASE_INPUT'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                           iv_value = abap_false ).
      io_helper->set_attr( iv_name  = 'ATTACHMENTS_FU'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                           iv_value = abap_false ).
      io_helper->set_attr( iv_name  = 'ATTACHMENTS_FU'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_required
                           iv_value = abap_true ).
    ELSE.
      io_helper->set_attr( iv_name  = 'HSE_ASE_INPUT'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                           iv_value = abap_true ).
      io_helper->set_attr( iv_name  = 'ATTACHMENTS_FU'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                           iv_value = abap_true ).
      io_helper->set_attr( iv_name  = 'ATTACHMENTS_FU'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_required
                           iv_value = abap_false ).
    ENDIF.

    " Anzeige Begründung für Anforderung ohne Vertrag
    IF lv_non_contract = abap_true.
      io_helper->set_attr( iv_name  = 'NON_CONTRACT_BEGR'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                           iv_value = abap_false ).
    ELSE.
      io_helper->set_attr( iv_name  = 'NON_CONTRACT_BEGR'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                           iv_value = abap_true ).
    ENDIF.

    " Entwicklung Zuständigkeit und Anzeige Ausschließlichkeit + Vergabeverordnung
    IF ( iv_trigger = 'PRODUCT_CATEGORY' OR iv_trigger = 'PRICE_NETTO' OR iv_trigger = 'HSE_VERGABE' ) AND lv_price IS NOT INITIAL AND lv_matgroup IS NOT INITIAL.
      lo_dcf_helper->get_hse_ekgrp_from_matkl_price( EXPORTING iv_matkl = lv_matgroup
                                                               iv_price = CONV #( lv_price )
                                                     IMPORTING
*                                                               ev_ekgrp =
                                                               ev_hse   = lv_hse_resp ).

      IF iv_context_status = 'UPDATE'.
        TRY.
            lo_dcf_helper->set_ekgrp_from_matkl( iv_matkl = lv_matgroup
                                                 iv_price = CONV #( lv_price ) ).
          CATCH cx_sy_conversion_no_number.
            " its fine to do nothing here
        ENDTRY.
      ENDIF.
    ENDIF.

*    IF iv_context_status EQ 'NEW'
    IF lv_matgroup IS INITIAL OR lv_price IS INITIAL OR lv_uvgo IS INITIAL.
      RETURN.
    ENDIF.

    CASE lv_hse_resp.
      WHEN abap_true.
        io_helper->set_attr( iv_name  = 'ADD_TO_CART'
                             iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                             iv_value = abap_true ).
        io_helper->set_attr( iv_name  = 'PROD_SECTION_1'
                             iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                             iv_value = abap_true ).
        io_helper->set_attr( iv_name  = 'CREATE_RFX'
                             iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                             iv_value = abap_false ).

        ls_event-type = 'NAVIGATE_RFQ_CREATE'.

        IF lv_uvgo IS NOT INITIAL AND lv_price IS NOT INITIAL.
          SELECT SINGLE * FROM zrwtha_cust
            WHERE cust            = @lv_uvgo
              AND cust_min_range  < @lv_price
              AND cust_max_range >= @lv_price
            INTO CORRESPONDING FIELDS OF @ls_zrwtha_cust.
          lv_rfx_process = ls_zrwtha_cust-cust_value.

          " fallback if no label found
          IF lv_rfx_process IS INITIAL.
            lv_rfx_process = '/BENMSG/OTRDCF/ADD_TO_BASKET'.
          ENDIF.

          io_helper->set_label( iv_name  = 'CREATE_RFX'
                                iv_value = lv_rfx_process ).
        ENDIF.

*          IF lv_rfx_process EQ 'DIK'.
*            ls_event-confirmation = 'Wenn Sie forfahren wird der Freitext-Prozess verlassen und zur Anlage eines Direktkaufs weitergeleitet.'.
*          ELSEIF lv_rfx_process EQ 'PEV'.
*            ls_event-confirmation = 'Wenn Sie forfahren wird der Freitext-Prozess verlassen und zur Anlage eine Preisanfrage weitergeleitet.'.
*          ELSE.
*            CLEAR ls_event-confirmation.
*          ENDIF.

        SELECT SINGLE cust_value FROM zrwtha_cust WHERE cust = @lv_rfx_process INTO @lv_external_id.
        READ TABLE ls_event-params REFERENCE INTO DATA(lr_param) WITH KEY name = 'externalId'.
        IF sy-subrc = 0.
          lr_param->value = lv_external_id.
        ELSE.
          APPEND INITIAL LINE TO ls_event-params REFERENCE INTO lr_param.
          lr_param->name  = 'externalId'.
          lr_param->value = lv_external_id.
        ENDIF.

        READ TABLE ls_event-params REFERENCE INTO lr_param WITH KEY name = 'rfqName'.
        IF sy-subrc = 0.
          lr_param->value = lv_desc.
        ELSE.
          APPEND INITIAL LINE TO ls_event-params REFERENCE INTO lr_param.
          lr_param->name  = 'rfqName'.
          lr_param->value = lv_desc.
        ENDIF.

        READ TABLE ls_event-params REFERENCE INTO lr_param WITH KEY name = 'rfqDescription'.
        IF sy-subrc = 0.
          lr_param->value = lv_desc.
        ELSE.
          APPEND INITIAL LINE TO ls_event-params REFERENCE INTO lr_param.
          lr_param->name  = 'rfqDescription'.
          lr_param->value = lv_desc.
        ENDIF.

        READ TABLE ls_event-params REFERENCE INTO lr_param WITH KEY name = 'DCF_UVGO'.
        IF sy-subrc = 0.
          lr_param->value = lv_uvgo.
        ELSE.
          APPEND INITIAL LINE TO ls_event-params REFERENCE INTO lr_param.
          lr_param->name  = 'DCF_UVGO'.
          lr_param->value = lv_uvgo.
        ENDIF.

        READ TABLE ls_event-params REFERENCE INTO lr_param WITH KEY name = 'DCF_MATGROUP'.
        IF sy-subrc = 0.
          lr_param->value = lv_matgroup.
        ELSE.
          APPEND INITIAL LINE TO ls_event-params REFERENCE INTO lr_param.
          lr_param->name  = 'DCF_MATGROUP'.
          lr_param->value = lv_matgroup.
        ENDIF.

        READ TABLE ls_event-params REFERENCE INTO lr_param WITH KEY name = 'DCF_NOTE'.
        IF sy-subrc = 0.
          lr_param->value = lv_note.
        ELSE.
          APPEND INITIAL LINE TO ls_event-params REFERENCE INTO lr_param.
          lr_param->name  = 'DCF_NOTE'.
          lr_param->value = lv_note.
        ENDIF.

        io_helper->set_event( iv_name         = 'CREATE_RFX'    " Component name
                              iv_type         = ls_event-type    " Event type
                              it_params       = ls_event-params    " Event parameters
                              iv_confirmation = ls_event-confirmation ). " Event confirmation
        io_helper->set_attr( iv_name  = 'INFO_TEXT_ZEK'
                             iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                             iv_value = abap_true ).

      WHEN OTHERS.
        IF iv_trigger = 'PRODUCT_CATEGORY' OR iv_trigger = 'PRICE_NETTO' OR iv_trigger = 'HSE_VERGABE'.
          io_helper->set_attr( iv_name  = 'ADD_TO_CART'
                               iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                               iv_value = abap_false ).
          io_helper->set_attr( iv_name  = 'PROD_SECTION_1'
                               iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                               iv_value = abap_false ).
          io_helper->set_attr( iv_name  = 'CREATE_RFX'
                               iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                               iv_value = abap_true ).
          io_helper->set_attr( iv_name  = 'INFO_TEXT_ZEK'
                               iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                               iv_value = abap_false ).
        ENDIF.

    ENDCASE.
  ENDMETHOD.


  METHOD /benmsg/if_dcf_runtime~check.
  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~init.
    " right now all of this is only relevant when opening a basket and not for the first event=init
    IF iv_event <> 'EDIT'.
      RETURN.
    ENDIF.

    DATA lv_price    TYPE decfloat34.
    DATA lv_matgroup TYPE string.
    DATA lv_hse_resp TYPE abap_bool.
    DATA lv_uvgo     TYPE string.

    DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                    iv_trigger        = iv_trigger
                                                    iv_form_id        = iv_form_id
                                                    iv_event          = iv_event
                                                    io_helper         = io_helper
                                                    iv_context_status = iv_context_status
                                                    is_employee_data  = is_employee_data ).

    " TODO this can be removed after https://mycatalogcloud.atlassian.net/browse/CDEV-9665 is solved
    DATA(lo_prod) = io_context->get_product( ).
    IF lo_prod IS NOT BOUND.
      RETURN.
    ENDIF.
    IF lo_prod->get_id( ) IS NOT INITIAL.
      io_helper->set_attr( iv_name = 'ADD_TO_CART'
                           iv_attr = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden ).
    ENDIF.

    io_helper->get_value( EXPORTING iv_name  = 'HSE_VERGABE'
                          IMPORTING ev_value = lv_uvgo ).
    io_helper->get_value( EXPORTING iv_name  = 'PRICE_NETTO_PRICE'
                          IMPORTING ev_value = lv_price ).
    io_helper->get_value( EXPORTING iv_name  = 'PRODUCT_CATEGORY'
                          IMPORTING ev_value = lv_matgroup ).
    lo_dcf_helper->get_hse_ekgrp_from_matkl_price( EXPORTING iv_matkl = lv_matgroup
                                                             iv_price = CONV #( lv_price )
                                                   IMPORTING ev_hse   = lv_hse_resp ).

    " fix that PROD_SECTION_1 is not visible anymore in the basket
    IF lv_matgroup IS NOT INITIAL AND lv_price IS NOT INITIAL AND lv_uvgo IS NOT INITIAL AND lv_hse_resp = abap_false.
      io_helper->set_attr( iv_name  = 'PROD_SECTION_1'
                           iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                           iv_value = abap_false ).
    ENDIF.
  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~submit.
    DATA lv_price    TYPE string.
    DATA lv_matgroup TYPE string.

    DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                    iv_trigger        = iv_trigger
                                                    iv_form_id        = iv_form_id
                                                    iv_event          = iv_event
                                                    io_helper         = io_helper
                                                    iv_context_status = iv_context_status
                                                    is_employee_data  = is_employee_data ).

    io_helper->get_value( EXPORTING iv_name  = 'PRICE_NETTO_PRICE'
                          IMPORTING ev_value = lv_price ).
    io_helper->get_value( EXPORTING iv_name  = 'PRODUCT_CATEGORY'
                          IMPORTING ev_value = lv_matgroup ).

    IF iv_context_status = 'NEW' AND lv_price IS NOT INITIAL AND lv_matgroup IS NOT INITIAL.
      TRY.
          lo_dcf_helper->set_ekgrp_from_matkl( iv_matkl = lv_matgroup
                                               iv_price = CONV #( lv_price ) ).
        CATCH cx_sy_conversion_no_number.
          " its fine to do nothing here
      ENDTRY.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
