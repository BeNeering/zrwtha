CLASS zrwtha_cl_wsi_obj_shlp_psp DEFINITION
  PUBLIC
  INHERITING FROM zrwtha_cl_wsi_obj_shlp_root
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
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

ENDCLASS.
