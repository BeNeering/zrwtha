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

  ENDMETHOD.

ENDCLASS.
