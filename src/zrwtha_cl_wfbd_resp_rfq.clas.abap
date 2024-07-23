CLASS zrwtha_cl_wfbd_resp_rfq DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_wf_bd_resp .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_wfbd_resp_rfq IMPLEMENTATION.


  METHOD /benmsg/if_wf_bd_resp~get_responsible_agents.
    DATA: lv_profile TYPE /benmsg/ewf_profile,
          lt_prof_db TYPE TABLE OF /benmsg/dwfrdp,
          ls_prof_db TYPE /benmsg/dwfrdp,
          ls_prof_e  TYPE /benmsg/swf_profile_map.

    et_agents = /benmsg/cl_wf_resp_ctrl=>get_api( )->get_wf_admin( ).

*    ls_prof_db-decision_id = is_decision-decision_id.
*    ls_prof_db-proftype    = /benmsg/if_wf_c=>obj_cat-cse_dl.
*    ls_prof_db-profile     = lv_profile.
*    append ls_prof_db to lt_prof_db.
    DATA(lo_pd) = /benmsg/cl_wf_pd_access=>factory( io_wf_obj = io_wf_obj ).
    DATA(ls_hdr)  = lo_pd->get_header( ).
    "Hardcode for testing
*    lv_profile = 'MW510651'.

    lv_profile = ls_hdr-created_by.
    IF lv_profile IS INITIAL.
      lv_profile = 'Myself'.
    ENDIF.
    ls_prof_e-proftype    = /benmsg/if_wf_c=>obj_cat-cse_us.
    ls_prof_e-profile     = lv_profile.

    APPEND ls_prof_e TO et_profiles.

  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_reapproval_required.
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_step_valid.
    DATA: lv_conflict_int TYPE /benmsg/eext_value.

    CLEAR cv_valid.

    DATA(lo_pd) = /benmsg/cl_wf_pd_access=>factory( io_wf_obj = io_wf_obj ).

    DATA(ls_hdr)  = lo_pd->get_header( ).

    lv_conflict_int = lo_pd->get_extrinsic_value( iv_name      = 'CONFLICT_OF_INTEREST'
                                                  iv_node_name = 'PDH'
                                                  iv_category  = 'WEBFORMFLD' ).

    IF lv_conflict_int IS INITIAL OR lv_conflict_int EQ 'N'.
      cv_valid = abap_false.
    ELSEIF lv_conflict_int EQ 'Y'.
      cv_valid = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~map_items_to_decisions.
  ENDMETHOD.
ENDCLASS.
