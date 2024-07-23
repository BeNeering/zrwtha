CLASS zrwtha_cl_im_wf_bd_resp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_wf_bd_cse_api.
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA: work_items TYPE /benmsg/twf_cse_wi.

    METHODS get_work_items
      RETURNING VALUE(rt_work_items) TYPE /benmsg/twf_cse_wi.
ENDCLASS.



CLASS zrwtha_cl_im_wf_bd_resp IMPLEMENTATION.
  METHOD /benmsg/if_wf_bd_cse_api~get_workitems_local.

* Skip local items processing without filter. This is to avoid the duplicate items retrieving
* in case local system = remote system

    IF iv_obj_type IS INITIAL.
      cv_profiles_processed = abap_true.
      cv_workitems_processed = abap_true.
      RETURN.
    ENDIF.
  ENDMETHOD.

  METHOD /benmsg/if_wf_bd_cse_api~get_workitems_remote.
  ENDMETHOD.

  METHOD get_work_items.
  ENDMETHOD.

ENDCLASS.
