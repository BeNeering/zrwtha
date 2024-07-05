CLASS zrwtha_cl_dcf_reservation DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_dcf_runtime .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_dcf_reservation IMPLEMENTATION.


  METHOD /benmsg/if_dcf_runtime~change.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~check.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~init.
    CONSTANTS default_sloc TYPE string VALUE '2200'.
    DATA lv_str TYPE string.

    DATA(lo_dcf_helper) = NEW zrwtha_cl_dcf_helper( io_context        = io_context
                                                    iv_trigger        = iv_trigger
                                                    iv_form_id        = iv_form_id
                                                    iv_event          = iv_event
                                                    io_helper         = io_helper
                                                    iv_context_status = iv_context_status
                                                    is_employee_data  = is_employee_data ).

    " add default sloc if empty
    io_helper->get_value( EXPORTING iv_name  = 'STORAGE_LOC'
                          IMPORTING ev_value = lv_str ).
    IF lv_str IS INITIAL.
      io_helper->set_value( iv_name  = 'STORAGE_LOC'
                            iv_value = default_sloc ).
    ENDIF.

    lo_dcf_helper->get_stock( ).
  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~submit.

  ENDMETHOD.

ENDCLASS.
