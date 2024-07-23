class ZRWTHA_CL_SAVE_RFQ_PD definition
  public
  final
  create public .

public section.

  interfaces /BENMSG/IF_RFQ_SAVE_BADI .
  interfaces IF_BADI_INTERFACE .
protected section.
private section.
ENDCLASS.



CLASS ZRWTHA_CL_SAVE_RFQ_PD IMPLEMENTATION.


  method /BENMSG/IF_RFQ_SAVE_BADI~AFTER_SUCCESS_SAVE.
  endmethod.


  method /BENMSG/IF_RFQ_SAVE_BADI~BOPF_AFTER_SUCCESS_SAVE.
  endmethod.


  method /BENMSG/IF_RFQ_SAVE_BADI~BOPF_AT_SAVE.
  endmethod.


  METHOD /benmsg/if_rfq_save_badi~change_before_save.
    READ TABLE cs_pd-extrinsics REFERENCE INTO DATA(lrs_extrinsics) WITH KEY name = 'DCF_MATGROUP'.
    IF sy-subrc EQ 0.
      cs_pd-lead_doc-mat_group = lrs_extrinsics->string.
      LOOP AT cs_pd-items REFERENCE INTO DATA(lrs_item).
        lrs_item->mat_group = lrs_extrinsics->value.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD /benmsg/if_rfq_save_badi~check_before_save.
    DATA: lines TYPE i.
    IF is_pd-lead_doc-process NE 'DIK'.
      LOOP AT is_pd-partners TRANSPORTING NO FIELDS WHERE function = 'SUPPLIER' AND selected = 'X'.
        lines = lines + 1.
      ENDLOOP.
      IF lines < 3.
        READ TABLE is_pd-extrinsics REFERENCE INTO DATA(lr_conflict) WITH KEY name = 'CONFLICT_OF_INTEREST'.
        IF lr_conflict->string EQ 'Y'.

        ELSE.
          APPEND INITIAL LINE TO ct_messages REFERENCE INTO DATA(lr_message).
          lr_message->type = 'E'.
          MESSAGE e000(zrwtha_rfx_process) INTO lr_message->message.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
