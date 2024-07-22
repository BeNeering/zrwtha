CLASS cost_center_tests DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    "! pads internal value with leading zeros
    METHODS pads_int_val_wth_leading_zeros FOR TESTING RAISING cx_static_check.
    METHODS throws_on_empty_input FOR TESTING RAISING cx_static_check.
    "! strips leading zeros on external value
    METHODS strips_leading_zeros_on_ex_val FOR TESTING RAISING cx_static_check.

    METHODS gets_cost_center_from_item FOR TESTING RAISING cx_static_check.
    METHODS gets_users_default_cost_center FOR TESTING RAISING cx_static_check.
    METHODS user_cost_center_as_fallback FOR TESTING RAISING cx_static_check.
    METHODS setup.
    DATA cost_center TYPE REF TO cost_center.
    DATA fake_endpoint TYPE REF TO fake_endpoint.
ENDCLASS.


CLASS cost_center_tests IMPLEMENTATION.

  METHOD pads_int_val_wth_leading_zeros.
    cost_center = NEW #( '010730' ).
    cl_abap_unit_assert=>assert_equals( exp = `0000010730` act = cost_center->internal_value( ) ).
  ENDMETHOD.

  METHOD strips_leading_zeros_on_ex_val.
    cost_center = NEW #( '010730' ).
    cl_abap_unit_assert=>assert_equals( exp = `10730` act = cost_center->external_value( ) ).
  ENDMETHOD.

  METHOD throws_on_empty_input.
    TRY.
        cost_center = NEW #( '' ).
        cl_abap_unit_assert=>fail( msg = `cost center was constructed with invalid format` ).
      CATCH invalid_cost_center.
    ENDTRY.
  ENDMETHOD.

  METHOD gets_cost_center_from_item.
    DATA(item) = VALUE /benmsg/bapimereqitem_s( preq_item = 1 created_by = 'TESTUSER' ).
    DATA(item_accounts) = VALUE /benmsg/bapimereqaccount_t(
      ( preq_item = 1 wbs_element = '131100107300020' ) ).
    cost_center = cost_center=>from_purchase_requisition_item( item = item item_accounts = item_accounts endpoint = fake_endpoint ).
    cl_abap_unit_assert=>assert_equals( exp = `0000010730` act = cost_center->internal_value( ) ).
  ENDMETHOD.

  METHOD gets_users_default_cost_center.
    fake_endpoint->cost_center = '9999999999'.
    cost_center = cost_center=>from_user( username = 'TESTUSER' endpoint = fake_endpoint ).
    cl_abap_unit_assert=>assert_equals( exp = `9999999999` act = cost_center->internal_value( ) ).
  ENDMETHOD.

  METHOD user_cost_center_as_fallback.
    fake_endpoint->cost_center = '9999999999'.
    DATA(item) = VALUE /benmsg/bapimereqitem_s( preq_item = 1 created_by = 'TESTUSER' ).
    DATA(item_accounts_with_empty_psp) = VALUE /benmsg/bapimereqaccount_t(
      ( preq_item = 1 wbs_element = '' ) ).
    cost_center = cost_center=>from_purchase_requisition_item(
      item = item
      item_accounts = item_accounts_with_empty_psp
      endpoint = fake_endpoint ).
    cl_abap_unit_assert=>assert_equals( exp = `9999999999` act = cost_center->internal_value( ) ).
  ENDMETHOD.

  METHOD setup.
    fake_endpoint = NEW #( ).
  ENDMETHOD.

ENDCLASS.
