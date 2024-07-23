CLASS zrwtha_cl_wsi_obj_ext_data DEFINITION
  PUBLIC
  INHERITING FROM /benmsg/cl_wsi_obj
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES /benmsg/if_rest_cust_data.
  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS get_supplier_email_by_suppl_no
      IMPORTING
        !iv_supplier_number TYPE bu_partner
      EXPORTING
        !ev_supplier_number TYPE bu_partner
        !ev_supplier_email  TYPE ad_smtpadr
        !ev_supplier_name   TYPE string
        !et_messages        TYPE bapiret2_t
         ev_sup_con_first_name TYPE string
         ev_sup_con_last_name TYPE string .
ENDCLASS.



CLASS zrwtha_cl_wsi_obj_ext_data IMPLEMENTATION.
  METHOD /benmsg/if_rest_cust_data~get_pd_supplier_contacts.
    DATA lv_contact_name TYPE string.

    me->get_supplier_email_by_suppl_no( EXPORTING iv_supplier_number    = CONV #( iv_supplier_id )   " Business Partner Number
                                        IMPORTING ev_supplier_number    = DATA(lv_supplier_number)    " Business Partner Number
                                                  ev_supplier_email     = DATA(lv_supplier_email)    " E-Mail Address
                                                  ev_supplier_name      = DATA(lv_supplier_name)    " Business Partner Name
                                                  ev_sup_con_first_name = DATA(lv_sup_con_first_name)
                                                  ev_sup_con_last_name  = DATA(lv_sup_con_last_name)
                                                  et_messages           = DATA(lt_messages) ).

    es_supplier-bup_org_id = iv_supplier_id.
    es_supplier-name       = lv_supplier_name.
    es_supplier-selected   = abap_true.

    lv_contact_name = |{ lv_sup_con_first_name } { lv_sup_con_last_name }|.

    APPEND INITIAL LINE TO es_supplier-contacts REFERENCE INTO DATA(lr_contact).
    lr_contact->bup_org_id = iv_supplier_id.
    lr_contact->name       = lv_contact_name.
    lr_contact->email_addr = lv_supplier_email.
  ENDMETHOD.


  METHOD get_supplier_email_by_suppl_no.
    DATA BEGIN OF ls_crud_imp.
    DATA   supplier_number TYPE lifnr.
    DATA END OF ls_crud_imp.

    DATA BEGIN OF ls_crud_exp.
    DATA   supplier_name   TYPE string.
    DATA   supplier_number TYPE lifnr.
    DATA   supplier_email  TYPE ad_smtpadr.
    DATA   sup_contact_first_name TYPE string.
    DATA   sup_contact_last_name TYPE string.
    DATA   bapiret2 TYPE TABLE OF bapiret2 WITH EMPTY KEY.
    DATA END OF ls_crud_exp.

    get_consumer( ).
    CHECK mo_crud_consumer IS BOUND.

    ms_crud_request-crud_request-crud_params-object = 'SUPPLIER'.
    ms_crud_request-crud_request-crud_params-action = 'getSupplierEmailBySupplierNumber'.

    ls_crud_imp-supplier_number = iv_supplier_number.

    set_request_data( iv_data = ls_crud_imp ).

    call_consumer( ).

    get_response_data( IMPORTING ev_data = ls_crud_exp ).

    ev_supplier_email  = ls_crud_exp-supplier_email.
    ev_supplier_name   = ls_crud_exp-supplier_name.
    ev_supplier_number = ls_crud_exp-supplier_number.
    ev_sup_con_first_name = ls_crud_exp-sup_contact_first_name.
    ev_sup_con_last_name = ls_crud_exp-sup_contact_last_name.
    et_messages        = ls_crud_exp-bapiret2.
  ENDMETHOD.

ENDCLASS.
