class ZRWTHA_CL_CHANGE_RFQ_RTE definition
  public
  final
  create public .

public section.

  interfaces /BENMSG/IF_RFQ_CHANGE_BADI_RTE .
  interfaces IF_BADI_INTERFACE .
protected section.
private section.
ENDCLASS.



CLASS ZRWTHA_CL_CHANGE_RFQ_RTE IMPLEMENTATION.


  METHOD /benmsg/if_rfq_change_badi_rte~change.
    DATA: lv_conflict       TYPE string,
          lv_conflict_radio TYPE string,
          ls_form_component TYPE /benmsg/if_rfx_json_mdl=>ts_rfx_doc_extrinsic.

    "Pre-fill values on first launch
    READ TABLE cs_doc-form_components WITH KEY name = 'INCOTERMS' TRANSPORTING NO FIELDS. "LFE
    IF sy-subrc NE 0.
      ls_form_component = VALUE  /benmsg/if_rfx_json_mdl=>ts_rfx_doc_extrinsic(
                                 name = 'INCOTERMS' value = 'LFE' label = '' data_type = '' ).
      APPEND ls_form_component TO cs_doc-form_components.
    ENDIF.
    READ TABLE cs_doc-form_components WITH KEY name = 'TERMS_OF_PAYMENT' TRANSPORTING NO FIELDS. "30D
    IF sy-subrc NE 0.
      ls_form_component = VALUE  /benmsg/if_rfx_json_mdl=>ts_rfx_doc_extrinsic(
                                 name = 'TERMS_OF_PAYMENT' value = '30D' label = '' data_type = '' ).
      APPEND ls_form_component TO cs_doc-form_components.
    ENDIF.
    READ TABLE cs_doc-form_components WITH KEY name = 'SERVICE_DESCRIPTION' TRANSPORTING NO FIELDS. "24 Monate
    IF sy-subrc NE 0.
      ls_form_component = VALUE  /benmsg/if_rfx_json_mdl=>ts_rfx_doc_extrinsic(
                                 name = 'SERVICE_DESCRIPTION' value = '24 Monate' label = '' data_type = '' ).
      APPEND ls_form_component TO cs_doc-form_components.
    ENDIF.
    READ TABLE cs_doc-form_components REFERENCE INTO DATA(lrs_form_components) WITH KEY name = 'CONFLICT_OF_INTEREST'.
    IF sy-subrc = 0. lv_conflict = lrs_form_components->value. ENDIF.

    IF lv_conflict EQ 'Y'.
      READ TABLE ct_form_config REFERENCE INTO DATA(lr_form_config) WITH KEY field_name = 'CONFLICT_INFO'.
      IF sy-subrc = 0. lr_form_config->visible = 'X'. ENDIF.
      READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_INFO_RADIO'.
      IF sy-subrc = 0. lr_form_config->visible = 'X'. ENDIF.

      READ TABLE cs_doc-form_components REFERENCE INTO lrs_form_components WITH KEY name = 'CONFLICT_INFO_RADIO'.
      IF sy-subrc = 0. lv_conflict_radio = lrs_form_components->value. ENDIF.
      IF lv_conflict_radio EQ 'NAH'.
        READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_CLOSE_REL_RADIO'.
        IF sy-subrc = 0. lr_form_config->visible = 'X'. ENDIF.
        READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_CLOSE_REL_INPUT'.
        IF sy-subrc = 0. lr_form_config->visible = 'X'. ENDIF.
      ELSE.
        READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_CLOSE_REL_RADIO'.
        IF sy-subrc = 0. lr_form_config->visible = ''. ENDIF.
        READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_CLOSE_REL_INPUT'.
        IF sy-subrc = 0. lr_form_config->visible = ''. ENDIF.
      ENDIF.
    ELSE.
      READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_INFO'.
      IF sy-subrc = 0. lr_form_config->visible = ''. ENDIF.
      READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_INFO_RADIO'.
      IF sy-subrc = 0. lr_form_config->visible = ''. ENDIF.
      READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_CLOSE_REL_RADIO'.
      IF sy-subrc = 0. lr_form_config->visible = ''. ENDIF.
      READ TABLE ct_form_config REFERENCE INTO lr_form_config WITH KEY field_name = 'CONFLICT_CLOSE_REL_INPUT'.
      IF sy-subrc = 0. lr_form_config->visible = ''. ENDIF.
    ENDIF.

    READ TABLE cs_doc-extrinsics REFERENCE INTO DATA(lrs_extrinsics) WITH KEY name = 'DCF_MATGROUP'.
    IF sy-subrc EQ 0.
      cs_doc-material_group = lrs_extrinsics->value.
    ENDIF.

    READ TABLE cs_doc-extrinsics REFERENCE INTO lrs_extrinsics WITH KEY name = 'DCF_NOTE'.
    IF sy-subrc EQ 0.
      READ TABLE cs_doc-form_components WITH KEY name = 'INTERNAL_NOTE' REFERENCE INTO DATA(lrs_note).
      IF sy-subrc EQ 0.
        IF lrs_note->value IS INITIAL.
          lrs_note->value = lrs_extrinsics->value.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
