CLASS ltcl_texts DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS all_keys_have_text FOR TESTING.
ENDCLASS.

CLASS ltcl_texts IMPLEMENTATION.

  METHOD all_keys_have_text.
    " 语言表完整性：每个 c_key 都必须有非空文本（新增键漏配即红）
    DATA ls_keys LIKE zcl_ark_texts=>c_key.
    ls_keys = zcl_ark_texts=>c_key.

    DATA(lo_struc) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( ls_keys ) ).
    LOOP AT lo_struc->get_components( ) INTO DATA(ls_comp).
      ASSIGN COMPONENT ls_comp-name OF STRUCTURE ls_keys TO FIELD-SYMBOL(<lv_key>).
      DATA(lv_text) = zcl_ark_texts=>text( <lv_key> ).
      cl_abap_unit_assert=>assert_not_initial(
        act  = lv_text
        msg  = |missing text for key { ls_comp-name } (language { sy-langu })| ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
