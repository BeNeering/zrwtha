TYPES hashed_tswhactor TYPE HASHED TABLE OF swhactor WITH UNIQUE KEY table_line.
TYPES sorted_tswhactor TYPE SORTED TABLE OF swhactor WITH UNIQUE KEY table_line.
TYPES sorted_profiles TYPE SORTED TABLE OF /benmsg/swf_profile_map WITH UNIQUE KEY proftype profile.

TYPES r_process_id TYPE RANGE OF string.
TYPES r_value TYPE RANGE OF /benmsg/bapimereqitem_s-value_item.
TYPES r_roles TYPE RANGE OF string.
TYPES r_responsibility TYPE RANGE OF /benmsg/ewf_resp.
TYPES r_abap_bool TYPE RANGE OF abap_bool.

TYPES: BEGIN OF workflow_rule,
         is_emergency_order             TYPE abap_bool,
         value_group                    TYPE char10,
         role_group                     TYPE char10,
         material_grp_approval_required TYPE abap_bool,
       END OF workflow_rule.

TYPES BEGIN OF workflow_rule_with_result.
INCLUDE TYPE workflow_rule.
TYPES resulting_workflow TYPE char5.
TYPES END OF workflow_rule_with_result.

TYPES workflow_rules TYPE HASHED TABLE OF workflow_rule_with_result WITH UNIQUE KEY
  value_group role_group is_emergency_order material_grp_approval_required.

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


CLASS empty_requester DEFINITION CREATE PUBLIC INHERITING FROM cx_static_check.
ENDCLASS.


CLASS requester DEFINITION CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        user_name TYPE xubname
      RAISING
        empty_requester.

    CLASS-METHODS from_purchase_requisition_item
      IMPORTING
        item          TYPE /benmsg/bapimereqitem_t
        mycart        TYPE /benmsg/cl_dc4_models=>ts_my_cart
      RETURNING
        VALUE(result) TYPE REF TO requester
      RAISING
        empty_requester.

    DATA user_name TYPE xubname READ-ONLY.
ENDCLASS.


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
      RETURNING
        VALUE(result) TYPE REF TO cost_center
      RAISING
        invalid_cost_center.

    CLASS-METHODS from_requester
      IMPORTING
        requester               TYPE REF TO requester
        customer_wf_customizing TYPE REF TO /benmsg/cl_wsi_obj_cust_data
      RETURNING
        VALUE(result)           TYPE REF TO cost_center
      RAISING
        missing_user_configuration.

    CLASS-METHODS from_item_or_requester
      IMPORTING
        item                    TYPE /benmsg/bapimereqitem_s
        item_accounts           TYPE /benmsg/bapimereqaccount_t
        requester               TYPE REF TO requester
        customer_wf_customizing TYPE REF TO /benmsg/cl_wsi_obj_cust_data
      RETURNING
        VALUE(result)           TYPE REF TO cost_center
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



CLASS invariant_violated DEFINITION CREATE PUBLIC INHERITING FROM cx_no_check.
ENDCLASS.

CLASS precondition_violated DEFINITION CREATE PUBLIC INHERITING FROM cx_no_check.
ENDCLASS.

CLASS empty_material_group DEFINITION CREATE PUBLIC INHERITING FROM cx_dynamic_check.
ENDCLASS.


CLASS material_group DEFINITION CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        material_group TYPE matkl
      RAISING
        empty_material_group.

    METHODS requires_approval
      IMPORTING
        cost_center             TYPE REF TO cost_center
        customer_wf_customizing TYPE REF TO /benmsg/cl_wsi_obj_cust_data
      RETURNING
        VALUE(result)           TYPE abap_bool.

    METHODS approver
      IMPORTING
        cost_center             TYPE REF TO cost_center
        customer_wf_customizing TYPE REF TO /benmsg/cl_wsi_obj_cust_data
      RETURNING
        VALUE(result)           TYPE xubname.

  PRIVATE SECTION.
    DATA material_group TYPE matkl.

ENDCLASS.


TYPES: BEGIN OF predicted_workflow_step,
         step_idx_cfg   TYPE /benmsg/ewf_idx,
         responsibility TYPE /benmsg/ewf_resp,
       END OF predicted_workflow_step,
       predicted_workflow_steps TYPE STANDARD TABLE OF predicted_workflow_step WITH EMPTY KEY.

TYPES: BEGIN OF user_costcenter_role_tuple,
         benutzer     TYPE c LENGTH 12,
         kostenstelle TYPE kostl,
         rolle        TYPE agr_name,
       END OF user_costcenter_role_tuple.
TYPES user_costcenter_role_mapping TYPE STANDARD TABLE OF user_costcenter_role_tuple WITH EMPTY KEY.

TYPES: BEGIN OF flat_workflow_tuple,
         step_index           TYPE /benmsg/swf_bd_step-step_idx_cfg,
         step_responsibility  TYPE /benmsg/swf_bd_step-responsibility,
         decision_external_id TYPE /benmsg/swf_bd_decision-external_id,
         agent_objid          TYPE actorid,
       END OF flat_workflow_tuple,
       flat_workflow TYPE STANDARD TABLE OF flat_workflow_tuple WITH EMPTY KEY.
