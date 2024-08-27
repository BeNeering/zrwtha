"! provides default behavior for all RWTHA search helps
CLASS zrwtha_cl_wsi_obj_shlp_root DEFINITION
  PUBLIC
  INHERITING FROM /benmsg/cl_wsi_obj_shlp
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS /benmsg/if_rest_shlp~get_search_help REDEFINITION.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zrwtha_cl_wsi_obj_shlp_root IMPLEMENTATION.

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
    "suppresses immediate search help value request for all search helps
    LOOP AT et_shlp_detail ASSIGNING FIELD-SYMBOL(<detail>).
      <detail>-dialogtype = dialog_with_value_restriction.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
