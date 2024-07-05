CLASS unit_test DEFINITION DEFERRED.
CLASS zrwtha_cl_wsi_obj_shlp_lfa DEFINITION LOCAL FRIENDS unit_test.

TYPES: BEGIN OF field_order_map,
         order_number TYPE shlpselpos,
         fieldname    TYPE shlpfield,
       END OF field_order_map.
TYPES sorted_field_order_mapping TYPE SORTED TABLE OF field_order_map WITH UNIQUE KEY order_number.
