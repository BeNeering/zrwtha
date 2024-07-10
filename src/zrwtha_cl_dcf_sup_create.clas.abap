CLASS zrwtha_cl_dcf_sup_create DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_dcf_runtime .
    INTERFACES if_badi_interface .
  PROTECTED SECTION.
  PRIVATE SECTION.
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
        form_data     TYPE form_fields
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
ENDCLASS.



CLASS zrwtha_cl_dcf_sup_create IMPLEMENTATION.
  METHOD /benmsg/if_dcf_runtime~change.
    DATA: lo_mail_ctrl      TYPE REF TO /benmsg/cl_mail_ctrl,
          lv_action         TYPE ppfdtt,
          ls_response       TYPE /benmsg/cl_mail_ctrl=>ty_s_mail_response,
          ls_mail_request   TYPE /benmsg/cl_mail_ctrl=>ty_s_mail_request,
          ls_mail_recipient TYPE /benmsg/cl_mail_ctrl=>ty_s_recipient,
          ls_param          TYPE /benmsg/cl_mail_ctrl=>ty_s_param,
          ls_message        TYPE /benmsg/cl_dcf_mdl=>ts_form_message.

    IF iv_trigger EQ 'SEND_EMAIL'.
      DATA(form_data) = form_data( io_helper ).
      IF required_fields_are_supplied( form_data ).
        "All required fields are maintained. Send out email.
        lv_action = 'ZRWTHA_SUP_CREATE'. " 'ZDEMO_SUP_CREATE'.
        CLEAR ls_mail_request.

        ls_mail_request-custid = is_employee_data-root_id.
        ls_mail_request-lang = 'DE'.
        ls_mail_request-type = lv_action.

        DATA(lr_product) = io_context->get_product( ).
        CHECK lr_product IS BOUND.
        DATA(lr_doc) = lr_product->get_doc( ).
        CHECK lr_doc IS BOUND.
        DATA(lt_doc_fields) = lr_doc->get_doc_fields( ).
        TRY.
            DATA(lv_email_to) = lt_doc_fields[ name = 'MAIL' ]-value.
          CATCH cx_sy_itab_line_not_found.
            " its fine to do nothing here
        ENDTRY.

        IF lv_email_to IS NOT INITIAL.
          CLEAR ls_mail_recipient.
          ls_mail_recipient-email = lv_email_to.
          APPEND ls_mail_recipient TO ls_mail_request-recipients.
        ENDIF.

        INSERT LINES OF params_from_employee_data( is_employee_data ) INTO TABLE ls_mail_request-params.

        "add parameters for email template
        INSERT LINES OF params_from_form_data( form_data ) INTO TABLE ls_mail_request-params.

        CREATE OBJECT lo_mail_ctrl.
        lo_mail_ctrl->send_message(
        EXPORTING
          ip_action   = lv_action  " PPF: Name of Action Definition
          is_request  = ls_mail_request
        IMPORTING
          es_response =  ls_response   " Response in JSON format
        ).

        IF ls_response-access IS INITIAL OR ls_response-success IS INITIAL.
          CLEAR ls_message.
          ls_message-type = io_helper->/benmsg/if_dcf_cons~mc_component-message-type-error.
          ls_message-message = |Email nicht versendet. Versuchen Sie es erneut|.
          io_helper->add_form_message( is_message = ls_message ).
        ELSEIF ls_response-success IS NOT INITIAL.
          CLEAR ls_message.
          ls_message-type = io_helper->/benmsg/if_dcf_cons~mc_component-message-type-info.
          ls_message-message = |Email wurde versendet|.
          io_helper->add_form_message( is_message = ls_message ).
        ENDIF.
      ELSE.
        "Give form message to fill out required data
        CLEAR ls_message.
        ls_message-type = io_helper->/benmsg/if_dcf_cons~mc_component-message-type-error.
        ls_message-message = |Bitte füllen Sie alle benötigten Felder aus|.
        io_helper->add_form_message( is_message = ls_message ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~check.

  ENDMETHOD.

  METHOD /benmsg/if_dcf_runtime~init.
    io_helper->set_value( iv_name  = 'INCO' iv_value = 'LFE (frei Leistungs- und Erfüllungsort)' ).
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
    " FIXME: find a way to 'mark' fields as obligatory without having to spell them out more then once.
    " If new obligatory fields are added, they have to be added in the local type form_fields and here,
    " which is prone to error
    IF  form_data-name       IS NOT INITIAL AND
        form_data-street     IS NOT INITIAL AND
        form_data-housenum   IS NOT INITIAL AND
        form_data-postl      IS NOT INITIAL AND
        form_data-city       IS NOT INITIAL AND
        form_data-country    IS NOT INITIAL AND
        form_data-umsatz     IS NOT INITIAL AND
        form_data-tele       IS NOT INITIAL AND
        form_data-mail_req   IS NOT INITIAL AND
        form_data-mail_order IS NOT INITIAL AND
        form_data-mail_contr IS NOT INITIAL AND
        form_data-zahlbe     IS NOT INITIAL AND
        form_data-inco       IS NOT INITIAL.
      result = abap_true.
    ENDIF.
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

ENDCLASS.
