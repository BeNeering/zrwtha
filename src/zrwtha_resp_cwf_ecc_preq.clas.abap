CLASS zrwtha_resp_cwf_ecc_preq DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES /benmsg/if_wf_bd_resp.
    INTERFACES if_badi_interface.
    TYPES tt_users TYPE TABLE OF xubname WITH DEFAULT KEY .
    TYPES: BEGIN OF responsibility,
             responsible_agent TYPE xubname,
             cost_center       TYPE kostl,
             role              TYPE agr_name,
           END OF responsibility.
    TYPES responsibilities TYPE HASHED TABLE OF responsibility WITH UNIQUE KEY responsible_agent cost_center role.
    CLASS-DATA cached_responsibilities TYPE responsibilities.

    TYPES: BEGIN OF material_group_approver_tuple,
             kostl TYPE kostl,
             matkl TYPE matkl,
             freig TYPE c LENGTH 12,
           END OF material_group_approver_tuple,
           material_group_approver_map TYPE HASHED TABLE OF material_group_approver_tuple WITH UNIQUE KEY kostl matkl.
    CLASS-DATA cached_material_grp_approv_map TYPE material_group_approver_map.

    METHODS constructor
      IMPORTING
        customer_wf_customizing TYPE REF TO /benmsg/cl_wsi_obj_cust_data OPTIONAL.
  PROTECTED SECTION.
    DATA purchase_requisition TYPE REF TO /benmsg/cl_wf_obj_cwf_ec_preq .

    METHODS users_for_responsibility
      IMPORTING
        cost_center      TYPE REF TO cost_center
        i_responsibility TYPE agr_name
      RETURNING
        VALUE(result)    TYPE tt_users.

  PRIVATE SECTION.
    CLASS-DATA customer_wf_customizing TYPE REF TO /benmsg/cl_wsi_obj_cust_data.

    METHODS roles_of_requester
      IMPORTING
        cost_center   TYPE REF TO cost_center
        requester     TYPE REF TO requester
      RETURNING
        VALUE(result) TYPE spers_alst.

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
    METHODS agents_for_decision
      IMPORTING
        decision      TYPE /benmsg/swf_decision
      RETURNING
        VALUE(result) TYPE tswhactor.

    METHODS process_id
      IMPORTING
        purchase_requisition_extension TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_ben_bapi_pr_get_detail
      RETURNING
        VALUE(result)                  TYPE string.

    METHODS at_least_one_match
      IMPORTING
        actual_roles  TYPE string_table
        roles_range   TYPE rule-roles
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS profiles_from_agents
      IMPORTING
        agents        TYPE tswhactor
      RETURNING
        VALUE(result) TYPE sorted_profiles.

    METHODS cached_customer_wf_customizing
      RETURNING
        VALUE(result) TYPE REF TO /benmsg/cl_wsi_obj_cust_data.
    METHODS predicted_workflow_steps
      IMPORTING
        workflow_shape TYPE char5
      RETURNING
        VALUE(result)  TYPE predicted_workflow_steps.

    METHODS workflow_shape_from_purch_req
      IMPORTING
        purchase_requisition TYPE REF TO /benmsg/cl_wf_obj_cwf_ec_preq
      RETURNING
        VALUE(result)        TYPE char5.

    METHODS predicted_uncompacted_workflow
      IMPORTING
        predicted_workflow_steps TYPE predicted_workflow_steps
        workflow_object          TYPE REF TO /benmsg/cl_wf_obj
      RETURNING
        VALUE(result)            TYPE flat_workflow.

    METHODS compacted_workflow
      IMPORTING
        predicted_uncompacted_workflow TYPE flat_workflow
      RETURNING
        VALUE(result)                  TYPE flat_workflow.

    METHODS cache_material_grp_approv_map.

    METHODS cache_responsibilities.

    METHODS material_grp_requires_approval
      IMPORTING
        material_group TYPE /benmsg/bapimereqitem_s-matl_group
        cost_center    TYPE REF TO cost_center
      RETURNING
        VALUE(result)  TYPE abap_bool.
    METHODS material_group_approver
      IMPORTING
        material_group TYPE /benmsg/bapimereqitem_s-matl_group
        cost_center    TYPE REF TO cost_center
      RETURNING
        VALUE(result)  TYPE xubname.

ENDCLASS.



