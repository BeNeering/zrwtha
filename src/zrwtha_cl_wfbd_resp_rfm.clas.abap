class ZRWTHA_CL_WFBD_RESP_RFM definition
  public
  final
  create public .

public section.

  interfaces /BENMSG/IF_WF_BD_RESP .
  interfaces IF_BADI_INTERFACE .
protected section.
private section.
ENDCLASS.



CLASS ZRWTHA_CL_WFBD_RESP_RFM IMPLEMENTATION.


  method /BENMSG/IF_WF_BD_RESP~GET_RESPONSIBLE_AGENTS.
  endmethod.


  method /BENMSG/IF_WF_BD_RESP~IS_REAPPROVAL_REQUIRED.
  endmethod.


  method /BENMSG/IF_WF_BD_RESP~IS_STEP_VALID.
  endmethod.


  method /BENMSG/IF_WF_BD_RESP~MAP_ITEMS_TO_DECISIONS.
  endmethod.
ENDCLASS.
