CLASS zrwtha_resp_cwf_ecc_preq DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES /benmsg/if_wf_bd_resp .
    INTERFACES if_badi_interface .

    TYPES:
      BEGIN OF ts_wf_item,
        wf_type TYPE char2,
        uname   TYPE uname,
        gswrt   TYPE p LENGTH 13 DECIMALS 2,
        bukrs   TYPE char4,
      END OF ts_wf_item .
    TYPES:
      BEGIN OF ts_wf_data,
        step       TYPE string,
        items      TYPE STANDARD TABLE OF ts_wf_item WITH EMPTY KEY,
        step_valid TYPE abap_bool,
      END OF ts_wf_data .
    TYPES:
      BEGIN OF role,
        role TYPE  agr_name,
      END OF role .
    TYPES:
      tt_roles TYPE TABLE OF role WITH DEFAULT KEY .
    TYPES:
      tt_users TYPE TABLE OF xubname WITH DEFAULT KEY .
  PROTECTED SECTION.
    DATA mo_pr TYPE REF TO /benmsg/cl_wf_obj_cwf_ec_preq .

    METHODS get_users_from_role IMPORTING iv_kostl   TYPE kostl
                                          iv_role    TYPE agr_name
                                RETURNING VALUE(ret) TYPE tt_users.
    METHODS get_roles_from_user IMPORTING iv_kostl   TYPE kostl
                                          iv_uname   LIKE sy-uname
                                RETURNING VALUE(ret) TYPE spers_alst.
    METHODS get_user_from_kostl_matkl IMPORTING iv_kostl   TYPE REF TO cost_center
                                                iv_matkl   TYPE matkl
                                      RETURNING VALUE(ret) TYPE xubname.


  PRIVATE SECTION.
    CLASS-DATA cached_users_from_role TYPE tyt_cached_users_from_role.

    METHODS agents_for_step
      IMPORTING
        wf_obj        TYPE REF TO /benmsg/cl_wf_obj
        step          TYPE /benmsg/swf_bd_step
      RETURNING
        VALUE(result) TYPE tswhactor.

    METHODS forecasted_steps
      IMPORTING
        current_step  TYPE /benmsg/swf_bd_step
        wf_obj        TYPE REF TO /benmsg/cl_wf_obj
      RETURNING
        VALUE(result) TYPE /benmsg/twf_rstep.

    "! agents and profiles for decision
    METHODS agents_and_profls_for_decision
      IMPORTING
        decision      TYPE /benmsg/swf_decision
        wf_obj        TYPE REF TO /benmsg/cl_wf_obj
      RETURNING
        VALUE(result) TYPE union_agents_profiles.

    METHODS sum_item_values
      IMPORTING
        purchase_requisition TYPE /benmsg/bapipr_s
      RETURNING
        VALUE(result)        TYPE /benmsg/bapimereqitem_s-value_item.

    METHODS process_id
      IMPORTING
        purchase_requisition_extension TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_ben_bapi_pr_get_detail
      RETURNING
        VALUE(result)                  TYPE string.

    METHODS roles_of_requester
      IMPORTING
        purchase_requsition TYPE /benmsg/bapipr_s
      RETURNING
        VALUE(result)       TYPE string_table.

    METHODS has_material_group_user
      IMPORTING
        purchase_requisition TYPE /benmsg/bapipr_s
      RETURNING
        VALUE(result)        TYPE abap_bool.

    METHODS at_least_one_match
      IMPORTING
        actual_roles  TYPE string_table
        roles_range   TYPE rule-roles
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS agents_appear_later_in_wf
      IMPORTING
        step          TYPE /benmsg/swf_bd_step
        wf_obj        TYPE REF TO /benmsg/cl_wf_obj
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS profiles_from_agents
      IMPORTING
        agents        TYPE tswhactor
      RETURNING
        VALUE(result) TYPE sorted_profiles.

ENDCLASS.



CLASS zrwtha_resp_cwf_ecc_preq IMPLEMENTATION.


  METHOD /benmsg/if_wf_bd_resp~get_responsible_agents.
    " other impl. as reference:
