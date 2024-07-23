CLASS zrwtha_cl_save_rfm_pd DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_rfm_save_badi .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_save_rfm_pd IMPLEMENTATION.


  METHOD /benmsg/if_rfm_save_badi~after_success_save.
  ENDMETHOD.


  METHOD /benmsg/if_rfm_save_badi~bopf_after_success_save.
  ENDMETHOD.


  METHOD /benmsg/if_rfm_save_badi~bopf_at_save.
  ENDMETHOD.


  METHOD /benmsg/if_rfm_save_badi~change_before_save.
  ENDMETHOD.


  METHOD /benmsg/if_rfm_save_badi~check_before_save.
    DATA: lt_rfq_extrinsics     TYPE /benmsg/tcpdext,
          lv_expected_max_price TYPE /benmsg/edoc_total_value.

    READ TABLE is_pd-ref_docs REFERENCE INTO DATA(lr_ref) WITH KEY host_node_name = /benmsg/if_pd_c=>bopf-node_name-pdh.
    IF sy-subrc EQ 0.
      DATA(lo_rfq) = /benmsg/cl_pd=>factory( iv_obj_type = /benmsg/if_pd_c=>obj_type-rfq
                                             iv_doc_key  = lr_ref->ref_key ).
    ENDIF.

    CHECK lo_rfq IS BOUND.

    lt_rfq_extrinsics = lo_rfq->get_extrinsics( ).
    READ TABLE lt_rfq_extrinsics REFERENCE INTO DATA(lrs_max_value) WITH KEY name = 'EXPECTED_MAX_PRICE'.
    IF lrs_max_value IS NOT INITIAL.
      "convert string to number
      lv_expected_max_price = lrs_max_value->value.
      IF is_pd-lead_doc-total_value LE lv_expected_max_price.
        "Do nothing - value is ok
      ELSE.
        cv_rc = 4.
        APPEND INITIAL LINE TO ct_messages REFERENCE INTO DATA(lr_message).
        lr_message->type = 'E'.
        MESSAGE e001(zrwtha_rfx_process) INTO lr_message->message.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
