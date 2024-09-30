CLASS zrwtha_cl_dcf_sup_create DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_dcf_runtime .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS supplier_creation_mail TYPE ppfdtt VALUE 'ZRWTHA_SUP_CREATE'.

    "! returns form data for all fields in the return structure
    METHODS form_data
      IMPORTING
        helper        TYPE REF TO /benmsg/cl_dcf_change_bdi_h
      RETURNING
        VALUE(result) TYPE form_fields.

    METHODS required_fields_are_supplied
      IMPORTING
        form_data     TYPE form_fields
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! converts form fields to parameters
    METHODS params_from_form_data
      IMPORTING
        form_data     TYPE form_fields
      RETURNING
        VALUE(result) TYPE /benmsg/cl_mail_ctrl=>ty_t_params.

    "! converts employee data to parameters
    METHODS params_from_employee_data
      IMPORTING
        employee_data TYPE /benmsg/cl_dc4_models=>ts_employee_data
      RETURNING
        VALUE(result) TYPE /benmsg/cl_mail_ctrl=>ty_t_params.

    METHODS components_of
      IMPORTING
        form_data     TYPE any
      RETURNING
        VALUE(result) TYPE component_names.

    METHODS is_timestamp
      IMPORTING
        value         TYPE any
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS as_string
      IMPORTING
        value         TYPE any
      RETURNING
        VALUE(result) TYPE string.

    "! removes all user input from the form
    METHODS clear_form
      IMPORTING
        helper TYPE REF TO /benmsg/cl_dcf_change_bdi_h.

    METHODS toggle_required_fields_err_msg
      IMPORTING
        form_data TYPE form_fields
        helper    TYPE REF TO /benmsg/cl_dcf_change_bdi_h.

    METHODS mail_request
      IMPORTING
        form_data     TYPE form_fields
        employee_data TYPE /benmsg/cl_dc4_models=>ts_employee_data
        context       TYPE REF TO /benmsg/cl_dcf_ctx
      RETURNING
        VALUE(result) TYPE /benmsg/cl_mail_ctrl=>ty_s_mail_request.

    METHODS mail_not_sent
      IMPORTING
        helper TYPE REF TO /benmsg/cl_dcf_change_bdi_h.

    METHODS mail_successfully_sent
      IMPORTING
        helper TYPE REF TO /benmsg/cl_dcf_change_bdi_h.

    "! request missing fields from user
    METHODS request_missng_fields_from_usr
      IMPORTING
        helper    TYPE REF TO /benmsg/cl_dcf_change_bdi_h
        form_data TYPE form_fields.
ENDCLASS.



