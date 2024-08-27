CLASS zrwtha_cl_dcf_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING io_context        TYPE REF TO /benmsg/cl_dcf_ctx
                iv_trigger        TYPE /benmsg/edcf_component_name
                iv_form_id        TYPE /benmsg/edcf_form_id
                iv_event          TYPE /benmsg/edcf_event
                io_helper         TYPE REF TO /benmsg/cl_dcf_change_bdi_h
                iv_context_status TYPE /benmsg/edcf_context_status
                is_employee_data  TYPE /benmsg/cl_dc4_models=>ts_employee_data.

    METHODS get_item_defaults.
    METHODS is_prod_and_doc_bound RETURNING VALUE(rv_result) TYPE abap_bool.

    METHODS set_ekgrp_from_matkl IMPORTING iv_matkl TYPE string
                                           iv_price TYPE decfloat34.

    METHODS get_matkl_from_eclass.
    METHODS get_stock.

    METHODS get_hse_ekgrp_from_matkl IMPORTING iv_matkl TYPE string
                                     EXPORTING ev_ekgrp TYPE ekgrp
                                               ev_hse   TYPE xfeld.

    METHODS get_hse_ekgrp_from_matkl_price IMPORTING iv_matkl TYPE string
                                                     iv_price TYPE decfloat34
                                           EXPORTING ev_ekgrp TYPE ekgrp
                                                     ev_hse   TYPE xfeld.

    CLASS-METHODS change_tech_txt
      IMPORTING iv_name     TYPE string
                iv_value    TYPE string
      CHANGING  ct_tech_txt TYPE /benmsg/cl_dc4_models=>tth_tech_txt.

  PROTECTED SECTION.
    DATA: mo_context        TYPE REF TO /benmsg/cl_dcf_ctx,
          mv_trigger        TYPE /benmsg/edcf_component_name,
          mv_form_id        TYPE /benmsg/edcf_form_id,
          mo_helper         TYPE REF TO /benmsg/cl_dcf_change_bdi_h,
          mv_event          TYPE /benmsg/edcf_event,
          mo_ws             TYPE REF TO /benmsg/cl_wsi_obj_cust_data,
          ms_employee_data  TYPE /benmsg/cl_dc4_models=>ts_employee_data,
          mv_context_status TYPE /benmsg/edcf_context_status,
          mo_prod           TYPE REF TO /benmsg/if_dcf_ctx_product,
          mo_doc            TYPE REF TO /benmsg/if_dcf_ctx_doc,
          mv_is_new_item    TYPE abap_bool.
    METHODS add_matgroup_to_doc .

  PRIVATE SECTION.


ENDCLASS.



