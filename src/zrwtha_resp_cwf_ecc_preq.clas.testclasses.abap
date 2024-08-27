CLASS fake_purchase_requisition DEFINITION CREATE PUBLIC INHERITING FROM /benmsg/cl_wf_obj_cwf_ec_preq.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS ecc_get_detail REDEFINITION.
    METHODS on_object_save REDEFINITION.
    METHODS /benmsg/if_wf_obj~get_forecast REDEFINITION.
    DATA beneering_extensions TYPE /benmsg/cl_wsi_obj_ecc_pr=>ts_ben_bapi_pr_get_detail.
    DATA items TYPE /benmsg/bapimereqitem_t.
    DATA accounts TYPE /benmsg/bapimereqaccount_t.
    DATA current_step TYPE /benmsg/swf_bd_step.
ENDCLASS.

CLASS fake_purchase_requisition IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    me->ms_lpor-instid = 'TEST'.
    me->ms_lpor-typeid = '/BENMSG/CL_WF_OBJ_CWF_EC_PREQ'.
    get_process( ).
  ENDMETHOD.

  METHOD ecc_get_detail.
    ASSERT iv_cwf_filter = abap_true.
    es_bapi_ben = me->beneering_extensions.
    et_item = me->items.
    et_account = me->accounts.
  ENDMETHOD.

  METHOD /benmsg/if_wf_obj~get_forecast.
    TYPES sorted_wf_schema TYPE SORTED TABLE OF /benmsg/swf_rstep WITH UNIQUE KEY step_idx_cfg.
    DATA(wf_schema) = VALUE sorted_wf_schema(
      ( step_idx_cfg = '010' responsibility = 'ZRWTHA_ALL' )
      ( step_idx_cfg = '100' responsibility = 'ZRWTHA_PG_TECHNISCH' )
      ( step_idx_cfg = '200' responsibility = 'ZRWTHA_KAUFM' )
      ( step_idx_cfg = '300' responsibility = 'ZRWTHA_WARENGRP' )
      ( step_idx_cfg = '400' responsibility = 'ZRWTHA_SACHLICH' ) ).
    ct_steps = FILTER #( wf_schema WHERE step_idx_cfg > me->current_step-step_idx_cfg ).
  ENDMETHOD.

  METHOD on_object_save.
  ENDMETHOD.

ENDCLASS.



CLASS fake_customer_wf_customizing DEFINITION CREATE PUBLIC INHERITING FROM /benmsg/cl_wsi_obj_cust_data.

  PUBLIC SECTION.
    METHODS constructor.
    METHODS get_external_data REDEFINITION.
    TYPES: BEGIN OF material_group_tuple,
             kostl TYPE kostl,
             matkl TYPE matkl,
             freig TYPE xubname,
           END OF material_group_tuple,
           material_group_map TYPE SORTED TABLE OF material_group_tuple WITH UNIQUE KEY kostl matkl.
    DATA agent_for_material_group TYPE material_group_map.

    TYPES responsibilities TYPE SORTED TABLE OF zrwtha_resp_cwf_ecc_preq=>responsibility WITH UNIQUE KEY cost_center role responsible_agent
      WITH NON-UNIQUE SORTED KEY secondary COMPONENTS responsible_agent.
    DATA responsiblities TYPE responsibilities.
    TYPES: BEGIN OF user_cost_center_pair,
             user  TYPE sy-uname,
             kostl TYPE kostl,
           END OF user_cost_center_pair,
           user_cost_center_mapping TYPE SORTED TABLE OF user_cost_center_pair WITH UNIQUE KEY user.
    DATA cost_centers_of_users TYPE user_cost_center_mapping.
ENDCLASS.

CLASS fake_customer_wf_customizing IMPLEMENTATION.

  METHOD constructor.
    super->constructor(
      iv_customer_id = 'TEST'
      iv_cust_sys_id = 'TEST'
      iv_remote_sys  = 'TEST' ).
  ENDMETHOD.

  METHOD get_external_data.
    FIELD-SYMBOLS <responsibility> TYPE zrwtha_resp_cwf_ecc_preq=>responsibility.
    DATA: BEGIN OF kostlfromuser,
            BEGIN OF request,
              user LIKE sy-uname,
            END OF request,
            BEGIN OF response,
              kostl TYPE kostl,
            END OF response,
          END OF kostlfromuser.
    DATA: BEGIN OF freigfromkostlmatkl,
            BEGIN OF request,
              kostl TYPE kostl,
              matkl TYPE matkl,
            END OF request,
            BEGIN OF response,
              freig TYPE xubname,
            END OF response,
          END OF freigfromkostlmatkl.
    DATA: BEGIN OF usercostcenterrolemapping,
            BEGIN OF response,
              mapping TYPE user_costcenter_role_mapping,
            END OF response,
          END OF usercostcenterrolemapping.

    CASE iv_action.
      WHEN 'RolesFromUser'.
        cl_abap_unit_assert=>fail( msg = `Use CRUD call UserCostCenterRoleMapping instead of RolesFromUser` ).
      WHEN 'FreigFromKostlMatkl'.
        freigfromkostlmatkl-request = iv_data.
        freigfromkostlmatkl-response-freig = VALUE #( agent_for_material_group[
          kostl = freigfromkostlmatkl-request-kostl
          matkl = freigfromkostlmatkl-request-matkl ]-freig OPTIONAL ).
        ev_data = freigfromkostlmatkl-response.
      WHEN 'UsersFromRoles'.
        cl_abap_unit_assert=>fail( msg = `Use CRUD call UserCostCenterRoleMapping instead of UsersFromRoles` ).
      WHEN 'KostlFromUser'.
        kostlfromuser-request = iv_data.
        TRY.
            kostlfromuser-response-kostl = cost_centers_of_users[ user = kostlfromuser-request-user ]-kostl.
          CATCH cx_sy_itab_line_not_found INTO DATA(missing_cost_center_mapping).
            cl_abap_unit_assert=>fail( |User { kostlfromuser-request-user } has no cost center mapping| ).
        ENDTRY.
        ev_data = kostlfromuser-response.
      WHEN 'UserCostCenterRoleMapping'.
        usercostcenterrolemapping-response-mapping = CORRESPONDING #( responsiblities
          MAPPING benutzer = responsible_agent
                  kostenstelle = cost_center
                  rolle = role ).
        ev_data = usercostcenterrolemapping-response.
      WHEN OTHERS.
        cl_abap_unit_assert=>fail( |unexpected CRUD call { iv_action }| ).
    ENDCASE.
  ENDMETHOD.

