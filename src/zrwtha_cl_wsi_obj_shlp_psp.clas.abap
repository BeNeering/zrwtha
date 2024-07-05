CLASS zrwtha_cl_wsi_obj_shlp_psp DEFINITION
  PUBLIC
  INHERITING FROM /benmsg/cl_wsi_obj_shlp
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS /benmsg/if_rest_shlp~get_search_help REDEFINITION.
  PROTECTED SECTION.
    METHODS modify_search_help REDEFINITION.
    METHODS set_default_select_options REDEFINITION .
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_wsi_obj_shlp_psp IMPLEMENTATION.

  METHOD modify_search_help.

*    " remove all (tabs) except PRPMP
*    DELETE ct_shlp_int WHERE shlpname <> 'PRPMP'.
*
*    " change order
*    TRY.
*        DATA(lt_prop) = ct_shlp_int[ shlpname = 'PRPMP' ]-fieldprop.
*        lt_prop[ fieldname = 'POSID' ]-shlpselpos = '01'.
*        lt_prop[ fieldname = 'POSTU' ]-shlpselpos = '02'.
*        lt_prop[ fieldname = 'PSPID' ]-shlpselpos = '03'.
*        lt_prop[ fieldname = 'POSKI' ]-shlpselpos = '04'.
*        ct_shlp_int[ shlpname = 'PRPMP' ]-fieldprop = lt_prop.
*      CATCH cx_sy_itab_line_not_found.
*        " its fine to do nothing here
*    ENDTRY.

  ENDMETHOD.

  METHOD set_default_select_options.
    super->set_default_select_options( EXPORTING is_employee_data = is_employee_data
                                       CHANGING  ct_shlp_int      = ct_shlp_int ).

    TRY.
        ct_shlp_int[ shlpname = 'ZBEN_MYC_PSP' ]-selopt[ shlpfield = 'POSID' ]-option = 'CP'.
        ct_shlp_int[ shlpname = 'ZBEN_MYC_PSP' ]-selopt[ shlpfield = 'POST1' ]-option = 'CP'.

      CATCH cx_sy_itab_line_not_found.
        " its fine to do nothing here
    ENDTRY.
  ENDMETHOD.

  METHOD /benmsg/if_rest_shlp~get_search_help.
    CONSTANTS dialog_with_value_restriction TYPE ddshdiatyp VALUE 'C'.
    super->/benmsg/if_rest_shlp~get_search_help(
      EXPORTING
        iv_objtype       = iv_objtype
        iv_detail        = iv_detail
        iv_employee      = iv_employee
        it_query_params  = it_query_params
        is_employee_data = is_employee_data
        it_params        = it_params
      IMPORTING
        es_object_descr  = es_object_descr
        et_shlp_descr    = et_shlp_descr
        et_shlp_detail   = et_shlp_detail
        et_helpval_descr = et_helpval_descr
        et_shlp_int      = et_shlp_int ).
    TRY.
        "suppresses immediate search help value request
        et_shlp_detail[ fieldname = 'ZBEN_MYC_PSP' ]-dialogtype = dialog_with_value_restriction.
      CATCH cx_sy_itab_line_not_found.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
