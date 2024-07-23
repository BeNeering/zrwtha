CLASS zrwhta_cl_email_change_badi DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_email_change_badi .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwhta_cl_email_change_badi IMPLEMENTATION.
  METHOD /benmsg/if_email_change_badi~change_email_data.
    DATA: ls_email_data   TYPE /benmsg/cl_mail_ctrl_cwf_ec_pr=>ts_crud_email_data,
          lv_current_resp TYPE /benmsg/ewf_resp,
          lv_tabix        LIKE sy-tabix.

    " check in what step we are and map the description since it should be shown in the mail later
    CHECK iv_action = '/BENMSG/CWF_BUS2105_MSG_WI_CRT' OR
          iv_action = '/BENMSG/CWF_BUS2105_MSG_WI_REJ' OR
          iv_action = '/BENMSG/CWF_BUS2105_MSG_WF_FIN' OR
          iv_action = '/BENMSG/CWF_BUS2105_MSG_WI_REP'. " already in badi filter but just to be sure

    TRY.
        DATA(lv_json_wf) = cs_json-params[ name = 'CONTEXT_DATA' ]-value.
      CATCH cx_sy_itab_line_not_found.
        " its fine to do nothing here
    ENDTRY.

    CHECK lv_json_wf IS NOT INITIAL.

    /ui2/cl_json=>deserialize(
          EXPORTING
            json             =  lv_json_wf
            pretty_name      =  /ui2/cl_json=>pretty_mode-camel_case
          CHANGING
            data             = ls_email_data
        ).

    IF iv_action = '/BENMSG/CWF_BUS2105_MSG_WI_CRT'.
      CHECK ls_email_data-initiated_by_wf_decision-external_id IS NOT INITIAL.

      SELECT cwf~responsibility, t~resp_descr
      INTO TABLE @DATA(lt_db)
      FROM /benmsg/dwfcs AS cwf
      LEFT JOIN /benmsg/dwfcrest AS t ON cwf~responsibility = t~responsibility AND langu = 'D'
      WHERE wf_schema = 'ZRWTHA_BANF' ORDER BY step_idx.

      DATA(lv_desc_out) = ||.
      DATA(lv_note_out) = ||.

      LOOP AT lt_db ASSIGNING FIELD-SYMBOL(<line>).
        IF ls_email_data-initiated_by_wf_decision-external_id CS <line>-responsibility.
          lv_desc_out = <line>-resp_descr.
          lv_current_resp = <line>-responsibility. " just to have it for the comment later
          EXIT.
        ENDIF.
      ENDLOOP.

      " add last comment
      LOOP AT ls_email_data-wf_process-steps ASSIGNING FIELD-SYMBOL(<line_step>).
        " %20
        IF <line_step>-responsibility = lv_current_resp.
          lv_tabix = sy-tabix. " store since exit will clear it
          EXIT.
        ENDIF.
      ENDLOOP.

      TRY.
          IF lv_tabix > 1.
            lv_tabix = lv_tabix - 1.
            lv_note_out = ls_email_data-wf_process-steps[ lv_tabix ]-decisions[ 1 ]-note.
          ENDIF.
        CATCH cx_sy_itab_line_not_found.
          " its fine to do nothing here
      ENDTRY.
      IF lv_note_out IS INITIAL.
        lv_note_out = '&nbsp;'. " fallback to not see the #LAST_COMMENT in the mail
      ENDIF.

      APPEND VALUE #( name = 'CWF_STEP_DESC' value = lv_desc_out ) TO cs_json-params.
      APPEND VALUE #( name = 'LAST_COMMENT' value = lv_note_out ) TO cs_json-params.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