ENDCLASS.



CLASS unit_tests DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.
  PUBLIC SECTION.
    TYPES unique_steps TYPE SORTED TABLE OF /benmsg/swf_bd_step WITH UNIQUE KEY step_idx_cfg.
    TYPES agents TYPE STANDARD TABLE OF swhactor-objid WITH EMPTY KEY.
    TYPES: BEGIN OF decision,
             external_id TYPE /benmsg/swf_bd_decision-external_id,
             agents      TYPE agents,
           END OF decision.
    TYPES decisions TYPE STANDARD TABLE OF decision WITH EMPTY KEY.
    TYPES: BEGIN OF workflow_step,
             responsibility TYPE /benmsg/swf_bd_step-responsibility,
             decisions      TYPE decisions,
           END OF workflow_step.
    TYPES workflow_shape TYPE STANDARD TABLE OF workflow_step WITH EMPTY KEY.
    TYPES step TYPE /benmsg/swf_bd_step.
    DATA fake_purchase_requisition TYPE REF TO fake_purchase_requisition.
    DATA all_steps TYPE unique_steps.
    DATA cut TYPE REF TO zrwtha_resp_cwf_ecc_preq.
    DATA fake_customer_wf_customizing TYPE REF TO fake_customer_wf_customizing.
    DATA is_valid TYPE abap_bool.
    DATA steps_expected_to_be_valid TYPE workflow_shape.
    CONSTANTS: BEGIN OF responsibilities,
                 all            TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_ALL',
                 tech           TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_PG_TECHNISCH',
                 kauf           TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_KAUFM',
                 material_group TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_WARENGRP',
                 sach           TYPE /benmsg/swf_bd_step-responsibility VALUE 'ZRWTHA_SACHLICH',
               END OF responsibilities.
    CONSTANTS: BEGIN OF value_range,
                 under_500          TYPE char10 VALUE '<500',
                 between_500_and_1k TYPE char10 VALUE '500-1k',
                 between_1k_and_10k TYPE char10 VALUE '1k-10k',
                 over_10k           TYPE char10 VALUE '>10k',
               END OF value_range.

  PRIVATE SECTION.
    METHODS:
      "! even when multiple items contain the same material group requiring approval,
      "! only one decision is created for each material group, each with only one agent
      groups_agents_by_decision FOR TESTING RAISING cx_static_check,
      wf1_1 FOR TESTING RAISING cx_static_check,
      wf0_1 FOR TESTING RAISING cx_static_check,
      wf0_2 FOR TESTING RAISING cx_static_check,
      wf0_3 FOR TESTING RAISING cx_static_check,
      wf0_4 FOR TESTING RAISING cx_static_check,
      wf1_2 FOR TESTING RAISING cx_static_check,
      wf1_3 FOR TESTING RAISING cx_static_check,
      wf1_4 FOR TESTING RAISING cx_static_check,
      wf2_1 FOR TESTING RAISING cx_static_check,
      wf2_2 FOR TESTING RAISING cx_static_check,
      wf2_3 FOR TESTING RAISING cx_static_check,
      wf2_4 FOR TESTING RAISING cx_static_check,
      wf3_1 FOR TESTING RAISING cx_static_check,
      wf3_2 FOR TESTING RAISING cx_static_check,
      wf3_3 FOR TESTING RAISING cx_static_check,
      wf3_4 FOR TESTING RAISING cx_static_check,
      wf4_1 FOR TESTING RAISING cx_static_check,
      wf4_2 FOR TESTING RAISING cx_static_check,
      wf4_3 FOR TESTING RAISING cx_static_check,
      wf4_4 FOR TESTING RAISING cx_static_check,
      wf5_1 FOR TESTING RAISING cx_static_check,
      wf5_2 FOR TESTING RAISING cx_static_check,
      wf5_3 FOR TESTING RAISING cx_static_check,
      wf5_4 FOR TESTING RAISING cx_static_check,
      wf6 FOR TESTING RAISING cx_static_check,
      wf7 FOR TESTING RAISING cx_static_check,
      error FOR TESTING RAISING cx_static_check,
      compacting_1 FOR TESTING RAISING cx_static_check,
      compacting_2 FOR TESTING RAISING cx_static_check,
      compacting_skipping_step FOR TESTING RAISING cx_static_check,
      item_requester_is_initial FOR TESTING RAISING cx_static_check,
      invalid_item_cost_center FOR TESTING RAISING cx_static_check,
      fallback_user FOR TESTING RAISING cx_static_check,
      material_grp_without_approver FOR TESTING RAISING cx_static_check,
      setup,
      teardown,
      assert
        IMPORTING
          valid_steps TYPE unit_tests=>workflow_shape,
      given_emergency_order_process,
      given_purch_req_items_with_val
        IMPORTING
          range LIKE value_range-under_500,
      given_requester
        IMPORTING
          requester TYPE xubname,
      given_customizing_of_responsib,
      given_customizing_of_mat_group,
      given_mat_group_to_be_approved.
