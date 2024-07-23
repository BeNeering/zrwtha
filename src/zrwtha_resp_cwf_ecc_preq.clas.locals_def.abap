TYPES: BEGIN OF union_agents_profiles,
         agents   TYPE tswhactor,
         profiles TYPE /benmsg/twf_profile_map,
       END OF union_agents_profiles.

TYPES: BEGIN OF ty_cached_users_from_role,
         iv_kostl TYPE kostl,
         iv_role  TYPE agr_name,
         result   TYPE zrwtha_resp_cwf_ecc_preq=>tt_users,
       END OF ty_cached_users_from_role.
TYPES tyt_cached_users_from_role TYPE HASHED TABLE OF ty_cached_users_from_role WITH UNIQUE KEY iv_kostl iv_role.

TYPES hashed_tswhactor TYPE HASHED TABLE OF swhactor WITH UNIQUE KEY table_line.
TYPES sorted_tswhactor TYPE SORTED TABLE OF swhactor WITH UNIQUE KEY table_line.
TYPES sorted_profiles TYPE SORTED TABLE OF /benmsg/swf_profile_map WITH UNIQUE KEY proftype profile.

TYPES: BEGIN OF rule_parameters,
         process_id                    TYPE string,
         value                         TYPE /benmsg/bapimereqitem_s-value_item,
         roles                         TYPE string_table,
         responsibility                TYPE /benmsg/ewf_resp,
         "! Does the material group have a responsible agent assigned?
         has_material_group_user       TYPE abap_bool,
         "! Do all agents of the current step appear in a later step in the workflow?
         "! If yes, step may be skipped if the rule says so
         all_agents_appear_later_in_wf TYPE abap_bool,
       END OF rule_parameters.

TYPES r_process_id TYPE RANGE OF string.
TYPES r_value TYPE RANGE OF /benmsg/bapimereqitem_s-value_item.
TYPES r_roles TYPE RANGE OF string.
TYPES r_responsibility TYPE RANGE OF /benmsg/ewf_resp.
TYPES r_abap_bool TYPE RANGE OF abap_bool.

TYPES: BEGIN OF rule,
         "! process id of the purchase requisition
         process_id                TYPE r_process_id,
         "! value of all the items of the purchase requisition
         value                     TYPE r_value,
         "! roles of the requester of the purchase requisition
         roles                     TYPE r_roles,
         "! responsibility of the step
         responsibility            TYPE r_responsibility,
         "! true if the material group of the purchase requisition has a responsible agent
         has_material_group_user   TYPE r_abap_bool,
         "! true if all agents of evaluated step can occur in later step in workflow
         agents_appear_later_in_wf TYPE r_abap_bool,
         "! Outcome of rule. If true then step is executed. If false, step is skipped
         result                    TYPE abap_bool,
       END OF rule.
TYPES rules TYPE STANDARD TABLE OF rule WITH EMPTY KEY.


TYPES:
  "! for debugging if a rule applies to the current step
  BEGIN OF rule_applies_for_debug,
    process_id                    TYPE abap_bool,
    value                         TYPE abap_bool,
    roles                         TYPE abap_bool,
    responsibility                TYPE abap_bool,
    has_material_group_user       TYPE abap_bool,
    all_agents_appear_later_in_wf TYPE abap_bool,
  END OF rule_applies_for_debug.


CLASS invalid_cost_center DEFINITION CREATE PUBLIC INHERITING FROM cx_static_check.
ENDCLASS.


CLASS missing_user_configuration DEFINITION CREATE PUBLIC INHERITING FROM cx_static_check.
ENDCLASS.


CLASS cost_center DEFINITION CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        cost_center TYPE kostl
      RAISING
        invalid_cost_center.

    CLASS-METHODS from_purchase_requisition_item
      IMPORTING
        item          TYPE /benmsg/bapimereqitem_s
        item_accounts TYPE /benmsg/bapimereqaccount_t
        endpoint      TYPE REF TO /benmsg/cl_wsi_obj_cust_data
      RETURNING
        VALUE(result) TYPE REF TO cost_center
      RAISING
        invalid_cost_center
        missing_user_configuration.

    CLASS-METHODS from_user
      IMPORTING
        username      TYPE syst_uname
        endpoint      TYPE REF TO /benmsg/cl_wsi_obj_cust_data
      RETURNING
        VALUE(result) TYPE REF TO cost_center
      RAISING
        missing_user_configuration.

    METHODS internal_value
      RETURNING
        VALUE(result) TYPE kostl.

    METHODS external_value
      RETURNING
        VALUE(result) TYPE kostl.

  PRIVATE SECTION.
    DATA cost_center TYPE kostl.
ENDCLASS.
