CLASS zcx_ark_exception DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_t100_message .
    CLASS-METHODS raise
      IMPORTING !iv_text TYPE clike
      RAISING zcx_ark_exception .
    METHODS constructor
      IMPORTING !textid LIKE if_t100_message=>t100key OPTIONAL
                !previous LIKE previous OPTIONAL
                !iv_text TYPE string OPTIONAL .
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.

CLASS zcx_ark_exception IMPLEMENTATION.
  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    mv_text = iv_text.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
  METHOD raise.
    DATA lx_error TYPE REF TO zcx_ark_exception.
    CREATE OBJECT lx_error EXPORTING iv_text = iv_text.
    RAISE EXCEPTION lx_error.
  ENDMETHOD.
ENDCLASS.