*    /BENMSG/CL_WFBI_RESP_CWF_PR
*    zcon_wf_resp_cwf_ecc_preq
*    ZBOSCH_CL_RESP_CWF_ECC_PREQ
*    ZCL_OGE_CWF_ECC_PREQ
*    ZDEMO_RESP_CWF_ECC_PREQ
*    ZZMKL_WF_RESP_CWF_Edecision

    DATA(agents_and_profiles) = agents_and_profls_for_decision(
      decision = CORRESPONDING #( is_decision )
      wf_obj = io_wf_obj ).

    "Responsible agents should not have to release a workitem twice. Therefore the responsible agents for the forecasted
    "steps are determined and removed from the current step. In conjunction with the method 'is_step_valid', steps in
    "which all the agents also appear later are skipped, and the steps that remain contain only the agents which are not
    "appearing in a later step.
    DATA(forecasted_steps) = forecasted_steps( current_step = CORRESPONDING #( is_step ) wf_obj = io_wf_obj ).
    DATA agents_forecasted_steps TYPE tswhactor.
    LOOP AT forecasted_steps ASSIGNING FIELD-SYMBOL(<forecasted_step>).
      INSERT LINES OF agents_for_step( step = CORRESPONDING #( <forecasted_step> ) wf_obj = io_wf_obj )
        INTO TABLE agents_forecasted_steps.
    ENDLOOP.
    DATA(unique_agents_forecasted_steps) = agents=>unique( agents_forecasted_steps ).

    DATA agents_appearing_later_in_wf TYPE tswhactor.
    LOOP AT agents_and_profiles-agents ASSIGNING FIELD-SYMBOL(<agent>).
      IF line_exists( unique_agents_forecasted_steps[ table_line = <agent> ] ).
        INSERT <agent> INTO TABLE agents_appearing_later_in_wf.
      ENDIF.
    ENDLOOP.

    LOOP AT agents_appearing_later_in_wf ASSIGNING <agent>.
      DELETE agents_and_profiles-agents WHERE table_line = <agent>.
    ENDLOOP.

    et_agents = agents_and_profiles-agents.
    et_profiles = profiles_from_agents( et_agents ).
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_reapproval_required.

    cv_required = abap_false.

  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_step_valid.
    DATA: ls_preq     TYPE /benmsg/bapipr_s,
          ls_bapi_ben TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_ben_bapi_pr_get_detail.
    mo_pr = CAST /benmsg/cl_wf_obj_cwf_ec_preq( io_wf_obj ).
    mo_pr->ecc_get_detail( EXPORTING iv_cwf_filter = 'X'
                           IMPORTING es_bapi_ben = ls_bapi_ben
                                     et_item = ls_preq-pritemexp
                                     et_account = ls_preq-praccount ).

    " For each step a set of rules is evaluated to determine if it is skipped or not
    " Values to be compared with expected ranges to satisfy a given rule for a step are collected here
    " Check the ABAPDoc of the type of this variable for further info
    DATA(rule_parameters_of_step) = VALUE rule_parameters(
      process_id = process_id( ls_bapi_ben )
      value = sum_item_values( ls_preq )
      roles =  roles_of_requester( ls_preq )
      responsibility = is_step-responsibility
      has_material_group_user = has_material_group_user( ls_preq )
      all_agents_appear_later_in_wf = agents_appear_later_in_wf( step = is_step wf_obj = io_wf_obj ) ).

    " Expected ranges of values to be checked in rules cannot be declared as constants, hence the static helper method
    DATA(r) = rule_parameter=>value( ).
    " Rules are evaluated in listed order. Earlier rules are overwritten by later rules
    " Check line type of this variable for further info
    DATA(rules) = VALUE rules(
      ( process_id = r-excluding_emergency_orders
        value = r-any_value
        roles = r-all_roles
        responsibility = r-four_step_workflow
        has_material_group_user = r-true_or_false
        agents_appear_later_in_wf = r-false
        result = abap_true )

      ( process_id = r-all_process_ids
        value = r-under_500
        roles = r-role_00
        responsibility = r-one_step_workflow
        has_material_group_user = r-true_or_false
        agents_appear_later_in_wf = r-true_or_false
        result = abap_true )

      ( process_id = r-all_process_ids
        value = r-under_500
        roles = r-roles_03_04_05
        responsibility = r-one_step_workflow
        has_material_group_user = r-true_or_false
        agents_appear_later_in_wf = r-true_or_false
        result = abap_true )

      ( process_id = r-emergency_order
        value = r-under_500
        roles = r-all_roles
        responsibility = r-five_step_workflow
        has_material_group_user = r-true_or_false
        agents_appear_later_in_wf = r-true_or_false
        result = abap_false )

      ( process_id = r-emergency_order
        value = r-between_500_and_1k
        roles = r-all_roles
        responsibility = r-one_step_workflow
        has_material_group_user = r-true_or_false
        agents_appear_later_in_wf = r-true_or_false
        result = abap_true )

      ( process_id = r-excluding_emergency_orders
        value = r-between_500_and_1k
        roles = r-all_roles
        responsibility = r-three_step_workflow
        has_material_group_user = r-true
        agents_appear_later_in_wf = r-false
        result = abap_true )

      ( process_id = r-excluding_emergency_orders
        value = r-between_1k_and_10k
        roles = r-all_roles
        responsibility = r-four_step_workflow
        has_material_group_user = r-true
        agents_appear_later_in_wf = r-false
        result = abap_true ) ).

    CLEAR cv_valid.
    LOOP AT rules ASSIGNING FIELD-SYMBOL(<rule>).
      " for debugging the rules
      DATA does_rule_apply_to TYPE rule_applies_for_debug.
      does_rule_apply_to-process_id = xsdbool( rule_parameters_of_step-process_id IN <rule>-process_id ).
      does_rule_apply_to-value = xsdbool( rule_parameters_of_step-value IN <rule>-value ).
      does_rule_apply_to-roles = xsdbool(
        at_least_one_match( actual_roles = rule_parameters_of_step-roles roles_range = <rule>-roles ) ).
      does_rule_apply_to-responsibility = xsdbool( rule_parameters_of_step-responsibility IN <rule>-responsibility ).
      does_rule_apply_to-has_material_group_user = xsdbool(
        rule_parameters_of_step-has_material_group_user IN <rule>-has_material_group_user ).
      does_rule_apply_to-all_agents_appear_later_in_wf = xsdbool(
        rule_parameters_of_step-all_agents_appear_later_in_wf IN <rule>-agents_appear_later_in_wf ).

      IF  does_rule_apply_to-process_id = abap_true
      AND does_rule_apply_to-value = abap_true
      AND does_rule_apply_to-roles = abap_true
      AND does_rule_apply_to-responsibility = abap_true
      AND does_rule_apply_to-has_material_group_user = abap_true
      AND does_rule_apply_to-all_agents_appear_later_in_wf = abap_true.
        cv_valid = <rule>-result.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~map_items_to_decisions.

    DATA: lr_map     TYPE REF TO /benmsg/swf_bd_dec_itmmap,
          ls_itm_map TYPE /benmsg/swf_bd_item_ref,
          ls_preq    TYPE /benmsg/bapipr_s,
          lr_item    TYPE REF TO /benmsg/bapimereqitem_s.

    DATA cost_center TYPE REF TO cost_center.
    DATA ls_mycart_struct TYPE /benmsg/cl_dc4_models=>ts_my_cart.

    " zcon_wf_resp_cwf_ecc_preq
    ls_itm_map-otype = 'BUS2009'. " Purchase Requisition Item
    me->mo_pr = CAST /benmsg/cl_wf_obj_cwf_ec_preq( io_wf_obj ).
    me->mo_pr->ecc_get_detail( EXPORTING iv_cwf_filter = 'X'
                               IMPORTING et_item = ls_preq-pritemexp
                                         et_account = ls_preq-praccount
                                         et_mycart = ls_mycart_struct ).

    DATA(lv_ext_id) = |{ is_step-responsibility }|.
    DATA(lo_ws) = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = me->mo_pr->ms_cwf_hdr-customer_id
                                                  iv_cust_sys_id = me->mo_pr->ms_cwf_hdr-cust_sys_id
                                                  iv_remote_sys  = me->mo_pr->ms_cwf_hdr-remote_sys ).
    LOOP AT ls_preq-pritemexp REFERENCE INTO lr_item WHERE delete_ind EQ space.
      TRY.
          cost_center = cost_center=>from_purchase_requisition_item(
            item = lr_item->*
            item_accounts = ls_preq-praccount
            endpoint = lo_ws ).
        CATCH invalid_cost_center
              missing_user_configuration.
          CONTINUE.
      ENDTRY.

      IF is_step-responsibility = 'ZRWTHA_PG_TECHNISCH' OR
         is_step-responsibility = 'ZRWTHA_KAUFM' OR
         is_step-responsibility = 'ZRWTHA_ALL' OR
         is_step-responsibility = 'ZRWTHA_SACHLICH'.

        lv_ext_id = |{ is_step-responsibility }_{ cost_center->external_value( ) }|.
      ELSEIF is_step-responsibility = 'ZRWTHA_WARENGRP'.
        " group positions by kostl,matkl
        DATA(lv_preq_name) = get_user_from_kostl_matkl( iv_kostl = cost_center
                                                        iv_matkl = lr_item->matl_group ).
        CHECK lv_preq_name IS NOT INITIAL.

*        lv_ext_id = |ZRWTHA_WARENGRP_{ lv_kostl }_{ lr_item->matl_group }|.
        lv_ext_id = |ZRWTHA_WARENGRP_{ lv_preq_name }|. " there is only one, this is why we use this logic
      ENDIF.

      READ TABLE ct_item_map REFERENCE INTO lr_map WITH KEY external_id = lv_ext_id.
      IF ct_item_map IS INITIAL OR sy-subrc IS NOT INITIAL.
        INSERT INITIAL LINE INTO TABLE ct_item_map REFERENCE INTO lr_map.
        lr_map->external_id = lv_ext_id .
      ENDIF.

      ls_itm_map-objid = |{ me->mo_pr->ms_cwf_hdr-remote_id(10) }{ lr_item->preq_item }|.
      APPEND ls_itm_map TO lr_map->item_map.

    ENDLOOP.

  ENDMETHOD.


  METHOD agents_and_profls_for_decision.
    DATA ls_preq TYPE /benmsg/bapipr_s.
    DATA lt_preq_names TYPE zrwtha_resp_cwf_ecc_preq=>tt_users.

    mo_pr = CAST /benmsg/cl_wf_obj_cwf_ec_preq( wf_obj ).
    mo_pr->ecc_get_detail( EXPORTING iv_cwf_filter = 'X'
                           IMPORTING et_item = ls_preq-pritemexp
                                     et_account = ls_preq-praccount ).

    IF decision-responsibility = 'ZRWTHA_PG_TECHNISCH' OR
       decision-responsibility = 'ZRWTHA_KAUFM' OR
       decision-responsibility = 'ZRWTHA_ALL' OR
       decision-responsibility = 'ZRWTHA_SACHLICH'.

      SPLIT decision-external_id AT '_' INTO TABLE DATA(lt_split).
      TRY.
          IF decision-responsibility = 'ZRWTHA_PG_TECHNISCH'.
            DATA(lv_kostl) = lt_split[ 4 ].
          ELSE.
            lv_kostl = lt_split[ 3 ].
          ENDIF.
        CATCH cx_sy_itab_line_not_found.
          " its fine to do nothing here
      ENDTRY.

      TRY.
          lt_preq_names = cached_users_from_role[ iv_kostl = lv_kostl iv_role = decision-responsibility ]-result.
        CATCH cx_sy_itab_line_not_found.
          lt_preq_names = get_users_from_role(
                       iv_kostl = CONV #( lv_kostl )
                       iv_role  = CONV #( decision-responsibility ) ).
          IF lv_kostl IS NOT INITIAL.
            INSERT VALUE #( iv_kostl = lv_kostl iv_role = decision-responsibility result = lt_preq_names )
              INTO TABLE cached_users_from_role.
          ENDIF.
      ENDTRY.

    ELSEIF decision-responsibility = 'ZRWTHA_WARENGRP'.
      TRY.
          SPLIT decision-external_id AT '_' INTO TABLE lt_split.
          DATA(lv_preq_name) = lt_split[ 3 ]. " only one, this is why this is fine
          CHECK lv_preq_name IS NOT INITIAL.
          APPEND lv_preq_name TO lt_preq_names.
        CATCH cx_sy_itab_line_not_found.
          " its fine to do nothing here
      ENDTRY.
    ENDIF.

    DATA unique_agents TYPE sorted_tswhactor.
    LOOP AT lt_preq_names ASSIGNING FIELD-SYMBOL(<agent>).
      INSERT VALUE #( otype = /benmsg/if_wf_c=>obj_cat-user objid = <agent> ) INTO TABLE unique_agents.
    ENDLOOP.
    result-agents = unique_agents.

    result-profiles = profiles_from_agents( result-agents ).
  ENDMETHOD.


  METHOD agents_for_step.
    /benmsg/cl_wf_resp_ctrl=>get_api( )->map_items_to_decisions(
      EXPORTING
        io_wf_obj    = wf_obj
        is_step      = VALUE #( BASE CORRESPONDING #( step ) decide_by_items = abap_true )
      IMPORTING
        et_decisions = DATA(decisions) ).

    LOOP AT decisions ASSIGNING FIELD-SYMBOL(<decision>).
      DATA(agents) = agents_and_profls_for_decision( decision = <decision> wf_obj   = wf_obj ).
      INSERT LINES OF agents-agents INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD forecasted_steps.
    CHECK current_step-step_idx_cfg IS NOT INITIAL.
    wf_obj->/benmsg/if_wf_obj~get_forecast( CHANGING ct_steps = result ).
    DELETE result WHERE step_idx_cfg <= current_step-step_idx_cfg.
  ENDMETHOD.


  METHOD get_roles_from_user.
    DATA: BEGIN OF ls_crud_imp,
            kostl TYPE kostl,
            user  LIKE sy-uname,
          END OF ls_crud_imp,
          BEGIN OF ls_crud_exp,
            roles TYPE spers_alst,
          END OF ls_crud_exp.

    DATA(lo_ws) = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = me->mo_pr->ms_cwf_hdr-customer_id
                                                    iv_cust_sys_id = me->mo_pr->ms_cwf_hdr-cust_sys_id
                                                    iv_remote_sys  = me->mo_pr->ms_cwf_hdr-remote_sys ).

    ls_crud_imp-kostl = iv_kostl.
    ls_crud_imp-user = iv_uname.

    lo_ws->get_external_data( EXPORTING iv_action   = 'RolesFromUser'
                                        iv_object   = 'BEN_DATA'
                                        iv_data     = ls_crud_imp
                              IMPORTING ev_data     = ls_crud_exp ).

    ret = ls_crud_exp-roles.
  ENDMETHOD.


  METHOD get_users_from_role.
    DATA: BEGIN OF ls_crud_imp,
            kostl TYPE kostl,
            role  TYPE agr_name,
          END OF ls_crud_imp,
          BEGIN OF ls_crud_exp,
            users TYPE tt_users,
          END OF ls_crud_exp.

    DATA(lo_ws) = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = me->mo_pr->ms_cwf_hdr-customer_id
                                                    iv_cust_sys_id = me->mo_pr->ms_cwf_hdr-cust_sys_id
                                                    iv_remote_sys  = me->mo_pr->ms_cwf_hdr-remote_sys ).
    ls_crud_imp-role = iv_role.
    IF iv_role = 'ZRWTHA_PG_TECHNISCH'.
      ls_crud_imp-role = 'Z_GHBS:04_GENEHMIGUNG-FACHL'.
    ELSEIF iv_role = 'ZRWTHA_KAUFM'.
      ls_crud_imp-role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM'.
    ELSEIF iv_role = 'ZRWTHA_SACHLICH'.
      ls_crud_imp-role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER'.
    ELSEIF iv_role = 'ZRWTHA_ALL'.
      ls_crud_imp-role = 'ALL'.
    ENDIF.

    ls_crud_imp-kostl = iv_kostl.

    lo_ws->get_external_data( EXPORTING iv_action   = 'UsersFromRoles'
                                        iv_object   = 'BEN_DATA'
                                        iv_data     = ls_crud_imp
                              IMPORTING ev_data     = ls_crud_exp ).

    ret = ls_crud_exp-users.
  ENDMETHOD.


  METHOD get_user_from_kostl_matkl.
    DATA: BEGIN OF ls_crud_imp,
            kostl TYPE kostl,
            matkl TYPE matkl,
          END OF ls_crud_imp,
          BEGIN OF ls_crud_exp,
            freig TYPE xubname,
          END OF ls_crud_exp.

    DATA(lo_ws) = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = me->mo_pr->ms_cwf_hdr-customer_id
                                                    iv_cust_sys_id = me->mo_pr->ms_cwf_hdr-cust_sys_id
                                                    iv_remote_sys  = me->mo_pr->ms_cwf_hdr-remote_sys ).

    ls_crud_imp-kostl = iv_kostl->internal_value( ).
    ls_crud_imp-matkl = iv_matkl.

    lo_ws->get_external_data( EXPORTING iv_action   = 'FreigFromKostlMatkl'
                                        iv_object   = 'BEN_DATA'
                                        iv_data     = ls_crud_imp
                              IMPORTING ev_data     = ls_crud_exp ).

    ret = ls_crud_exp-freig.
  ENDMETHOD.


  METHOD sum_item_values.
    LOOP AT purchase_requisition-pritemexp ASSIGNING FIELD-SYMBOL(<item>) WHERE delete_ind = abap_false.
      result = result + <item>-value_item.
    ENDLOOP.
  ENDMETHOD.


  METHOD process_id.
    LOOP AT purchase_requisition_extension-extensionout ASSIGNING FIELD-SYMBOL(<item>) WHERE structure = 'BAPI_TE_MEREQITEM'.
      result = <item>-cust_fields[ component_name = 'ZZ_BENGRP' ]-component_value.
    ENDLOOP.
  ENDMETHOD.


  METHOD roles_of_requester.
