CLASS zcl_team2_auxiliary_nro DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS c_object TYPE cl_numberrange_objects=>nr_attributes-object VALUE 'ZTEAM2_SO'.
    METHODS create_number_range
      IMPORTING
        io_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS draw_number
      IMPORTING
        io_out TYPE REF TO if_oo_adt_classrun_out.
    METHODS reset_number_range
      IMPORTING
        io_out TYPE REF TO if_oo_adt_classrun_out.
ENDCLASS.
CLASS zcl_team2_auxiliary_nro IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
*   draw_number( out ).
*    reset_number_range( out ).
    create_number_range( out ).

  ENDMETHOD.
  METHOD create_number_range.

    TRY.
        cl_numberrange_intervals=>create(
          EXPORTING
            object = c_object
            interval = VALUE #(
              (
                nrrangenr  = '01'
                fromnumber = '0000000001'
                tonumber   = '9999999999'
                nrlevel    = '0000000000'
                externind  = space
                procind    = 'I'
              )
            )
          IMPORTING
            error     = DATA(lv_error)
            error_inf = DATA(ls_error)
            error_iv  = DATA(lt_error_iv)
            warning   = DATA(lv_warning)
        ).

      CATCH cx_root INTO DATA(lo_error).
        io_out->write(
          lo_error->get_text( )
        ).

        RETURN.

    ENDTRY.

    io_out->write( lv_error ).
    io_out->write( ls_error ).
    io_out->write( lt_error_iv ).
    io_out->write( lv_warning ).
  ENDMETHOD.

  METHOD draw_number.
    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr = '01'
            object      = c_object
          IMPORTING
            number      = DATA(lv_number)
            returncode  = DATA(lv_rcode)
        ).

      CATCH cx_root INTO DATA(lo_error).

        io_out->write(
          lo_error->get_text( )
        ).
        RETURN.
    ENDTRY.
    io_out->write( lv_number ).
    io_out->write( lv_rcode ).

  ENDMETHOD.

  METHOD reset_number_range.

    " Delete the existing number range interval.
    TRY.
        cl_numberrange_intervals=>delete(
          EXPORTING
            object   = c_object
            interval = VALUE #(
              (
                nrrangenr  = '01'
                fromnumber = '0000000001'
                tonumber   = '9999999999'
                procind    = 'D'
              )
            )
          IMPORTING
            error     = DATA(lv_delete_error)
            error_inf = DATA(ls_delete_error)
            error_iv  = DATA(lt_delete_error_iv)
            warning   = DATA(lv_delete_warning)
        ).

        IF lv_delete_error IS NOT INITIAL.
          io_out->write( 'Delete interval failed.' ).
          io_out->write( ls_delete_error ).
          io_out->write( lt_delete_error_iv ).
          RETURN.
        ENDIF.

        " Recreate the interval starting at number 1.
        cl_numberrange_intervals=>create(
          EXPORTING
            object   = c_object
            interval = VALUE #(
              (
                nrrangenr  = '01'
                fromnumber = '0000000001'
                tonumber   = '9999999999'
                nrlevel    = '0000000000'
                externind  = space
                procind    = 'I'
              )
            )
          IMPORTING
            error     = DATA(lv_create_error)
            error_inf = DATA(ls_create_error)
            error_iv  = DATA(lt_create_error_iv)
            warning   = DATA(lv_create_warning)
        ).

        IF lv_create_error IS NOT INITIAL.
          io_out->write( 'Create interval failed.' ).
          io_out->write( ls_create_error ).
          io_out->write( lt_create_error_iv ).
          RETURN.
        ENDIF.

        io_out->write( 'Number Range reset successfully.' ).
        io_out->write( 'Next expected number: 0000000001' ).

      CATCH cx_root INTO DATA(lo_error).
        io_out->write( lo_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
