class ZRWTHA_CL_CHANGE_RFM_RTE definition
  public
  final
  create public .

public section.

  interfaces /BENMSG/IF_RFM_CHANGE_BADI_RTE .
  interfaces IF_BADI_INTERFACE .
protected section.
private section.
ENDCLASS.



CLASS ZRWTHA_CL_CHANGE_RFM_RTE IMPLEMENTATION.


  METHOD /benmsg/if_rfm_change_badi_rte~change.
    READ TABLE is_request-rfm-extrinsics REFERENCE INTO DATA(lrs_extrinsics) WITH KEY name = 'DELIVERY_RESTRICTIONS'.
    IF sy-subrc EQ 0.
      READ TABLE ct_form_config REFERENCE INTO DATA(lr_form_config) WITH KEY field_name = 'CONFIRMATION'.
      IF sy-subrc = 0. lr_form_config->visible = 'X'. lr_form_config->mandatory = 'X'. lr_form_config->editable = 'X'. ENDIF.
    ELSE.
      READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFIRMATION'.
      IF sy-subrc = 0. lr_form_config->visible = ''. lr_form_config->mandatory = ''. lr_form_config->editable = ''. ENDIF.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
