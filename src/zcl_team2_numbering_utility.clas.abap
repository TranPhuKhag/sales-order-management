**********************************************************************
* Class: Sales Order Numbering Utility
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 13/10/2026
* Content explanation:
*   Provide reusable numbering functions for the Sales Order BO.
*   Get one or multiple numbers from a Number Range Object.
*   Generate sequential Item and Schedule Line IDs.
**********************************************************************
CLASS zcl_team2_numbering_utility DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

*&---------------------------------------------------------------------*
* Number Range
*&---------------------------------------------------------------------*
    CLASS-METHODS get_number_range
      IMPORTING
        iv_object       TYPE cl_numberrange_runtime=>nr_object
        iv_interval     TYPE cl_numberrange_runtime=>nr_interval
        iv_quantity     TYPE cl_numberrange_runtime=>nr_quantity DEFAULT 1
      EXPORTING
        ev_number       TYPE cl_numberrange_runtime=>nr_number
        ev_return_code  TYPE cl_numberrange_runtime=>nr_returncode
        ev_returned_qty TYPE cl_numberrange_runtime=>nr_returned_quantity
      RAISING
        cx_nr_object_not_found
        cx_number_ranges.

*&---------------------------------------------------------------------*
* Sequential Numbering
*&---------------------------------------------------------------------*
    CLASS-METHODS get_next_sequence
      IMPORTING
        iv_current TYPE int8
        iv_step    TYPE int8
        iv_width   TYPE i
      RETURNING
        VALUE(rv_sequence) TYPE string.

ENDCLASS.


CLASS zcl_team2_numbering_utility IMPLEMENTATION.


  METHOD get_number_range.
**********************************************************************
* Method: Get Number Range
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 13/10/2026
* Content explanation:
*   Request one or multiple sequential numbers from the specified
*   Number Range Object and interval.
*   Return the highest reserved number, Number Range return code,
*   and the actual quantity of numbers returned.
*---------------------------------------------------------------------*
* Parameters:
* --> IV_OBJECT       : Number Range Object
* --> IV_INTERVAL     : Number Range Interval
* --> IV_QUANTITY     : Number of numbers to reserve
* <-- EV_NUMBER       : Highest number of the reserved block
* <-- EV_RETURN_CODE  : Number Range return code
* <-- EV_RETURNED_QTY : Actual number of reserved numbers
*---------------------------------------------------------------------*
    cl_numberrange_runtime=>number_get(
      EXPORTING
        object            = iv_object
        nr_range_nr       = iv_interval
        quantity          = iv_quantity
      IMPORTING
        number            = ev_number
        returncode        = ev_return_code
        returned_quantity = ev_returned_qty
    ).

  ENDMETHOD.



  METHOD get_next_sequence.
**********************************************************************
* Method: Generate Next Sequential Number
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 13/10/2026
* Content explanation:
*   Calculate the next sequential number from the current value.
*   Increase the current value by the specified step.
*   Format the result with leading zeros to the specified width.
*---------------------------------------------------------------------*
* Parameters:
* --> IV_CURRENT      : Current sequence number
* --> IV_STEP         : Increment value
* --> IV_WIDTH        : Output number length
* <-- RV_SEQUENCE     : Next formatted sequence number
*---------------------------------------------------------------------*
    DATA(lv_next_sequence) = iv_current + iv_step.

    rv_sequence = |{ lv_next_sequence }|.

  ENDMETHOD.

ENDCLASS.