CLASS zrwtha_resp_cwf_ecc_preq IMPLEMENTATION.

  METHOD constructor.
    IF customer_wf_customizing IS SUPPLIED.
      me->customer_wf_customizing = customer_wf_customizing.
    ENDIF.
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~get_responsible_agents.
    me->purchase_requisition = CAST /benmsg/cl_wf_obj_cwf_ec_preq( io_wf_obj ).

    DATA(workflow_shape) = workflow_shape_from_purch_req( purchase_requisition ).

    DATA(predicted_uncompacted_workflow) = predicted_uncompacted_workflow(
      predicted_workflow_steps = predicted_workflow_steps( workflow_shape )
      workflow_object          = io_wf_obj ).

    DATA(compacted_workflow) = compacted_workflow( predicted_uncompacted_workflow ).

    CLEAR et_agents.
    LOOP AT compacted_workflow ASSIGNING FIELD-SYMBOL(<x>) WHERE decision_external_id = is_decision-external_id.
      INSERT VALUE #( otype = /benmsg/if_wf_c=>obj_cat-user objid = <x>-agent_objid ) INTO TABLE et_agents.
    ENDLOOP.
    et_profiles = profiles_from_agents( et_agents ).
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_reapproval_required.
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~is_step_valid.
    me->purchase_requisition = CAST /benmsg/cl_wf_obj_cwf_ec_preq( io_wf_obj ).

    DATA(workflow_shape) = workflow_shape_from_purch_req( purchase_requisition ).

    DATA(predicted_uncompacted_workflow) = predicted_uncompacted_workflow(
      predicted_workflow_steps = predicted_workflow_steps( workflow_shape )
      workflow_object          = io_wf_obj ).

    DATA(compacted_workflow) = compacted_workflow( predicted_uncompacted_workflow ).

    IF line_exists( compacted_workflow[ step_responsibility = is_step-responsibility ] ).
      cv_valid = abap_true.
    ELSE.
      cv_valid = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD /benmsg/if_wf_bd_resp~map_items_to_decisions.
    DATA: map                  TYPE REF TO /benmsg/swf_bd_dec_itmmap,
          purchase_requisition TYPE /benmsg/bapipr_s,
          item                 TYPE REF TO /benmsg/bapimereqitem_s,
          cost_center          TYPE REF TO cost_center.

    CLEAR ct_item_map.
    me->purchase_requisition = CAST /benmsg/cl_wf_obj_cwf_ec_preq( io_wf_obj ).
    me->purchase_requisition->ecc_get_detail(
      EXPORTING
        iv_cwf_filter = 'X'
      IMPORTING
        et_item = purchase_requisition-pritemexp
        et_account = purchase_requisition-praccount
        et_mycart = DATA(mycart) ).

    TRY.
        DATA(requester) = requester=>from_purchase_requisition_item(
          item            = purchase_requisition-pritemexp
          mycart          = mycart ).
        cost_center = cost_center=>from_item_or_requester(
          item                       = purchase_requisition-pritemexp[ delete_ind = abap_false ]
          item_accounts              = purchase_requisition-praccount
          requester                  = requester
          customer_wf_customizing    = cached_customer_wf_customizing( ) ).
      CATCH empty_requester
            missing_user_configuration
            cx_sy_itab_line_not_found INTO DATA(exc).
        " The requester must be supplied, the cost center must be present in the first (as well as subsequent items) or
        " the cost center must be derivable from the requester and there must be purchase requisition items in the first
        " place. If those preconditions are not met, execution cannot continue.
        RAISE EXCEPTION TYPE precondition_violated EXPORTING previous = exc.
    ENDTRY.
    DATA(external_id) = |{ is_step-responsibility }|.
    LOOP AT purchase_requisition-pritemexp REFERENCE INTO item WHERE delete_ind EQ space.
      CASE is_step-responsibility.
        WHEN  responsibility-all
        OR    responsibility-kauf
        OR    responsibility-sach
        OR    responsibility-tech.
          external_id = |{ is_step-responsibility }_{ cost_center->external_value( ) }|.
        WHEN responsibility-material_group.
          CHECK item->matl_group IS NOT INITIAL.
          DATA(material_group_approver) = material_group_approver(
            material_group = item->matl_group
            cost_center    = cost_center ).
          CHECK material_group_approver IS NOT INITIAL.
          external_id = |ZRWTHA_WARENGRP_{ material_group_approver }|.
      ENDCASE.

      READ TABLE ct_item_map REFERENCE INTO map WITH KEY external_id = external_id.
      IF ct_item_map IS INITIAL OR sy-subrc IS NOT INITIAL.
        INSERT INITIAL LINE INTO TABLE ct_item_map REFERENCE INTO map.
        map->external_id = external_id .
      ENDIF.
      INSERT VALUE #(
        otype = 'BUS2009'
        objid = |{ me->purchase_requisition->ms_cwf_hdr-remote_id(10) }{ item->preq_item }| )
        INTO TABLE map->item_map.
    ENDLOOP.
  ENDMETHOD.


  METHOD agents_for_decision.
    DATA users_for_role TYPE zrwtha_resp_cwf_ecc_preq=>tt_users.

    DATA(cost_center_or_agent) = substring_after( val = decision-external_id sub = |{ decision-responsibility }_| ).
    IF decision-responsibility = responsibility-tech OR
       decision-responsibility = responsibility-kauf OR
       decision-responsibility = responsibility-all OR
       decision-responsibility = responsibility-sach.
      TRY.
          users_for_role = users_for_responsibility(
            cost_center = NEW #( CONV #( cost_center_or_agent ) )
            i_responsibility  = CONV #( decision-responsibility ) ).
        CATCH invalid_cost_center.
          RAISE EXCEPTION TYPE invariant_violated.
      ENDTRY.
    ELSEIF decision-responsibility = 'ZRWTHA_WARENGRP'.
      IF cost_center_or_agent IS NOT INITIAL.
        INSERT CONV #( cost_center_or_agent ) INTO TABLE users_for_role.
      ELSE.
        RETURN.
      ENDIF.
    ENDIF.

    DATA unique_agents TYPE sorted_tswhactor.
    LOOP AT users_for_role ASSIGNING FIELD-SYMBOL(<agent>).
      INSERT VALUE #( otype = /benmsg/if_wf_c=>obj_cat-user objid = <agent> ) INTO TABLE unique_agents.
    ENDLOOP.

    result = unique_agents.
  ENDMETHOD.


  METHOD agents_for_step.
    /benmsg/cl_wf_resp_ctrl=>get_api( )->map_items_to_decisions(
      EXPORTING
        io_wf_obj    = wf_obj
        is_step      = VALUE #( BASE CORRESPONDING #( step ) decide_by_items = abap_true )
      IMPORTING
        et_decisions = DATA(decisions) ).

    LOOP AT decisions ASSIGNING FIELD-SYMBOL(<decision>).
      DATA(agents) = agents_for_decision( decision = <decision> ).
      INSERT LINES OF agents INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD forecasted_steps.
    CHECK current_step-step_idx_cfg IS NOT INITIAL.
    wf_obj->/benmsg/if_wf_obj~get_forecast( CHANGING ct_steps = result ).
    DELETE result WHERE step_idx_cfg <= current_step-step_idx_cfg.
  ENDMETHOD.


  METHOD roles_of_requester.
    LOOP AT cached_responsibilities ASSIGNING FIELD-SYMBOL(<responsibility>)
      WHERE cost_center = cost_center->internal_value( )
      AND   responsible_agent = requester->user_name.
      INSERT <responsibility>-role INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD users_for_responsibility.
    FIELD-SYMBOLS <responsiblity> TYPE zrwtha_resp_cwf_ecc_preq=>responsibility.

    DATA(role) = SWITCH agr_name( i_responsibility
      WHEN responsibility-tech THEN 'Z_GHBS:04_GENEHMIGUNG-FACHL'
      WHEN responsibility-kauf THEN 'Z_GHBS:03_GENEHMIGUNG-KAUFM'
      WHEN responsibility-sach THEN 'Z_GHBS:05_ZEICHNUNGSBEFUGTER'
      WHEN responsibility-all  THEN 'ALL' ).

    IF i_responsibility = responsibility-all.
      LOOP AT cached_responsibilities ASSIGNING <responsiblity>
        WHERE   cost_center = cost_center->internal_value( ).
        INSERT <responsiblity>-responsible_agent INTO TABLE result.
      ENDLOOP.
    ELSE.
      LOOP AT cached_responsibilities ASSIGNING <responsiblity>
        WHERE role = role
        AND   cost_center = cost_center->internal_value( ).
        INSERT <responsiblity>-responsible_agent INTO TABLE result.
      ENDLOOP.
      IF sy-subrc <> 0.
        INSERT CONV #( 'FS454989' ) INTO TABLE result.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD process_id.
    LOOP AT purchase_requisition_extension-extensionout ASSIGNING FIELD-SYMBOL(<item>) WHERE structure = 'BAPI_TE_MEREQITEM'.
      result = <item>-cust_fields[ component_name = 'ZZ_BENGRP' ]-component_value.
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


  METHOD profiles_from_agents.
    LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
      INSERT VALUE #( profile = <agent>-objid proftype = /benmsg/if_wf_c=>obj_cat-cse_us ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD cached_customer_wf_customizing.
    IF me->customer_wf_customizing IS INITIAL.
      me->customer_wf_customizing = NEW /benmsg/cl_wsi_obj_cust_data(
        iv_customer_id = me->purchase_requisition->ms_cwf_hdr-customer_id
        iv_cust_sys_id = me->purchase_requisition->ms_cwf_hdr-cust_sys_id
        iv_remote_sys  = me->purchase_requisition->ms_cwf_hdr-remote_sys ).
    ENDIF.
    result = me->customer_wf_customizing.

    IF cached_responsibilities IS INITIAL.
      cache_responsibilities( ).
    ENDIF.
    IF cached_material_grp_approv_map IS INITIAL.
      cache_material_grp_approv_map( ).
    ENDIF.
  ENDMETHOD.


  METHOD predicted_workflow_steps.
    DATA: BEGIN OF workflow_step_schema,
            all            TYPE predicted_workflow_step,
            tech           TYPE predicted_workflow_step,
            kauf           TYPE predicted_workflow_step,
            material_group TYPE predicted_workflow_step,
            sach           TYPE predicted_workflow_step,
          END OF workflow_step_schema.

    "WARNING: this couples to the order of the steps and their index in the customizing of the workflow schema
    workflow_step_schema = VALUE #(
      all = VALUE #( responsibility = responsibility-all step_idx_cfg = 010 )
      tech = VALUE #( responsibility = responsibility-tech step_idx_cfg = 100 )
      kauf = VALUE #( responsibility = responsibility-kauf step_idx_cfg = 200 )
      material_group = VALUE #( responsibility = responsibility-material_group step_idx_cfg = 300 )
      sach = VALUE #( responsibility = responsibility-sach step_idx_cfg = 400 ) ).

    CASE workflow_shape.
      WHEN 'wf0'.
        result = VALUE #( ).
      WHEN 'wf1'.
        result = VALUE #( ( workflow_step_schema-material_group ) ).
      WHEN 'wf2'.
        result = VALUE #( ( workflow_step_schema-all ) ).
      WHEN 'wf3'.
        result = VALUE #( ( workflow_step_schema-all )
                          ( workflow_step_schema-material_group ) ).
      WHEN 'wf4'.
        result = VALUE #( ( workflow_step_schema-kauf )
                          ( workflow_step_schema-sach ) ).
      WHEN 'wf5'.
        result = VALUE #( ( workflow_step_schema-kauf )
                          ( workflow_step_schema-material_group )
                          ( workflow_step_schema-sach ) ).
      WHEN 'wf6'.
        result = VALUE #( ( workflow_step_schema-tech )
                          ( workflow_step_schema-kauf )
                          ( workflow_step_schema-sach ) ).
      WHEN 'wf7'.
        result = VALUE #( ( workflow_step_schema-tech )
                          ( workflow_step_schema-kauf )
                          ( workflow_step_schema-material_group )
                          ( workflow_step_schema-sach ) ).
      WHEN 'error'.
        " An explicit error was defined for the current parameters. Check the rules table.
        RAISE EXCEPTION TYPE precondition_violated.
      WHEN OTHERS.
        " Undefined workflow shape. Execution cannot proceed, because the evaluation of the given rules would not result
        " in a correct workflow.
        RAISE EXCEPTION TYPE invariant_violated.
    ENDCASE.
  ENDMETHOD.


  METHOD workflow_shape_from_purch_req.
    DATA rule_value TYPE workflow_rule.

    purchase_requisition->ecc_get_detail(
      EXPORTING
        iv_cwf_filter = 'X'
      IMPORTING
        et_item = DATA(items)
        et_account = DATA(accounts)
        et_mycart = DATA(mycart)
        es_bapi_ben = DATA(purchase_requisition_extension) ).
    IF process_id( purchase_requisition_extension ) = 'NOT'.
      rule_value-is_emergency_order = abap_true.
    ELSE.
      rule_value-is_emergency_order = abap_false.
    ENDIF.

    TRY.
        DATA(requester) = requester=>from_purchase_requisition_item(
          item = items
          mycart = mycart ).
        DATA(cost_center) = cost_center=>from_item_or_requester(
          item = items[ delete_ind = abap_false ]
          item_accounts = accounts
          requester = requester
          customer_wf_customizing = cached_customer_wf_customizing( ) ).
      CATCH empty_requester
            missing_user_configuration
            cx_sy_itab_line_not_found INTO DATA(exc).
        " The requester must be supplied, the cost center must be present in the first (as well as subsequent items) or
        " the cost center must be derivable from the requester and there must be purchase requisition items in the first
        " place. If those preconditions are not met, execution cannot continue.
        RAISE EXCEPTION TYPE precondition_violated EXPORTING previous = exc.
    ENDTRY.

    DATA sum_of_item_values TYPE /benmsg/bapimereqitem_s-value_item.
    LOOP AT items ASSIGNING FIELD-SYMBOL(<item>) WHERE delete_ind = abap_false.
      IF sy-tabix = 1.
        DATA(roles) = roles_of_requester( cost_center = cost_center requester = requester ).
        DATA(r) = requester_role_ranges=>value( ).
        rule_value-role_group = COND #(
          WHEN at_least_one_match( actual_roles = CONV #( roles ) roles_range = r-role_00 ) THEN '00-role'
          WHEN at_least_one_match( actual_roles = CONV #( roles ) roles_range = r-roles_03_04_05 ) THEN '03-05-role'
          ELSE 'no-role' ).
      ENDIF.

      sum_of_item_values = sum_of_item_values + COND #( WHEN <item>-value_item IS INITIAL
                                                        THEN <item>-preq_price
                                                        ELSE <item>-value_item ).
      IF <item>-matl_group IS NOT INITIAL.
        IF material_grp_requires_approval( material_group = <item>-matl_group cost_center = cost_center ).
          rule_value-material_grp_approval_required = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF sum_of_item_values < 500.
      rule_value-value_group = '<500'.
    ELSEIF sum_of_item_values >= 500 AND sum_of_item_values <= 1000.
      rule_value-value_group = '500-1k'.
    ELSEIF sum_of_item_values >= 1000 AND sum_of_item_values <= 10000.
      rule_value-value_group = '>1k-10k'.
    ELSEIF sum_of_item_values > 10000.
      rule_value-value_group = '>10k'.
    ENDIF.

    DATA(rules) = VALUE workflow_rules(
    ( value_group = '<500'    role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'wf1' )
    ( value_group = '<500'    role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'wf0' )
    ( value_group = '<500'    role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf5' )
    ( value_group = '<500'    role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf4' )
    ( value_group = '<500'    role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'wf1' )
    ( value_group = '<500'    role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'wf0' )
    ( value_group = '<500'    role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf3' )
    ( value_group = '<500'    role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf2' )
    ( value_group = '<500'    role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'wf1' )
    ( value_group = '<500'    role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'wf0' )
    ( value_group = '<500'    role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf1' )
    ( value_group = '<500'    role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf0' )
    ( value_group = '500-1k'  role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'wf3' )
    ( value_group = '500-1k'  role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'wf2' )
    ( value_group = '500-1k'  role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf5' )
    ( value_group = '500-1k'  role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf4' )
    ( value_group = '500-1k'  role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'wf3' )
    ( value_group = '500-1k'  role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'wf2' )
    ( value_group = '500-1k'  role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf5' )
    ( value_group = '500-1k'  role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf4' )
    ( value_group = '500-1k'  role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'wf3' )
    ( value_group = '500-1k'  role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'wf2' )
    ( value_group = '500-1k'  role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf5' )
    ( value_group = '500-1k'  role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf4' )
    ( value_group = '>1k-10k' role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'error' )
    ( value_group = '>1k-10k' role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'error' )
    ( value_group = '>1k-10k' role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf7' )
    ( value_group = '>1k-10k' role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf6' )
    ( value_group = '>1k-10k' role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'error' )
    ( value_group = '>1k-10k' role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'error' )
    ( value_group = '>1k-10k' role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf7' )
    ( value_group = '>1k-10k' role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf6' )
    ( value_group = '>1k-10k' role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'error' )
    ( value_group = '>1k-10k' role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'error' )
    ( value_group = '>1k-10k' role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf7' )
    ( value_group = '>1k-10k' role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf6' )
    ( value_group = '>10k'    role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'error' )
    ( value_group = '>10k'    role_group = 'no-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'error' )
    ( value_group = '>10k'    role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf7' )
    ( value_group = '>10k'    role_group = 'no-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf6' )
    ( value_group = '>10k'    role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'error' )
    ( value_group = '>10k'    role_group = '00-role'    is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'error' )
    ( value_group = '>10k'    role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf7' )
    ( value_group = '>10k'    role_group = '00-role'    is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf6' )
    ( value_group = '>10k'    role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_true  resulting_workflow = 'error' )
    ( value_group = '>10k'    role_group = '03-05-role' is_emergency_order = abap_true  material_grp_approval_required = abap_false resulting_workflow = 'error' )
    ( value_group = '>10k'    role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_true  resulting_workflow = 'wf7' )
    ( value_group = '>10k'    role_group = '03-05-role' is_emergency_order = abap_false material_grp_approval_required = abap_false resulting_workflow = 'wf6' ) ).

    result = rules[
      value_group = rule_value-value_group
      role_group = rule_value-role_group
      is_emergency_order = rule_value-is_emergency_order
      material_grp_approval_required = rule_value-material_grp_approval_required ]-resulting_workflow.
  ENDMETHOD.


  METHOD predicted_uncompacted_workflow.
    LOOP AT predicted_workflow_steps ASSIGNING FIELD-SYMBOL(<step>).
      DATA decision_item_map TYPE /benmsg/twf_bd_dec_itmmap.
      me->/benmsg/if_wf_bd_resp~map_items_to_decisions(
        EXPORTING
          io_wf_obj   = workflow_object
          is_step     = CORRESPONDING #( <step> )
        CHANGING
          ct_item_map = decision_item_map ).
      LOOP AT decision_item_map ASSIGNING FIELD-SYMBOL(<decision>).
        DATA(agents) = agents_for_decision(
          decision = VALUE #( BASE CORRESPONDING #( <decision> ) responsibility = <step>-responsibility )  ).
        LOOP AT agents ASSIGNING FIELD-SYMBOL(<agent>).
          INSERT VALUE #(
            step_index = <step>-step_idx_cfg
            step_responsibility = <step>-responsibility
            decision_external_id = <decision>-external_id
            agent_objid = <agent>-objid ) INTO TABLE result.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD compacted_workflow.
    result = predicted_uncompacted_workflow.
    LOOP AT predicted_uncompacted_workflow ASSIGNING FIELD-SYMBOL(<wf>).
      DELETE result WHERE agent_objid = <wf>-agent_objid AND step_index < <wf>-step_index.
    ENDLOOP.
  ENDMETHOD.


  METHOD cache_material_grp_approv_map.
    DATA: BEGIN OF response,
            mapping TYPE material_group_approver_map,
          END OF response.
    DATA dummy_request TYPE c LENGTH 1.
    me->customer_wf_customizing->get_external_data(
    EXPORTING
      iv_object   = 'BEN_DATA'
      iv_action   = 'MaterialGroupApproverMapping'
      iv_data     = dummy_request
    IMPORTING
      ev_data     = response ).
    cached_material_grp_approv_map = response-mapping.
  ENDMETHOD.


  METHOD cache_responsibilities.
    DATA: BEGIN OF response,
            mapping TYPE user_costcenter_role_mapping,
          END OF response.
    DATA dummy_request TYPE c LENGTH 1.
    me->customer_wf_customizing->get_external_data(
    EXPORTING
      iv_object   = 'BEN_DATA'
      iv_action   = 'UserCostCenterRoleMapping'
      iv_data     = dummy_request
    IMPORTING
      ev_data     = response ).
    cached_responsibilities = CORRESPONDING #( response-mapping MAPPING  responsible_agent = benutzer
                                                                  cost_center = kostenstelle
                                                                  role = rolle ).
  ENDMETHOD.


  METHOD material_grp_requires_approval.
    IF material_group_approver( material_group = material_group cost_center = cost_center ) IS NOT INITIAL.
      result = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD material_group_approver.
    READ TABLE cached_material_grp_approv_map WITH KEY kostl = cost_center->internal_value( ) matkl = material_group
      ASSIGNING FIELD-SYMBOL(<approval>).
    IF sy-subrc = 0.
      result = <approval>-freig.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