CLASS zrwtha_cl_dcf_sup_create IMPLEMENTATION.
  METHOD /benmsg/if_dcf_runtime~change.
    IF iv_trigger EQ 'SEND_EMAIL'.
      DATA(form_data) = form_data( io_helper ).
      IF required_fields_are_supplied( form_data ).

        NEW /benmsg/cl_mail_ctrl( )->send_message(
          EXPORTING
            ip_action   = supplier_creation_mail
            is_request  = mail_request(
              form_data     = form_data
              employee_data = is_employee_data
              context       = io_context )
          IMPORTING
            es_response =  DATA(response) ).

        IF response-access IS INITIAL OR response-success IS INITIAL.
          mail_not_sent( io_helper ).
        ELSEIF response-success IS NOT INITIAL.
          mail_successfully_sent( io_helper ).
        ENDIF.
      ELSE.
        request_missng_fields_from_usr( helper = io_helper form_data = form_data ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~check.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~init.
    io_helper->set_value( iv_name  = 'INCO' iv_value = TEXT-LFE ).
  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~submit.

  ENDMETHOD.


  METHOD form_data.
    LOOP AT components_of( result ) ASSIGNING FIELD-SYMBOL(<component>).
      ASSIGN COMPONENT <component> OF STRUCTURE result TO FIELD-SYMBOL(<value>).
      CHECK sy-subrc = 0.
      helper->get_value( EXPORTING iv_name = CONV #( <component> ) IMPORTING ev_value = <value> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD required_fields_are_supplied.
    DATA obligatory_fields TYPE obligatory_form_fields.
    result = abap_true.
    LOOP AT components_of( obligatory_fields ) ASSIGNING FIELD-SYMBOL(<component>).
      ASSIGN COMPONENT <component> OF STRUCTURE form_data TO FIELD-SYMBOL(<value>).
      IF <value> IS INITIAL.
        result = abap_false.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD params_from_form_data.
    LOOP AT components_of( form_data ) ASSIGNING FIELD-SYMBOL(<component>).
      ASSIGN COMPONENT <component> OF STRUCTURE form_data TO FIELD-SYMBOL(<value>).
      CHECK sy-subrc = 0.
      IF is_timestamp( <value> ).
        INSERT VALUE #( name = <component> value = as_string( <value> ) ) INTO TABLE result.
      ELSE.
        INSERT VALUE #( name = <component> value = <value> ) INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD params_from_employee_data.
    INSERT VALUE #(
      name = 'REQUESTER'
      value = |{ employee_data-contact-first_name } { employee_data-contact-last_name }| ) INTO TABLE result.
    INSERT VALUE #( name = 'REQ_EMAIL' value = employee_data-contact-email_addr ) INTO TABLE result.
    INSERT VALUE #( name = 'PURCHASE_ORG' value = employee_data-purchasing_org ) INTO TABLE result.
    TRY.
        INSERT VALUE #( name = 'IKZ' value = employee_data-cust_fields[ tech_name = 'IKZ' ]-values[ 1 ]-value )
          INTO TABLE result.
      CATCH cx_sy_itab_line_not_found.
        INSERT VALUE #( name = 'IKZ' value = TEXT-001 ) INTO TABLE result.
    ENDTRY.
  ENDMETHOD.


  METHOD components_of.
    DATA(components) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( form_data ) )->components.
    result = VALUE #(
      FOR <component> IN components
      ( <component>-name ) ).
  ENDMETHOD.


  METHOD is_timestamp.
    DATA timestamp TYPE timestamp.
    DATA(timestamp_descriptor) = CAST cl_abap_datadescr( cl_abap_typedescr=>describe_by_data( timestamp ) ).
    IF timestamp_descriptor->applies_to_data( value ).
      result = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD as_string.
    DATA(timestamp) = REF timestamp( value ).
    CONVERT TIME STAMP timestamp->* TIME ZONE space INTO DATE DATA(date).
    result = |{ date DATE = USER }|.
  ENDMETHOD.


  METHOD clear_form.
    DATA empty_form TYPE form_fields.
    DATA(all_components) = VALUE table_of_strings( FOR c IN components_of( empty_form ) ( CONV string( c ) ) ).
    helper->clear_values( all_components ).
    LOOP AT all_components ASSIGNING FIELD-SYMBOL(<component>).
      helper->clear_message( <component> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD toggle_required_fields_err_msg.
    DATA obligatory_fields TYPE obligatory_form_fields.
    LOOP AT components_of( obligatory_fields ) ASSIGNING FIELD-SYMBOL(<component>).
      ASSIGN COMPONENT <component> OF STRUCTURE form_data TO FIELD-SYMBOL(<value>).
      IF <value> IS INITIAL.
        helper->add_message( iv_name = CONV #( <component> ) is_message = VALUE #(
          type = helper->/benmsg/if_dcf_cons~mc_component-message-type-error
          tech_name = <component>
          value = '$OTR:/BENMSG/OTRDCF/REQUIRED' ) ).
      ELSE.
        helper->clear_message( CONV #( <component> ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD mail_request.
    TRY.
        result-custid = employee_data-root_id.
        result-lang = 'DE'.
        result-type = supplier_creation_mail.
        DATA(lt_doc_fields) = context->get_product( )->get_doc( )->get_doc_fields( ).
        INSERT VALUE #( email = lt_doc_fields[ name = 'MAIL' ]-value ) INTO TABLE result-recipients.
        INSERT LINES OF params_from_employee_data( employee_data ) INTO TABLE result-params.
        INSERT LINES OF params_from_form_data( form_data ) INTO TABLE result-params.
      CATCH cx_sy_ref_is_initial
            cx_sy_itab_line_not_found.
    ENDTRY.
  ENDMETHOD.


  METHOD mail_not_sent.
    DATA error_message TYPE /benmsg/cl_dcf_mdl=>ts_form_message.
    error_message-type = helper->/benmsg/if_dcf_cons~mc_component-message-type-error.
    error_message-message = TEXT-002.
    helper->add_form_message( is_message = error_message ).
  ENDMETHOD.


  METHOD mail_successfully_sent.
    DATA success_message TYPE /benmsg/cl_dcf_mdl=>ts_form_message.
    success_message-type = helper->/benmsg/if_dcf_cons~mc_component-message-type-info.
    success_message-message = TEXT-003.
    helper->add_form_message( is_message = success_message ).
    clear_form( helper ).
  ENDMETHOD.


  METHOD request_missng_fields_from_usr.
    DATA error_message TYPE /benmsg/cl_dcf_mdl=>ts_form_message.
    error_message-type = helper->/benmsg/if_dcf_cons~mc_component-message-type-error.
    error_message-message = TEXT-004.
    helper->add_form_message( is_message = error_message ).
    toggle_required_fields_err_msg( form_data = form_data helper = helper ).
  ENDMETHOD.

ENDCLASS.
