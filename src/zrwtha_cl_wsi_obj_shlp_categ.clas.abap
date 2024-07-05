CLASS zrwtha_cl_wsi_obj_shlp_categ DEFINITION
  PUBLIC
  INHERITING FROM /benmsg/cl_wsi_obj_shlp
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  PROTECTED SECTION.
    methods modify_search_help redefinition.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_wsi_obj_shlp_categ IMPLEMENTATION.

METHOD modify_search_help.

  LOOP AT ct_shlp_int REFERENCE INTO DATA(lrs_shlp_int) WHERE shlpname = 'ZBEN_MYC_MATGRP'.
    READ TABLE lrs_shlp_int->selopt REFERENCE INTO DATA(lrs_selopt) WITH KEY shlpname = lrs_shlp_int->shlpname shlpfield = 'KSCHG'.
    IF sy-subrc EQ 0.
      lrs_selopt->option = 'CP'.
    ELSE.
      APPEND VALUE ddshselopt(
                              shlpname = lrs_shlp_int->shlpname
                              shlpfield = 'KSCHG'
                              sign = 'I'
                              option = 'CP' )
                              TO lrs_shlp_int->selopt.
    ENDIF.
  ENDLOOP.

  super->modify_search_help(
    EXPORTING
      it_params   = it_params
    CHANGING
      ct_shlp_int = ct_shlp_int
  ).
ENDMETHOD.

ENDCLASS.
