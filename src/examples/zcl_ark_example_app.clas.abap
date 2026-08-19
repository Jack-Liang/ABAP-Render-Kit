CLASS zcl_ark_example_app DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS run RAISING zcx_ark_exception .
    CLASS-METHODS main RAISING zcx_ark_exception .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_ark_example_app IMPLEMENTATION.

  METHOD main.
    run( ).
  ENDMETHOD.

  METHOD run.
    DATA(lo_gui) = zcl_ark_gui=>create( ).

    IF lo_gui IS INITIAL.
      zcx_ark_exception=>raise( 'Failed to create ARK GUI' ).
    ENDIF.

    DATA(lo_hello_page) = NEW zcl_ark_example_hello_page( ).
    lo_gui->set_page( lo_hello_page ).
  ENDMETHOD.

ENDCLASS.
