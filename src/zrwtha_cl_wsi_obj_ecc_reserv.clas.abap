CLASS zrwtha_cl_wsi_obj_ecc_reserv DEFINITION
  PUBLIC
  INHERITING FROM /benmsg/cl_wsi_obj_ecc_res
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS map_mycart_item_to_res REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zrwtha_cl_wsi_obj_ecc_reserv IMPLEMENTATION.

  METHOD map_mycart_item_to_res.
    super->map_mycart_item_to_res(
      EXPORTING
        is_my_cart     = is_my_cart
        is_product     = is_product
        iv_remote_user = iv_remote_user
      IMPORTING
        es_bapi_hdr    = es_bapi_hdr
        es_bapi_itm    = es_bapi_itm ).
    es_bapi_itm-unload_pt = is_product-res_item-unload_point.
  ENDMETHOD.

ENDCLASS.
