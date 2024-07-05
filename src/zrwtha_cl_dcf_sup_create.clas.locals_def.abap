TYPES:
  "! contains all fields of DCF.
  "! when new form fields are added with their corresponding type,
  "! the 'field name/value'-pair is automatically passed to mail processing as a parameter
  BEGIN OF form_fields,
    name       TYPE string,
    birthdate  TYPE timestamp,
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
  END OF form_fields.

TYPES component_names TYPE STANDARD TABLE OF abap_compname WITH EMPTY KEY.
