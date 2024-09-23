CLASS zrwtha_cl_dcf_pr_prod_cat DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_dcf_runtime .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_dcf_pr_prod_cat IMPLEMENTATION.
  METHOD /benmsg/if_dcf_runtime~change.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~check.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~init.

    DATA(lv_obj_id_parent) = io_parent->/benmsg/if_dcf_parent~get_obj_id( ). " empty when no PR
    DATA(lo_prod) = io_context->get_product( ).
    DATA(lv_type) = lo_prod->get_type( ).
    DATA(lo_doc) = lo_prod->get_doc( ).
    DATA(lv_sup_id) = lo_doc->get_supplier_id( ).
    IF lv_sup_id IS INITIAL AND lv_type = 'RFX' AND lv_obj_id_parent IS INITIAL.
      io_helper->set_attr( iv_name  = 'SEC_RFX_LIFNR'
                     iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_hidden
                     iv_value = abap_false ).
      io_helper->set_attr( iv_name  = 'RFX_LIFNR_SH'
                     iv_attr  = io_helper->/benmsg/if_dcf_cons~mc_component-attribute-is_required ).
    ENDIF.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~submit.
    DATA: lo_prod       TYPE REF TO /benmsg/if_dcf_ctx_product,
          lo_doc        TYPE REF TO /benmsg/if_dcf_ctx_doc,
          lt_doc_fields TYPE /benmsg/cl_dc4_models=>tt_name_value,
          ls_notes      TYPE io_helper->ts_notes,
          lt_notes      TYPE io_helper->tt_notes.
    DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                    iv_trigger        = iv_trigger
                                                    iv_form_id        = iv_form_id
                                                    iv_event          = iv_event
                                                    io_helper         = io_helper
                                                    iv_context_status = iv_context_status
                                                    is_employee_data  = is_employee_data ).
    lo_dcf_helper->get_item_defaults( ).

    IF iv_context_status EQ 'NEW'.
      lo_prod = io_context->get_product( ).
      CHECK lo_prod IS BOUND.
      lo_doc = lo_prod->get_doc( ).
      CHECK lo_doc IS BOUND.
      lt_doc_fields = lo_doc->get_doc_fields( ).
      READ TABLE lt_doc_fields REFERENCE INTO DATA(lrs_doc_fields) WITH KEY name = 'INTERNAL_NOTE'.
      IF sy-subrc EQ 0.
        lt_notes = lo_prod->get_notes( ).
        READ TABLE lt_notes REFERENCE INTO DATA(lrs_b02) WITH KEY technical_object_type = 'B02'.
        IF sy-subrc <> 0.
          CLEAR ls_notes.
          ls_notes-document_text          = lrs_doc_fields->value.
          ls_notes-technical_object_type  = 'B02'.
          APPEND ls_notes TO lt_notes.
        ELSE.
          lrs_b02->document_text = lrs_doc_fields->value.
        ENDIF.
        lo_prod->set_notes( it_notes = lt_notes ).
      ENDIF.
    ENDIF.

    " set supplier if empty for RFX
    DATA ls_sh_values TYPE io_helper->ts_sh_values.
    io_helper->get_value( EXPORTING iv_name  = 'RFX_LIFNR_SH'
                          IMPORTING ev_value = ls_sh_values ).
    IF ls_sh_values-obj_value_prop IS NOT INITIAL.
      io_context->get_product( )->get_doc( )->set_supplier_id( iv_supplier_id = ls_sh_values-obj_value_prop ).
      io_context->get_product( )->get_doc( )->set_supplier_name( iv_supplier_name = ls_sh_values-obj_label_prop ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