ENDCLASS.


CLASS unit_tests IMPLEMENTATION.

  METHOD groups_agents_by_decision.
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:00_ANFORDERUNG' responsible_agent = 'AGENT1' )
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'AGENT1' ) ).
    fake_customer_wf_customizing->agent_for_material_group = VALUE #(
      ( kostl = '0000111111' matkl = 'GROUP1' freig = 'AGENT2' )
      ( kostl = '0000111111' matkl = 'GROUP2' freig = 'AGENT3' ) ).

    fake_purchase_requisition->items = VALUE #(
      ( preq_item = '00010' value_item = 1 preq_name = 'AGENT1' matl_group = 'GROUP1' )
      ( preq_item = '00020' value_item = 1 preq_name = 'AGENT1' matl_group = 'GROUP1' )
      ( preq_item = '00030' value_item = 1 preq_name = 'AGENT1' matl_group = 'GROUP2' ) ).
    fake_purchase_requisition->accounts = VALUE #(
      ( preq_item = '00010' wbs_element = '999991111119999' )
      ( preq_item = '00020' wbs_element = '999991111119999' )
      ( preq_item = '00030' wbs_element = '999991111119999' ) ).
    fake_purchase_requisition->current_step = 010.

    DATA(material_group_approval_step) = VALUE /benmsg/swf_rstep( step_idx_cfg = 300 responsibility = 'ZRWTHA_WARENGRP' ).
    cut = NEW zrwtha_resp_cwf_ecc_preq( fake_customer_wf_customizing ).
    cut->/benmsg/if_wf_bd_resp~get_responsible_agents(
      EXPORTING
        io_wf_obj   = fake_purchase_requisition
        is_decision = VALUE #( external_id = 'ZRWTHA_WARENGRP_AGENT2' responsibility = 'ZRWTHA_WARENGRP' )
        is_step     = material_group_approval_step
      IMPORTING
        et_agents   = DATA(agents)
    ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( agents ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'AGENT2' act = agents[ 1 ]-objid ).

    cut->/benmsg/if_wf_bd_resp~get_responsible_agents(
      EXPORTING
        io_wf_obj   = fake_purchase_requisition
        is_decision = VALUE #( external_id = 'ZRWTHA_WARENGRP_AGENT3' responsibility = 'ZRWTHA_WARENGRP' )
        is_step     = material_group_approval_step
      IMPORTING
        et_agents   = agents
    ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( agents ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'AGENT3' act = agents[ 1 ]-objid ).
  ENDMETHOD.


  METHOD wf0_1.
    "<500 no-role NOT !MATGRP
    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-under_500 ).
    fake_purchase_requisition->current_step = 010.

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf0_2.
    "<500  00-role NOT !MATGRP
    given_customizing_of_responsib( ).

    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-under_500 ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf0_3.
    "<500 03-05-role  NOT !MATGRP
    given_customizing_of_responsib( ).

    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-under_500 ).
    given_requester( 'KAUFM-AGENT' ).

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf0_4.
    "<500  03-05-role  !NOT  !MATGRP
    given_customizing_of_responsib( ).

    given_purch_req_items_with_val( value_range-under_500 ).
    given_requester( 'KAUFM-AGENT' ).

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).

    steps_expected_to_be_valid = VALUE #( ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf1_1.
    "<500  no-role NOT MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-under_500 ).
    given_mat_group_to_be_approved( ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = 'ZRWTHA_WARENGRP' decisions = VALUE #(
        ( external_id = 'ZRWTHA_WARENGRP_APPROVER' agents = VALUE #( ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf1_2.
    "<500  00-role NOT MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-under_500 ).
    given_mat_group_to_be_approved( ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = 'ZRWTHA_WARENGRP' decisions = VALUE #(
        ( external_id = 'ZRWTHA_WARENGRP_APPROVER' agents = VALUE #( ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf1_3.
    "<500 03-05-role  NOT MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-under_500 ).
    given_mat_group_to_be_approved( ).
    given_requester( 'KAUFM-AGENT' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = 'ZRWTHA_WARENGRP' decisions = VALUE #(
        ( external_id = 'ZRWTHA_WARENGRP_APPROVER' agents = VALUE #( ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf1_4.
    "<500  03-05-role  !NOT  MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_purch_req_items_with_val( value_range-under_500 ).
    given_mat_group_to_be_approved( ).
    given_requester( 'KAUFM-AGENT' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = 'ZRWTHA_WARENGRP' decisions = VALUE #(
        ( external_id = 'ZRWTHA_WARENGRP_APPROVER' agents = VALUE #( ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf2_1.
    "<500 00-role !NOT  !MATGRP
    given_customizing_of_responsib( ).
    given_purch_req_items_with_val( value_range-under_500 ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf2_2.
    "500-1k no-role NOT !MATGRP
    given_customizing_of_responsib( ).
    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf2_3.
    "500-1k 00-role NOT !MATGRP
    given_customizing_of_responsib( ).
    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf2_4.
    "500-1k 03-05-role  NOT !MATGRP
    given_customizing_of_responsib( ).
    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_requester( 'FACHL-AGENT' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf3_1.
    "<500  00-role !NOT  MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_purch_req_items_with_val( value_range-under_500 ).
    given_mat_group_to_be_approved( ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf3_2.
    "500-1k no-role NOT MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).
    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_mat_group_to_be_approved( ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf3_3.
    "500-1k 00-role NOT MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).
    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_mat_group_to_be_approved( ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf3_4.
    "500-1k 03-05-role  NOT MATGRP
    given_customizing_of_responsib( ).
    given_emergency_order_process( ).
    given_customizing_of_mat_group( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_mat_group_to_be_approved( ).
    given_requester( 'FACHL-AGENT' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-all decisions = VALUE #(
        ( external_id = |{ responsibilities-all }_111111| agents = VALUE #(
          ( 'ANFOR-AGENT1' ) ( 'FACHL-AGENT' ) ( 'KAUFM-AGENT' ) ( 'ZEICH-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf4_1.
    "<500 no-role !NOT  !MATGRP
    given_customizing_of_responsib( ).
    given_purch_req_items_with_val( value_range-under_500 ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf4_2.
    "500-1k no-role !NOT  !MATGRP
    given_customizing_of_responsib( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf4_3.
    "500-1k 00-role !NOT  !MATGRP
    given_customizing_of_responsib( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf4_4.
    "500-1k 03-05-role  !NOT  !MATGRP
    given_customizing_of_responsib( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_requester( 'FACHL-AGENT' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf5_1.
    "<500 no-role !NOT  MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_purch_req_items_with_val( value_range-under_500 ).
    given_mat_group_to_be_approved( ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf5_2.
    "500-1k no-role !NOT  MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_mat_group_to_be_approved( ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf5_3.
    "500-1k  00-role !NOT  MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_mat_group_to_be_approved( ).
    given_requester( 'ANFOR-AGENT1' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf5_4.
    "500-1k 03-05-role  !NOT  MATGRP
    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).

    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_mat_group_to_be_approved( ).
    given_requester( 'FACHL-AGENT' ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD wf6.
    ">1k-10k  no-roles    !NOT  !MATGRP
    ">1k-10k  00-role     !NOT  !MATGRP
    ">1k-10k  03-05-role  !NOT  !MATGRP
    ">10k     no-role     !NOT  !MATGRP
    ">10k     00-role     !NOT  !MATGRP
    ">10k     03-05-role  !NOT  !MATGRP

    given_customizing_of_responsib( ).
    given_purch_req_items_with_val( value_range-between_1k_and_10k ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-tech decisions = VALUE #(
        ( external_id = |{ responsibilities-tech }_111111| agents = VALUE #(
          ( 'FACHL-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ANFOR-AGENT1' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_purch_req_items_with_val( value_range-over_10k ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ANFOR-AGENT1' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).

  ENDMETHOD.


  METHOD wf7.
    ">1k-10k  no-role     !NOT  MATGRP
    ">1k-10k  00-role     !NOT  MATGRP
    ">1k-10k  03-05-role  !NOT  MATGRP
    ">10k     no-role     !NOT  MATGRP
    ">10k     00-role     !NOT  MATGRP
    ">10k     03-05-role  !NOT  MATGRP

    given_customizing_of_responsib( ).
    given_customizing_of_mat_group( ).
    given_purch_req_items_with_val( value_range-between_1k_and_10k ).
    given_mat_group_to_be_approved( ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-tech decisions = VALUE #(
        ( external_id = |{ responsibilities-tech }_111111| agents = VALUE #(
          ( 'FACHL-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-material_group decisions = VALUE #(
        ( external_id = |{ responsibilities-material_group }_APPROVER| agents = VALUE #(
          ( 'APPROVER' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ANFOR-AGENT1' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_purch_req_items_with_val( value_range-over_10k ).
    given_mat_group_to_be_approved( ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ANFOR-AGENT1' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'FACHL-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'KAUFM-AGENT' ).
    assert( steps_expected_to_be_valid ).

    given_requester( 'ZEICH-AGENT' ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD error.
    ">1k-10k  no-role     NOT MATGRP
    ">1k-10k  no-role     NOT !MATGRP
    ">1k-10k  00-role     NOT MATGRP
    ">1k-10k  00-role     NOT !MATGRP
    ">1k-10k  03-05-role  NOT MATGRP
    ">1k-10k  03-05-role  NOT !MATGRP
    ">10k     no-role     NOT MATGRP
    ">10k     no-role     NOT !MATGRP
    ">10k     00-role     NOT MATGRP
    ">10k     00-role     NOT !MATGRP
    ">10k     03-05-role  NOT MATGRP
    ">10k     03-05-role  NOT !MATGRP
    given_emergency_order_process( ).
    given_purch_req_items_with_val( value_range-between_1k_and_10k ).
    steps_expected_to_be_valid = VALUE #( ).
    TRY.
        assert( steps_expected_to_be_valid ).
        cl_abap_unit_assert=>fail( ).
      CATCH cx_no_check.
    ENDTRY.

    given_purch_req_items_with_val( value_range-over_10k ).
    TRY.
        assert( steps_expected_to_be_valid ).
        cl_abap_unit_assert=>fail( ).
      CATCH cx_no_check.
    ENDTRY.

    given_mat_group_to_be_approved( ).
    TRY.
        assert( steps_expected_to_be_valid ).
        cl_abap_unit_assert=>fail( ).
      CATCH cx_no_check.
    ENDTRY.
  ENDMETHOD.


  METHOD compacting_1.
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'A' )
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'B' )
      ( cost_center = '0000111111' role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' responsible_agent = 'A' )
      ( cost_center = '0000111111' role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' responsible_agent = 'C' ) ).
    given_purch_req_items_with_val( value_range-under_500 ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'B' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'A' ) ( 'C' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD compacting_2.
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'A' )
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'B' )
      ( cost_center = '0000111111' role = 'Z_GHBS:04_GENEHMIGUNG-FACHL' responsible_agent = 'A' )
      ( cost_center = '0000111111' role = 'Z_GHBS:04_GENEHMIGUNG-FACHL' responsible_agent = 'C' )
      ( cost_center = '0000111111' role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' responsible_agent = 'A' )
      ( cost_center = '0000111111' role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' responsible_agent = 'D' ) ).
    given_purch_req_items_with_val( value_range-between_1k_and_10k ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-tech decisions = VALUE #(
        ( external_id = |{ responsibilities-tech }_111111| agents = VALUE #(
          ( 'C' ) ) ) ) )
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'B' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'A' ) ( 'D' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD compacting_skipping_step.
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'A' )
      ( cost_center = '0000111111' role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' responsible_agent = 'A' )
      ( cost_center = '0000111111' role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' responsible_agent = 'C' ) ).
    given_purch_req_items_with_val( value_range-under_500 ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'A' ) ( 'C' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD item_requester_is_initial.
    given_customizing_of_responsib( ).

    "items under 500€ without requester
    fake_purchase_requisition->items = VALUE #(
      ( preq_item = '00010' value_item = 1 )
      ( preq_item = '00020' value_item = 1 )
      ( preq_item = '00030' value_item = 1 ) ).
    fake_purchase_requisition->accounts = VALUE #(
      ( preq_item = '00010' wbs_element = '999991111119999' )
      ( preq_item = '00020' wbs_element = '999991111119999' )
      ( preq_item = '00030' wbs_element = '999991111119999' ) ).

    TRY.
        assert( steps_expected_to_be_valid ).
        cl_abap_unit_assert=>fail( msg = `Should raise exception, because requester is not supplied` ).
      CATCH cx_no_check.
    ENDTRY.
  ENDMETHOD.


  METHOD invalid_item_cost_center.
    given_customizing_of_responsib( ).
    fake_customer_wf_customizing->cost_centers_of_users = VALUE #( ( user = 'AGENT' kostl = '0000111111' ) ).

    "items under 500€ without WBS elements from which cost centers could be derived (Requester has no roles)
    fake_purchase_requisition->items = VALUE #(
      ( preq_item = '00010' value_item = 1 preq_name = 'AGENT' )
      ( preq_item = '00020' value_item = 1 preq_name = 'AGENT' )
      ( preq_item = '00030' value_item = 1 preq_name = 'AGENT' ) ).
    fake_purchase_requisition->accounts = VALUE #(
      ( preq_item = '00010' )
      ( preq_item = '00020' )
      ( preq_item = '00030' ) ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD fallback_user.
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'FS454989' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD material_grp_without_approver.
    given_customizing_of_responsib( ).
    given_purch_req_items_with_val( value_range-between_500_and_1k ).
    given_mat_group_to_be_approved( ).

    steps_expected_to_be_valid = VALUE #(
      ( responsibility = responsibilities-kauf decisions = VALUE #(
        ( external_id = |{ responsibilities-kauf }_111111| agents = VALUE #(
          ( 'KAUFM-AGENT' ) ) ) ) )
      ( responsibility = responsibilities-sach decisions = VALUE #(
        ( external_id = |{ responsibilities-sach }_111111| agents = VALUE #(
          ( 'ZEICH-AGENT' ) ) ) ) ) ).
    assert( steps_expected_to_be_valid ).
  ENDMETHOD.


  METHOD assert.
    DATA item_map TYPE /benmsg/twf_bd_dec_itmmap.
    LOOP AT all_steps ASSIGNING FIELD-SYMBOL(<step>).
      cut = NEW zrwtha_resp_cwf_ecc_preq( fake_customer_wf_customizing ).
      cut->/benmsg/if_wf_bd_resp~is_step_valid(
        EXPORTING
          io_wf_obj = fake_purchase_requisition
          is_step   = <step>
        CHANGING
          cv_valid  = is_valid ).
      IF line_exists( valid_steps[ responsibility = <step>-responsibility ] ).
        cl_abap_unit_assert=>assert_true( act = is_valid msg = |Step { <step>-responsibility } should be valid| ).
        cut->/benmsg/if_wf_bd_resp~map_items_to_decisions(
          EXPORTING
            io_wf_obj   = fake_purchase_requisition
            is_step     = <step>
          CHANGING
            ct_item_map = item_map ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( lines( item_map ) >= 1 )
          msg = |Step { <step>-responsibility } should at least have one decision| ).
        DATA decision TYPE /benmsg/swf_bd_decision.
        LOOP AT item_map ASSIGNING FIELD-SYMBOL(<decision>).
          cut->/benmsg/if_wf_bd_resp~get_responsible_agents(
            EXPORTING
              io_wf_obj   = fake_purchase_requisition
              is_decision = VALUE #( external_id = <decision>-external_id responsibility = <step>-responsibility )
              is_step     = CORRESPONDING #( <step> )
            IMPORTING
              et_agents   = DATA(agents)
              et_profiles = DATA(profiles) ).
          cl_abap_unit_assert=>assert_equals(
            exp = valid_steps[ responsibility = <step>-responsibility ]-decisions[
              external_id = <decision>-external_id ]-agents
            act = VALUE agents( FOR i IN agents ( i-objid ) )
            msg = |Agents of step { <step>-responsibility } are not as expected| ).
          cl_abap_unit_assert=>assert_equals(
            exp = lines( agents )
            act = lines( profiles )
            msg = `Should have same number of Profiles as Agents` ).
          LOOP AT agents ASSIGNING FIELD-SYMBOL(<actual_agent>).
            cl_abap_unit_assert=>assert_true(
              act = xsdbool( line_exists( profiles[ profile = <actual_agent>-objid ] ) )
              msg = |Agent { <actual_agent>-objid } should be in Profiles| ).
          ENDLOOP.
        ENDLOOP.
      ELSE.
        cl_abap_unit_assert=>assert_false( act = is_valid msg = |Step { <step>-responsibility } should be invalid| ).
      ENDIF.
      CLEAR is_valid.
    ENDLOOP.
  ENDMETHOD.


  METHOD setup.
    fake_purchase_requisition = NEW fake_purchase_requisition( ).
    fake_customer_wf_customizing = NEW fake_customer_wf_customizing( ).
    all_steps = VALUE #(
      ( step_idx_cfg = '010' responsibility = 'ZRWTHA_ALL' )
      ( step_idx_cfg = '100' responsibility = 'ZRWTHA_PG_TECHNISCH' )
      ( step_idx_cfg = '200' responsibility = 'ZRWTHA_KAUFM' )
      ( step_idx_cfg = '300' responsibility = 'ZRWTHA_WARENGRP' )
      ( step_idx_cfg = '400' responsibility = 'ZRWTHA_SACHLICH' ) ).
  ENDMETHOD.

  METHOD teardown.
    CLEAR is_valid.
    CLEAR cut->cached_responsibilities.
  ENDMETHOD.

  METHOD given_emergency_order_process.
    fake_purchase_requisition->beneering_extensions = VALUE #(
          extensionout = VALUE #(
            ( structure = 'BAPI_TE_MEREQITEM' cust_fields = VALUE #(
              ( component_name = 'ZZ_BENGRP' component_value = 'NOT' ) ) ) ) ).
  ENDMETHOD.


  METHOD given_purch_req_items_with_val.
    CASE range.
      WHEN value_range-under_500.
        fake_purchase_requisition->items = VALUE #(
          ( preq_item = '00010' value_item = 1 preq_name = 'AGENT' )
          ( preq_item = '00020' value_item = 1 preq_name = 'AGENT' )
          ( preq_item = '00030' value_item = 1 preq_name = 'AGENT' ) ).
        fake_purchase_requisition->accounts = VALUE #(
          ( preq_item = '00010' wbs_element = '999991111119999' )
          ( preq_item = '00020' wbs_element = '999991111119999' )
          ( preq_item = '00030' wbs_element = '999991111119999' ) ).
      WHEN value_range-between_500_and_1k.
        fake_purchase_requisition->items = VALUE #(
          ( preq_item = '00010' value_item = 500 preq_name = 'AGENT' )
          ( preq_item = '00020' value_item = 1 preq_name = 'AGENT' )
          ( preq_item = '00030' value_item = 1 preq_name = 'AGENT' ) ).
        fake_purchase_requisition->accounts = VALUE #(
          ( preq_item = '00010' wbs_element = '999991111119999' )
          ( preq_item = '00020' wbs_element = '999991111119999' )
          ( preq_item = '00030' wbs_element = '999991111119999' ) ).
      WHEN value_range-between_1k_and_10k.
        fake_purchase_requisition->items = VALUE #(
          ( preq_item = '00010' value_item = 1000 preq_name = 'AGENT' )
          ( preq_item = '00020' value_item = 1 preq_name = 'AGENT' )
          ( preq_item = '00030' value_item = 1 preq_name = 'AGENT' ) ).
        fake_purchase_requisition->accounts = VALUE #(
          ( preq_item = '00010' wbs_element = '999991111119999' )
          ( preq_item = '00020' wbs_element = '999991111119999' )
          ( preq_item = '00030' wbs_element = '999991111119999' ) ).
      WHEN value_range-over_10k.
        fake_purchase_requisition->items = VALUE #(
          ( preq_item = '00010' value_item = 10000 preq_name = 'AGENT' )
          ( preq_item = '00020' value_item = 1 preq_name = 'AGENT' )
          ( preq_item = '00030' value_item = 1 preq_name = 'AGENT' ) ).
        fake_purchase_requisition->accounts = VALUE #(
          ( preq_item = '00010' wbs_element = '999991111119999' )
          ( preq_item = '00020' wbs_element = '999991111119999' )
          ( preq_item = '00030' wbs_element = '999991111119999' ) ).
      WHEN OTHERS.
        cl_abap_unit_assert=>abort( msg = `incorrect value range` ).
    ENDCASE.
  ENDMETHOD.


  METHOD given_requester.
    LOOP AT fake_purchase_requisition->items ASSIGNING FIELD-SYMBOL(<item>).
      <item>-preq_name = requester.
    ENDLOOP.
  ENDMETHOD.


  METHOD given_customizing_of_responsib.
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:00_ANFORDERUNG' responsible_agent = 'ANFOR-AGENT1' )
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'KAUFM-AGENT' )
      ( cost_center = '0000111111' role = 'Z_GHBS:04_GENEHMIGUNG-FACHL' responsible_agent = 'FACHL-AGENT' )
      ( cost_center = '0000111111' role = 'Z_GHBS:05_ZEICHNUNGSBEFUGTER' responsible_agent = 'ZEICH-AGENT' ) ).
  ENDMETHOD.


  METHOD given_customizing_of_mat_group.
    fake_customer_wf_customizing->agent_for_material_group = VALUE #(
      ( kostl = '0000111111' matkl = 'APPROVEME' freig = 'APPROVER' ) ).
  ENDMETHOD.


  METHOD given_mat_group_to_be_approved.
    fake_purchase_requisition->items[ 2 ]-matl_group = 'APPROVEME'.
  ENDMETHOD.

ENDCLASS.


CLASS test_mapping_items_2_decisions DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS
  INHERITING FROM unit_tests.

  PRIVATE SECTION.
    METHODS:
      should_map_decision_mult_matgr FOR TESTING RAISING cx_static_check,
      should_map_decision_w_1_matgr FOR TESTING RAISING cx_static_check,
      groups_decision_by_cost_center FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS test_mapping_items_2_decisions IMPLEMENTATION.

  METHOD groups_decision_by_cost_center.
    "ohne Warengruppenpositionen
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:00_ANFORDERUNG' responsible_agent = 'AGENT1' )
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'AGENT1' ) ).

    fake_purchase_requisition->items = VALUE #(
      ( preq_item = '00010' value_item = 1 preq_name = 'AGENT1'  )
      ( preq_item = '00020' value_item = 1 preq_name = 'AGENT1'  )
      ( preq_item = '00030' value_item = 1 preq_name = 'AGENT1'  ) ).
    fake_purchase_requisition->accounts = VALUE #(
      ( preq_item = '00010' wbs_element = '999991111119999' )
      ( preq_item = '00020' wbs_element = '999991111119999' )
      ( preq_item = '00030' wbs_element = '999991111119999' ) ).
    fake_purchase_requisition->current_step = 010.

    cut = NEW zrwtha_resp_cwf_ecc_preq( fake_customer_wf_customizing ).
    DATA decision_item_map TYPE /benmsg/twf_bd_dec_itmmap.
    cut->/benmsg/if_wf_bd_resp~map_items_to_decisions(
      EXPORTING
        io_wf_obj   = fake_purchase_requisition    " DC4 Workflow Object
        is_step     = VALUE #( responsibility = 'ZRWTHA_ALL' )    " Step detail (BADI)
      CHANGING
        ct_item_map = decision_item_map    " Decision item map (BADI)
    ).
    cl_abap_unit_assert=>assert_equals( exp = 'ZRWTHA_ALL_111111' act = decision_item_map[ 1 ]-external_id ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00010' )
                                        act = decision_item_map[ 1 ]-item_map[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00020' )
                                        act = decision_item_map[ 1 ]-item_map[ 2 ] ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00030' )
                                        act = decision_item_map[ 1 ]-item_map[ 3 ] ).
  ENDMETHOD.

  METHOD should_map_decision_mult_matgr.
    "mehrere Warengruppenpositionen
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:00_ANFORDERUNG' responsible_agent = 'AGENT1' )
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'AGENT1' ) ).
    fake_customer_wf_customizing->agent_for_material_group = VALUE #(
      ( kostl = '0000111111' matkl = 'GROUP1' freig = 'AGENT2' )
      ( kostl = '0000111111' matkl = 'GROUP2' freig = 'AGENT3' ) ).

    fake_purchase_requisition->items = VALUE #(
      ( preq_item = '00010' value_item = 1 preq_name = 'AGENT1'  )
      ( preq_item = '00020' value_item = 1 preq_name = 'AGENT1' matl_group = 'GROUP1' )
      ( preq_item = '00030' value_item = 1 preq_name = 'AGENT1' matl_group = 'GROUP2' ) ).
    fake_purchase_requisition->accounts = VALUE #(
      ( preq_item = '00010' wbs_element = '999991111119999' )
      ( preq_item = '00020' wbs_element = '999991111119999' )
      ( preq_item = '00030' wbs_element = '999991111119999' ) ).
    fake_purchase_requisition->current_step = 010.

    cut = NEW zrwtha_resp_cwf_ecc_preq( fake_customer_wf_customizing ).
    DATA decision_item_map TYPE /benmsg/twf_bd_dec_itmmap.
    cut->/benmsg/if_wf_bd_resp~map_items_to_decisions(
      EXPORTING
        io_wf_obj   = fake_purchase_requisition    " DC4 Workflow Object
        is_step     = VALUE #( responsibility = 'ZRWTHA_WARENGRP' )    " Step detail (BADI)
      CHANGING
        ct_item_map = decision_item_map    " Decision item map (BADI)
    ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( decision_item_map ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'ZRWTHA_WARENGRP_AGENT2' act = decision_item_map[ 1 ]-external_id ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00020' )
                                        act = decision_item_map[ 1 ]-item_map[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = 'ZRWTHA_WARENGRP_AGENT3' act = decision_item_map[ 2 ]-external_id ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00030' )
                                        act = decision_item_map[ 2 ]-item_map[ 1 ] ).
  ENDMETHOD.


  METHOD should_map_decision_w_1_matgr.
    "eine Warengruppenposition
    fake_customer_wf_customizing->responsiblities = VALUE #(
      ( cost_center = '0000111111' role = 'Z_GHBS:00_ANFORDERUNG' responsible_agent = 'AGENT1' )
      ( cost_center = '0000111111' role = 'Z_GHBS:03_GENEHMIGUNG-KAUFM' responsible_agent = 'AGENT1' ) ).
    fake_customer_wf_customizing->agent_for_material_group = VALUE #( (
          kostl = '0000111111' matkl = 'GROUP1' freig = 'AGENT2' ) ).

    fake_purchase_requisition->items = VALUE #(
      ( preq_item = '00010' value_item = 1 preq_name = 'AGENT1'  )
      ( preq_item = '00020' value_item = 1 preq_name = 'AGENT1' matl_group = 'GROUP1' )
      ( preq_item = '00030' value_item = 1 preq_name = 'AGENT1'  ) ).
    fake_purchase_requisition->accounts = VALUE #(
      ( preq_item = '00010' wbs_element = '999991111119999' )
      ( preq_item = '00020' wbs_element = '999991111119999' )
      ( preq_item = '00030' wbs_element = '999991111119999' ) ).
    fake_purchase_requisition->current_step = 010.

    cut = NEW zrwtha_resp_cwf_ecc_preq( fake_customer_wf_customizing ).
    DATA decision_item_map TYPE /benmsg/twf_bd_dec_itmmap.
    cut->/benmsg/if_wf_bd_resp~map_items_to_decisions(
      EXPORTING
        io_wf_obj   = fake_purchase_requisition    " DC4 Workflow Object
        is_step     = VALUE #( responsibility = 'ZRWTHA_ALL' )    " Step detail (BADI)
      CHANGING
        ct_item_map = decision_item_map    " Decision item map (BADI)
    ).
    cl_abap_unit_assert=>assert_equals( exp = 'ZRWTHA_ALL_111111' act = decision_item_map[ 1 ]-external_id ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00010' )
                                        act = decision_item_map[ 1 ]-item_map[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00020' )
                                        act = decision_item_map[ 1 ]-item_map[ 2 ] ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00030' )
                                        act = decision_item_map[ 1 ]-item_map[ 3 ] ).
    cut->/benmsg/if_wf_bd_resp~map_items_to_decisions(
      EXPORTING
        io_wf_obj   = fake_purchase_requisition    " DC4 Workflow Object
        is_step     = VALUE #( responsibility = 'ZRWTHA_WARENGRP' )    " Step detail (BADI)
      CHANGING
        ct_item_map = decision_item_map    " Decision item map (BADI)
    ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( decision_item_map ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'ZRWTHA_WARENGRP_AGENT2' act = decision_item_map[ 1 ]-external_id ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE /benmsg/swf_bd_item_ref( otype = 'BUS2009' objid = '00020' )
                                        act = decision_item_map[ 1 ]-item_map[ 1 ] ).
  ENDMETHOD.

ENDCLASS.



*CLASS new_remote_interface DEFINITION FINAL FOR TESTING
*  DURATION SHORT
*  RISK LEVEL HARMLESS.
*
*  PRIVATE SECTION.
*    METHODS:
*      first_test FOR TESTING RAISING cx_static_check.
*ENDCLASS.
*
*
*CLASS new_remote_interface IMPLEMENTATION.
*
*  METHOD first_test.
*    "TODO: remove this code
*    DATA dummy_request TYPE c LENGTH 1.
*    DATA: BEGIN OF response,
*            mapping TYPE user_costcenter_role_mapping,
*          END OF response.
*    NEW /benmsg/cl_wsi_obj_cust_data(
*        iv_customer_id = '1000004036'
*        iv_cust_sys_id = 'DE1CLNT120'
*        iv_remote_sys  = 'DE1CLNT120' )->get_external_data(
*      EXPORTING
*        iv_object   = 'BEN_DATA'
*        iv_action   = 'UserCostCenterRoleMapping'
*        iv_data     = dummy_request
*      IMPORTING
*        ev_data     = response ).
*    cl_abap_unit_assert=>assert_equals( exp = 34 act = lines( response-mapping ) ).
*  ENDMETHOD.
*
*ENDCLASS.
