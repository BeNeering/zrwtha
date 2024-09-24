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
          lv_tabix        LIKE sy-tabix,
          lv_desc_out     TYPE string,
          lv_note_out     TYPE string.

    CASE iv_action.
      WHEN '/BENMSG/CWF_BUS2105_MSG_WI_CRT'.
        DATA(lv_json_wf) = VALUE #( cs_json-params[ name = 'CONTEXT_DATA' ]-value OPTIONAL ).
        CHECK lv_json_wf IS NOT INITIAL.
        /ui2/cl_json=>deserialize(
              EXPORTING
                json             =  lv_json_wf
                pretty_name      =  /ui2/cl_json=>pretty_mode-camel_case
              CHANGING
                data             = ls_email_data ).

        CHECK ls_email_data-initiated_by_wf_decision-external_id IS NOT INITIAL.

        SELECT cwf~responsibility, t~resp_descr
          INTO TABLE @DATA(lt_db)
          FROM /benmsg/dwfcs AS cwf
          LEFT JOIN /benmsg/dwfcrest AS t ON cwf~responsibility = t~responsibility AND langu = 'D'
          WHERE wf_schema = 'ZRWTHA_BANF' ORDER BY step_idx.

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
      WHEN '/BENMSG/RFQ_EMAIL_CRT_APPR'
        OR '/BENMSG/RFQ_EMAIL_CRT_SUBM'
        OR '/BENMSG/RFQ_EMAIL_SUP_SUBM'
        OR '/BENMSG/RFQ_EMAIL_CRT_OPEN'
        OR '/BENMSG/RFQ_EMAIL_SUP_OPEN'.
        TRY.
            IF cs_json-params[ name = 'PROCESS' ]-value CS 'PEV'.
              DATA(appl_key) = CAST /benmsg/cl_ppf_obj( io_appl_obj )->get_applkey( ).
              SELECT SINGLE sortfield1 FROM ppfttrigg INTO @DATA(document_key) WHERE applkey = @appl_key.
              IF sy-subrc = 0.
                DATA(rfq) = /benmsg/cl_pd=>factory( iv_obj_type  = /benmsg/if_pd_c=>obj_type-rfq
                                                    iv_doc_key   = CONV #( document_key ) ).
                DATA(customer_id) = rfq->get_header( )-cust_id.
                IF customer_id IS NOT INITIAL.
                  INSERT VALUE #( path = |rfx/{ customer_id }/supplier-info.pdf| ) INTO TABLE cs_json-attachments.
                ENDIF.
              ENDIF.
            ENDIF.
          CATCH cx_sy_itab_line_not_found
                cx_sy_move_cast_error
                cx_sy_ref_is_initial.
        ENDTRY.
      WHEN OTHERS.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
