CLASS zcl_ark_html_parts DEFINITION PUBLIC FINAL CREATE PUBLIC .
  PUBLIC SECTION.
    METHODS add_part IMPORTING !iv_collection TYPE string !ii_part TYPE REF TO zif_ark_html
                     RAISING zcx_ark_exception .
    METHODS get_parts IMPORTING !iv_collection TYPE string
                      RETURNING VALUE(rt_parts) TYPE zif_ark_html=>ty_table_of .
    METHODS clear .
  PROTECTED SECTION.
  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_named_collection, name TYPE string, parts TYPE zif_ark_html=>ty_table_of,
      END OF ty_named_collection .
    DATA mt_collections TYPE STANDARD TABLE OF ty_named_collection WITH KEY name .
ENDCLASS.

CLASS zcl_ark_html_parts IMPLEMENTATION.
  METHOD add_part.
    FIELD-SYMBOLS <ls_collection> LIKE LINE OF mt_collections.
    READ TABLE mt_collections ASSIGNING <ls_collection> WITH KEY name = iv_collection.
    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO mt_collections ASSIGNING <ls_collection>.
      <ls_collection>-name = iv_collection.
    ENDIF.
    APPEND ii_part TO <ls_collection>-parts.
  ENDMETHOD.
  METHOD clear.
    CLEAR mt_collections.
  ENDMETHOD.
  METHOD get_parts.
    FIELD-SYMBOLS <ls_collection> LIKE LINE OF mt_collections.
    READ TABLE mt_collections ASSIGNING <ls_collection> WITH KEY name = iv_collection.
    IF sy-subrc = 0.
      rt_parts = <ls_collection>-parts.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
