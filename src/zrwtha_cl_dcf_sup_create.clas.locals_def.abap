TYPES:
  BEGIN OF obligatory_form_fields,
    name       TYPE string,
    street     TYPE string,
    housenum   TYPE string,
    postl      TYPE string,
    city       TYPE string,
    country    TYPE string,
    umsatz     TYPE string,
    tele       TYPE string,
    mail_req   TYPE string,
    mail_order TYPE string,
    mail_contr TYPE string,
    zahlbe     TYPE string,
    inco       TYPE string,
  END OF obligatory_form_fields.

TYPES:
  BEGIN OF optional_form_fields,
    birthdate TYPE timestamp,
  END OF optional_form_fields.

"! contains all fields of DCF.
"! when new form fields are added with their corresponding type,
"! the 'field name/value'-pair is automatically passed to mail processing as a parameter
TYPES BEGIN OF form_fields.
INCLUDE TYPE obligatory_form_fields.
INCLUDE TYPE optional_form_fields.
TYPES END OF form_fields.

TYPES component_names TYPE STANDARD TABLE OF abap_compname WITH EMPTY KEY.
