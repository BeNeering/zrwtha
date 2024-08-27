CLASS zrwtha_cl_wsi_obj_ecc_pr DEFINITION
  PUBLIC
  INHERITING FROM /benmsg/cl_wsi_obj_ecc_pr
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS set_test_data_in_my_cart_model REDEFINITION.
    METHODS map_extensionin REDEFINITION . " z-fields to RWTHA
    METHODS map_extensionout REDEFINITION . " z-fields from RWTHA
    METHODS map_my_cart_to_preq_pre_exit REDEFINITION.
    METHODS map_mycart_to_preq_post_exit2 REDEFINITION.
    METHODS map_preq_to_my_cart_post_exit2 REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_wsi_obj_ecc_pr IMPLEMENTATION.


  METHOD map_extensionin.
    DATA ls_extensionin  TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_extension.
    DATA ls_extensioninx TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_extension.
    DATA ls_bapi_te_mereqitem  TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_cust_field_extension.
    DATA ls_bapi_te_mereqitemx TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_cust_field_extension.
    DATA lt_bapi_te_mereqitem  TYPE /benmsg/cl_wsi_obj_ecc_pr=>tt_cust_field_extension.
    DATA lt_bapi_te_mereqitemx TYPE /benmsg/cl_wsi_obj_ecc_pr=>tt_cust_field_extension.

    DATA(lv_proc_id) = VALUE #( it_doc_fields[ name = 'PROCESS_ID' ]-value OPTIONAL ).
    DATA(lv_proj_number) = VALUE #( is_product-doc-tech_txt[ key = 'PROJ_NUMBER' ]-value[ 1 ] OPTIONAL ).

    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    ls_bapi_te_mereqitem-component_name = 'PREQ_ITEM'.
    ls_bapi_te_mereqitem-component_value = iv_preq_item.
    APPEND ls_bapi_te_mereqitem TO lt_bapi_te_mereqitem.
    ls_bapi_te_mereqitemx-component_name  = ls_bapi_te_mereqitem-component_name.
    ls_bapi_te_mereqitemx-component_value = iv_preq_item.
    APPEND ls_bapi_te_mereqitemx TO lt_bapi_te_mereqitemx.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    ls_bapi_te_mereqitem-component_name = 'ZZ_BENGRP'. " Z-Feld in Kundenstruktur (bapi_te_mereqitem)
    ls_bapi_te_mereqitem-component_value = lv_proc_id.
    APPEND ls_bapi_te_mereqitem TO lt_bapi_te_mereqitem.
    ls_bapi_te_mereqitemx-component_name = ls_bapi_te_mereqitem-component_name.
    ls_bapi_te_mereqitemx-component_value = abap_true.
    APPEND ls_bapi_te_mereqitemx TO lt_bapi_te_mereqitemx.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
    ls_bapi_te_mereqitem-component_name = 'ZZ_GZN'.
    ls_bapi_te_mereqitem-component_value = lv_proj_number.
    APPEND ls_bapi_te_mereqitem TO lt_bapi_te_mereqitem.
    ls_bapi_te_mereqitemx-component_name  = ls_bapi_te_mereqitem-component_name.
    ls_bapi_te_mereqitemx-component_value = abap_true.
    APPEND ls_bapi_te_mereqitemx TO lt_bapi_te_mereqitemx.
    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

    ls_extensionin-preq_item   = iv_preq_item.
    ls_extensionin-structure   = 'BAPI_TE_MEREQITEM'.
    ls_extensionin-cust_fields = lt_bapi_te_mereqitem.
    APPEND ls_extensionin TO ct_ben_extensionin.

    ls_extensioninx-preq_item   = iv_preq_item.
    ls_extensioninx-structure   = 'BAPI_TE_MEREQITEMX'.
    ls_extensioninx-cust_fields = lt_bapi_te_mereqitemx.
    APPEND ls_extensioninx TO ct_ben_extensionin.
  ENDMETHOD.


  METHOD map_extensionout.
    DATA(lt_item_doc_fields) = VALUE #( it_ben_extensionout[ preq_item = iv_preq_item structure = 'BAPI_TE_MEREQITEM' ]-cust_fields OPTIONAL ).
    IF lt_item_doc_fields IS NOT INITIAL.

      DATA(lv_val)  = VALUE #( lt_item_doc_fields[ component_name = 'ZZ_GZN' ]-component_value OPTIONAL ).
      TRY.
          ct_tech_txt_fields[ key = 'PROJ_NUMBER' ]-value[ 1 ] = lv_val.
        CATCH cx_sy_itab_line_not_found.
          " entry not there, add it
          INSERT VALUE #( key = 'PROJ_NUMBER' value = VALUE #( ( lv_val ) ) ) INTO TABLE ct_tech_txt_fields.
      ENDTRY.

    ENDIF.
  ENDMETHOD.


  METHOD map_my_cart_to_preq_pre_exit.

