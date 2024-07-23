CLASS unit_test DEFINITION CREATE PUBLIC
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.

  PUBLIC SECTION.
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA class_under_test TYPE REF TO zrwtha_cl_wsi_obj_shlp_lfa.
    DATA search_helps TYPE shlp_desct.
    METHODS first_position_should_be_name FOR TESTING RAISING cx_static_check.
    METHODS search_help_name_should_be_cp FOR TESTING RAISING cx_static_check.
    METHODS positions_should_be_unique FOR TESTING RAISING cx_static_check.
    METHODS setup.

ENDCLASS.

CLASS unit_test IMPLEMENTATION.

  METHOD setup.
    class_under_test = NEW #(
      iv_customer_id = space
      iv_cust_sys_id = space
      iv_remote_sys = space ).
    search_helps = VALUE #(
      ( shlpname = 'KREDE' fieldprop = VALUE #(
        ( fieldname = 'SORTL' shlpselpos = '01' )
        ( fieldname = 'LAND1' shlpselpos = '02' )
        ( fieldname = 'PSTLZ' shlpselpos = '03' )
        ( fieldname = 'MCOD3' shlpselpos = '04' )
        ( fieldname = 'MCOD1' shlpselpos = '05' )
        ( fieldname = 'LIFNR' shlpselpos = '06' )
        ( fieldname = 'EKORG' shlpselpos = '07' )
        ( fieldname = 'BOLRE' shlpselpos = '08' )
        ( fieldname = 'BEGRU' shlpselpos = '00' )
        ( fieldname = 'KTOKK' shlpselpos = '00' )
        ( fieldname = 'LOEVM' shlpselpos = '09' ) ) ) ).
  ENDMETHOD.

  METHOD first_position_should_be_name.
    class_under_test->modify_search_help( CHANGING ct_shlp_int = search_helps ).
    cl_abap_unit_assert=>assert_equals(
      exp = '01'
      act = search_helps[ shlpname = 'KREDE' ]-fieldprop[ fieldname = 'MCOD1' ]-shlpselpos
      msg = `search help parameter 'name' is not at the first position` ).
  ENDMETHOD.

  METHOD positions_should_be_unique.
    class_under_test->modify_search_help( CHANGING ct_shlp_int = search_helps ).
    DATA expected_search_help TYPE shlp_desct.
    expected_search_help = VALUE #(
      ( shlpname = 'KREDE' fieldprop = VALUE #(
        ( fieldname = 'SORTL' shlpselpos = '02' )
        ( fieldname = 'LAND1' shlpselpos = '03' )
        ( fieldname = 'PSTLZ' shlpselpos = '04' )
        ( fieldname = 'MCOD3' shlpselpos = '05' )
        ( fieldname = 'MCOD1' shlpselpos = '01' )
        ( fieldname = 'LIFNR' shlpselpos = '06' )
        ( fieldname = 'EKORG' shlpselpos = '07' )
        ( fieldname = 'BOLRE' shlpselpos = '08' )
        ( fieldname = 'BEGRU' shlpselpos = '00' )
        ( fieldname = 'KTOKK' shlpselpos = '00' )
        ( fieldname = 'LOEVM' shlpselpos = '09' ) ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = expected_search_help act = search_helps ).
  ENDMETHOD.

  METHOD search_help_name_should_be_cp.
    cl_abap_unit_assert=>fail( msg = `not implemented yet` ).
  ENDMETHOD.

ENDCLASS.