*    DATA(requester) = purchase_requsition-pritemexp[ 1 ]-preq_name.
*    DATA(cost_center) = COND kostl( LET psp = purchase_requsition-praccount[ 1 ]-wbs_element+5(6) IN
*                                    WHEN psp IS NOT INITIAL
*                                    THEN psp
*                                    ELSE get_kostl_from_user( iv_uname = requester ) ).
*    result = get_roles_from_user( iv_kostl = cost_center iv_uname = requester ).
  ENDMETHOD.


  METHOD has_material_group_user.
    DATA(lo_ws) = NEW /benmsg/cl_wsi_obj_cust_data( iv_customer_id = me->mo_pr->ms_cwf_hdr-customer_id
                                                    iv_cust_sys_id = me->mo_pr->ms_cwf_hdr-cust_sys_id
                                                    iv_remote_sys  = me->mo_pr->ms_cwf_hdr-remote_sys ).
    LOOP AT purchase_requisition-pritemexp ASSIGNING FIELD-SYMBOL(<item>) WHERE delete_ind = abap_false.
      TRY.
          result = xsdbool(
            get_user_from_kostl_matkl(
              iv_kostl = cost_center=>from_purchase_requisition_item(
                item = <item>
                item_accounts = purchase_requisition-praccount
                endpoint = lo_ws )
              iv_matkl = <item>-matl_group ) IS NOT INITIAL ).
        CATCH invalid_cost_center
              missing_user_configuration.
          CONTINUE.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD at_least_one_match.
    " if any role is supposed to match, than having no roles matches as well
    IF actual_roles IS INITIAL
    AND roles_range IS INITIAL.
      result = abap_true.
    ELSE.
      LOOP AT actual_roles ASSIGNING FIELD-SYMBOL(<role>).
        IF <role> IN roles_range.
          result = abap_true.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD agents_appear_later_in_wf.
    DATA(agents_current_step) = agents_for_step( step = step wf_obj = wf_obj ).
    DATA(unique_agents_current_step) = agents=>unique( agents_current_step ).
    DATA(forecasted_steps) = forecasted_steps( current_step = step wf_obj = wf_obj ).

    DATA agents_forecasted_steps TYPE tswhactor.
    LOOP AT forecasted_steps ASSIGNING FIELD-SYMBOL(<forecasted_step>).
      INSERT LINES OF agents_for_step( step = CORRESPONDING #( <forecasted_step> ) wf_obj = wf_obj )
        INTO TABLE agents_forecasted_steps.
    ENDLOOP.
    DATA(unique_agents_forecasted_steps) = agents=>unique( agents_forecasted_steps ).

    IF unique_agents_current_step IS NOT INITIAL AND unique_agents_forecasted_steps IS NOT INITIAL.
      LOOP AT unique_agents_forecasted_steps ASSIGNING FIELD-SYMBOL(<agent>).
        DELETE unique_agents_current_step WHERE table_line = <agent>.
      ENDLOOP.

      IF unique_agents_current_step IS INITIAL.
        result = abap_true.
      ELSE.
        result = abap_false.
      ENDIF.
    ELSE.
      result = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD profiles_from_agents.
    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      INSERT VALUE #( profile = <agent>-objid proftype = /benmsg/if_wf_c=>obj_cat-cse_us ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