*    cs_product-doc-buyer_a_i_d = |E{ cs_product-doc-target_classification-classification_i_d }|.

  ENDMETHOD.


  METHOD set_test_data_in_my_cart_model.

  ENDMETHOD.

  METHOD map_mycart_to_preq_post_exit2.
    " if PSP element is changed, we need to reset couple of fields to be able to retrigger the automatic determination in sap again
    LOOP AT cs_crud_pr_ecc-pr_bapi-praccountx ASSIGNING FIELD-SYMBOL(<line>).
      DATA(lv_first_pos) = <line>-preq_item. " needed for later in the code
      IF <line>-wbs_element <> 'X'. " we have a change here
        CONTINUE.
      ENDIF.

      TRY.
          CLEAR cs_crud_pr_ecc-pr_bapi-praccount[ preq_item = <line>-preq_item ]-costcenter.
          CLEAR cs_crud_pr_ecc-pr_bapi-praccount[ preq_item = <line>-preq_item ]-profit_ctr.
          CLEAR cs_crud_pr_ecc-pr_bapi-praccount[ preq_item = <line>-preq_item ]-funds_ctr.
          CLEAR cs_crud_pr_ecc-pr_bapi-praccount[ preq_item = <line>-preq_item ]-bus_area.

          <line>-costcenter = 'X'.
          <line>-profit_ctr = 'X'.
          <line>-funds_ctr  = 'X'.
          <line>-bus_area   = 'X'.
        CATCH cx_sy_itab_line_not_found.
          " its fine to do nothing here
      ENDTRY.
    ENDLOOP.

    " the following change will not be needed after CDEV-9596 is in place
    " its only for a better display of the deletion output
    TRY.
        IF cs_crud_pr_ecc-pr_bapi-pritem[ 1 ]-delete_ind = 'X'.
          LOOP AT cs_crud_pr_ecc-pr_bapi-pritemx ASSIGNING FIELD-SYMBOL(<linex>).
            CLEAR: <linex>-unit,
                   <linex>-preq_unit_iso,
                   <linex>-gr_ind,
                   <linex>-plnd_delry.
          ENDLOOP.
          LOOP AT cs_crud_pr_ecc-pr_bapi-praccountx ASSIGNING FIELD-SYMBOL(<lineaccx>).
            CLEAR: <lineaccx>-quantity,
                   <lineaccx>-profit_ctr.
          ENDLOOP.
        ENDIF.
      CATCH cx_sy_itab_line_not_found.
        " its fine to do nothing here
    ENDTRY.

    " additional z-fields mapping due missing header in first exit
    IF is_my_cart-document_type = 'ZNW' OR is_my_cart-document_type = 'ZFM' OR is_my_cart-document_type = 'ZNB'.

      LOOP AT cs_crud_pr_ecc-pr_bapi_ben-extensionin ASSIGNING FIELD-SYMBOL(<ext>) WHERE structure = 'BAPI_TE_MEREQITEM'.
        APPEND VALUE #( component_name  = 'ZZ_DATUM_PA'
                        component_value = sy-datum ) TO <ext>-cust_fields.
        APPEND VALUE #( component_name  = 'ZZ_GVV'
                        component_value = 'DIA' ) TO <ext>-cust_fields.
      ENDLOOP.

      LOOP AT cs_crud_pr_ecc-pr_bapi_ben-extensionin ASSIGNING FIELD-SYMBOL(<ext_x>) WHERE structure = 'BAPI_TE_MEREQITEMX'.
        APPEND VALUE #( component_name  = 'ZZ_DATUM_PA'
                        component_value = 'X' ) TO <ext_x>-cust_fields.
        APPEND VALUE #( component_name  = 'ZZ_GVV'
                        component_value = 'X' ) TO <ext_x>-cust_fields.
      ENDLOOP.

      IF is_my_cart-document_type = 'ZNB'.
        LOOP AT cs_crud_pr_ecc-pr_bapi-pritem ASSIGNING FIELD-SYMBOL(<item_line>).
          APPEND VALUE #( preq_item = <item_line>-preq_item
                          completed = abap_true
                          reason    = '0000' ) TO cs_crud_pr_ecc-pr_bapi-prversion.
          APPEND VALUE #( preq_item = <item_line>-preq_item
                          completed = abap_true
                          reason    = abap_true ) TO cs_crud_pr_ecc-pr_bapi-prversionx.
        ENDLOOP.
      ENDIF.

    ENDIF.

    " map header texts to items
    LOOP AT cs_crud_pr_ecc-pr_bapi-prheadertext ASSIGNING FIELD-SYMBOL(<txt_header>) WHERE text_id = 'B96' OR text_id = 'B97'.
      <txt_header>-preq_item = lv_first_pos.
      APPEND <txt_header> TO cs_crud_pr_ecc-pr_bapi-pritemtext.
    ENDLOOP.
    " for 95 add to all lines not only first
    LOOP AT cs_crud_pr_ecc-pr_bapi-prheadertext ASSIGNING <txt_header> WHERE text_id = 'B95'.
      LOOP AT cs_crud_pr_ecc-pr_bapi-pritem ASSIGNING FIELD-SYMBOL(<pr_item>).
        <txt_header>-preq_item = <pr_item>-preq_item.
        APPEND <txt_header> TO cs_crud_pr_ecc-pr_bapi-pritemtext.
      ENDLOOP.
    ENDLOOP.
    DELETE cs_crud_pr_ecc-pr_bapi-prheadertext WHERE text_id = 'B95' OR text_id = 'B96' OR text_id = 'B97'.

    " turns all attachments into header attachments
    LOOP AT cs_crud_pr_ecc-attachments ASSIGNING FIELD-SYMBOL(<attachment>).
      CLEAR <attachment>-preq_item.
    ENDLOOP.
  ENDMETHOD.

  METHOD map_preq_to_my_cart_post_exit2.
    " map item text back to header
    TRY.
        LOOP AT cs_my_cart-products[ 1 ]-notes ASSIGNING FIELD-SYMBOL(<line>) WHERE technical_object_type = 'B95' OR technical_object_type = 'B96' OR technical_object_type = 'B97'.
          APPEND VALUE #( document_text = <line>-document_text technical_object_type = <line>-technical_object_type ) TO cs_my_cart-notes.
        ENDLOOP.
      CATCH cx_sy_itab_line_not_found.
        " its fine to do nothing here
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