CLASS zrwtha_cl_dcf_helper IMPLEMENTATION.

  METHOD change_tech_txt.
    " first check if entry exists, then change it, otherwise add it
    TRY.
        ct_tech_txt[ key = iv_name ]-value[ 1 ] = iv_value.
      CATCH cx_sy_itab_line_not_found.
        " entry not there, add it
        INSERT VALUE #( key = iv_name value = VALUE #( ( iv_value ) ) ) INTO TABLE ct_tech_txt.
    ENDTRY.

  ENDMETHOD.

  METHOD add_matgroup_to_doc.
    DATA(lv_material_group) = mo_prod->get_material_group( ).

    IF lv_material_group-id IS NOT INITIAL.
      DATA(lv_value) = |{ lv_material_group-label } ({ lv_material_group-id })|.
    ELSE. " set field even if empty, so that user sees that no matkl was found/is there
      lv_value = ||.
    ENDIF.

    " check if field exists, then only update
    DATA(lt_fields) = mo_doc->get_doc_fields( ).
    TRY.
        lt_fields[ name = 'MATGROUP' ]-value = lv_value.
        mo_doc->set_doc_fields( it_doc_fields = lt_fields ).
      CATCH cx_sy_itab_line_not_found.
        " does not exist, add it
        mo_doc->append_doc_field( EXPORTING iv_name  = 'MATGROUP' iv_value = lv_value ).
    ENDTRY.

  ENDMETHOD.


  METHOD constructor.

    mo_context        = io_context.
    mv_trigger        = iv_trigger.
    mv_form_id        = iv_form_id.
    mv_event          = iv_event.
    mo_helper         = io_helper.
    mv_context_status = iv_context_status.
    ms_employee_data  = is_employee_data.

    mv_is_new_item = xsdbool( ( mv_context_status = 'NEW' ) AND ( mv_event = 'SUBMIT' ) ).

    CHECK mo_context IS BOUND.
    mo_prod = mo_context->get_product( ).

    CHECK mo_prod IS BOUND.
    mo_doc = mo_prod->get_doc( ).

  ENDMETHOD.


  METHOD get_hse_ekgrp_from_matkl.
    DATA: BEGIN OF ls_crud_imp,
            matkl TYPE matkl,
          END OF ls_crud_imp,
          BEGIN OF ls_crud_exp,
            ekgrp TYPE ekgrp,
            hse   TYPE xfeld,
          END OF ls_crud_exp.

    ls_crud_imp-matkl = iv_matkl.

    mo_ws = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = CONV #( ms_employee_data-root_id )
                                              iv_cust_sys_id = CONV #( ms_employee_data-cust_sys_id )
                                              iv_remote_sys  = CONV #( ms_employee_data-remote_system_id ) ).

    mo_ws->get_external_data( EXPORTING iv_action   = 'EkgrpFromMatkl'
                                        iv_object   = 'BEN_DATA'
                                        iv_data     = ls_crud_imp
                              IMPORTING ev_data     = ls_crud_exp ).
    ev_hse = ls_crud_exp-hse.
    ev_ekgrp = ls_crud_exp-ekgrp.
  ENDMETHOD.


  METHOD get_hse_ekgrp_from_matkl_price.
    DATA: BEGIN OF ls_crud_imp,
            matkl TYPE matkl,
          END OF ls_crud_imp,
          BEGIN OF ls_crud_exp,
            ekgrp TYPE ekgrp,
            hse   TYPE xfeld,
          END OF ls_crud_exp,
          lv_zek_thresh TYPE string.

    ls_crud_imp-matkl = iv_matkl.

    mo_ws = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = CONV #( ms_employee_data-root_id )
                                              iv_cust_sys_id = CONV #( ms_employee_data-cust_sys_id )
                                              iv_remote_sys  = CONV #( ms_employee_data-remote_system_id ) ).

    mo_ws->get_external_data( EXPORTING iv_action   = 'EkgrpFromMatkl'
                                        iv_object   = 'BEN_DATA'
                                        iv_data     = ls_crud_imp
                              IMPORTING ev_data     = ls_crud_exp ).

    SELECT SINGLE cust_value FROM zrwtha_cust WHERE cust = 'ZEK_THRESHHOLD' INTO @lv_zek_thresh.

    IF lv_zek_thresh IS NOT INITIAL.
      ev_hse = abap_false.
    ENDIF.
    ev_hse = ls_crud_exp-hse.
    ev_ekgrp = ls_crud_exp-ekgrp.
  ENDMETHOD.


  METHOD get_item_defaults.
    CHECK is_prod_and_doc_bound( ) = abap_true.

    add_matgroup_to_doc( ).

    IF mv_is_new_item = abap_true.
      IF mo_ws IS NOT BOUND.
        mo_ws = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = CONV #( ms_employee_data-root_id )
                                                  iv_cust_sys_id = CONV #( ms_employee_data-cust_sys_id )
                                                  iv_remote_sys  = CONV #( ms_employee_data-remote_system_id ) ).
      ENDIF.
      get_matkl_from_eclass( ).

    ENDIF.
  ENDMETHOD.


  METHOD get_matkl_from_eclass.
    DATA: BEGIN OF ls_crud_imp,
            eclass TYPE c LENGTH 9,
          END OF ls_crud_imp,
          BEGIN OF ls_crud_exp,
            matkl TYPE matkl,
            wgbez TYPE wgbez,
          END OF ls_crud_exp.

    mo_helper->get_value( EXPORTING iv_name  = 'PRODUCT_CATEGORY' IMPORTING ev_value = ls_crud_imp-eclass ).
    IF ls_crud_imp-eclass IS INITIAL.
      ls_crud_imp-eclass = mo_doc->get_target_classification( )-classification_i_d.
    ENDIF.

    CHECK ls_crud_imp-eclass IS NOT INITIAL.

    mo_ws->get_external_data( EXPORTING iv_action   = 'MatklFromEclass'
                                        iv_object   = 'BEN_DATA'
                                        iv_data     = ls_crud_imp
                              IMPORTING ev_data     = ls_crud_exp ).

    mo_prod->set_material_group( VALUE #( id = CONV #( ls_crud_exp-matkl ) label = ls_crud_exp-wgbez ) ).
    add_matgroup_to_doc(  ).
  ENDMETHOD.

  METHOD get_stock.
    DATA: BEGIN OF ls_crud_imp,
            matnr TYPE matnr,
            werks TYPE werks_d,
            lgort TYPE lgort_d,
          END OF ls_crud_imp.
    DATA: BEGIN OF ls_crud_exp,
            labst TYPE string,
          END OF ls_crud_exp.

    mo_helper->get_value( EXPORTING iv_name  = 'PLANT_RES'
                          IMPORTING ev_value = ls_crud_imp-werks ).
    mo_helper->get_value( EXPORTING iv_name  = 'STORAGE_LOC'
                          IMPORTING ev_value = ls_crud_imp-lgort ).

    mo_ws = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = CONV #( ms_employee_data-root_id )
                                              iv_cust_sys_id = CONV #( ms_employee_data-cust_sys_id )
                                              iv_remote_sys  = CONV #( ms_employee_data-remote_system_id ) ).

    mo_ws->get_external_data( EXPORTING iv_action = 'GetStock'
                                        iv_object = 'BEN_DATA'
                                        iv_data   = ls_crud_imp
                              IMPORTING ev_data   = ls_crud_exp ).

    mo_helper->set_value( iv_name  = 'STOCK'
                          iv_value = ls_crud_exp-labst ).
  ENDMETHOD.


  METHOD is_prod_and_doc_bound.
    IF mo_prod IS BOUND AND mo_doc IS BOUND.
      rv_result = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD set_ekgrp_from_matkl.
    DATA: lv_ekgrp TYPE ekgrp,
          lv_hse   TYPE xfeld.

    get_hse_ekgrp_from_matkl(
      EXPORTING
        iv_matkl = iv_matkl
      IMPORTING
        ev_ekgrp = lv_ekgrp
        ev_hse   = lv_hse
    ).

    SELECT SINGLE cust_value FROM zrwtha_cust WHERE cust = 'EKGRP_THRESHHOLD' INTO @DATA(lv_ekgrp_thresh).
    IF iv_price <= lv_ekgrp_thresh AND lv_hse IS NOT INITIAL.
      lv_ekgrp = '010'.
    ENDIF.

    mo_prod->set_purchasing_grp( VALUE #( id = lv_ekgrp ) ).
    mo_helper->set_value( EXPORTING iv_name  = 'PURCHASING_GRP' iv_value = lv_ekgrp ).
  ENDMETHOD.
ENDCLASS.
