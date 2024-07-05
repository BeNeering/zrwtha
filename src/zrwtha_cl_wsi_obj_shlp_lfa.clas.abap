CLASS zrwtha_cl_wsi_obj_shlp_lfa DEFINITION
  PUBLIC
  INHERITING FROM /benmsg/cl_wsi_obj_shlp
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS modify_search_help REDEFINITION.
    METHODS set_default_select_options REDEFINITION .
  PRIVATE SECTION.
    METHODS reordered
      IMPORTING
        VALUE(field_properties) TYPE ddshfprops
        desired_order           TYPE sorted_field_order_mapping
      RETURNING
        VALUE(result)           TYPE ddshfprops.
ENDCLASS.



CLASS zrwtha_cl_wsi_obj_shlp_lfa IMPLEMENTATION.

  METHOD modify_search_help.
    DATA desired_field_order TYPE sorted_field_order_mapping.
    desired_field_order = VALUE #( ( order_number = '01' fieldname = 'MCOD1' ) ).

    TRY.
        DATA(field_properties) = reordered(
          field_properties = ct_shlp_int[ shlpname = 'KREDE' ]-fieldprop
          desired_order = desired_field_order ).
        ct_shlp_int[ shlpname = 'KREDE' ]-fieldprop = field_properties.
      CATCH cx_sy_itab_line_not_found.
        " its fine to do nothing here
    ENDTRY.

  ENDMETHOD.

  METHOD set_default_select_options.

    super->set_default_select_options( EXPORTING is_employee_data = is_employee_data
                                       CHANGING  ct_shlp_int      = ct_shlp_int ).

    TRY.
        ct_shlp_int[ shlpname = 'KREDE' ]-selopt[ shlpfield = 'MCOD1' ]-option = 'CP'.
      CATCH cx_sy_itab_line_not_found.
        " its fine to do nothing here
    ENDTRY.

  ENDMETHOD.


  METHOD reordered.
    DATA current_order_with_order_numbr TYPE STANDARD TABLE OF shlpfield WITH EMPTY KEY.
    DATA(fields_with_order_number) = VALUE ddshfprops(
      FOR i IN field_properties WHERE ( shlpselpos <> '00' ) ( i ) ).
    SORT fields_with_order_number BY shlpselpos.
    current_order_with_order_numbr = VALUE #( FOR i IN fields_with_order_number ( i-fieldname ) ).
    LOOP AT desired_order ASSIGNING FIELD-SYMBOL(<desired>).
      DELETE current_order_with_order_numbr WHERE table_line = desired_order[ 1 ]-fieldname.
      INSERT desired_order[ 1 ]-fieldname INTO current_order_with_order_numbr INDEX desired_order[ 1 ]-order_number.
      DATA index TYPE i.
      LOOP AT field_properties ASSIGNING FIELD-SYMBOL(<i>).
        TRY.
            index = line_index( current_order_with_order_numbr[ table_line = <i>-fieldname ] ).
          CATCH cx_sy_itab_line_not_found.
            CLEAR index.
        ENDTRY.
        IF line_exists( result[ fieldname = <i>-fieldname ] ).
          result[ fieldname = <i>-fieldname ]-shlpselpos = index.
        ELSE.
          INSERT VALUE #( BASE <i> shlpselpos = index ) INTO TABLE result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
