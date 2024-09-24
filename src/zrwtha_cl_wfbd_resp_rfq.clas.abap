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
    DATA dummy_request TYPE c LENGTH 1.
    TYPES users TYPE STANDARD TABLE OF xubname WITH EMPTY KEY.
    DATA: BEGIN OF response,
            users TYPE users,
          END OF response.

    DATA(purchasing_request_header) = /benmsg/cl_wf_pd_access=>factory( io_wf_obj = io_wf_obj )->get_header( ).
    " note: because the remote system id is empty in the request, the customer system id is used instead.
    NEW /benmsg/cl_wsi_obj_cust_data(
        iv_customer_id = purchasing_request_header-cust_id
        iv_cust_sys_id = purchasing_request_header-cust_sys_id
        iv_remote_sys  = purchasing_request_header-cust_sys_id )->get_external_data(
      EXPORTING
        iv_action   = 'CentralPurchasingUsers'
        iv_object   = 'BEN_DATA'
        iv_data     = dummy_request
      IMPORTING
        ev_data     = response ).

    et_agents = VALUE #( FOR user IN response-users ( otype = 'US' objid = user ) ).
    et_profiles = VALUE #(
      FOR agent IN et_agents
      ( proftype = /benmsg/if_wf_c=>obj_cat-cse_us profile = agent-objid ) ).
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_reapproval_required.
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_step_valid.
    DATA: lv_conflict_int TYPE /benmsg/eext_value.
    CLEAR cv_valid.

    DATA(lo_pd) = /benmsg/cl_wf_pd_access=>factory( io_wf_obj = io_wf_obj ).
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
