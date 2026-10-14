
CLASS zcl_team2_so_reset_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.


CLASS zcl_team2_so_reset_data IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    "========================================
    " CONFIGURATION
    "========================================
    " abap_false = Preview
    " abap_true  = Execute deletion

    CONSTANTS lc_execute TYPE abap_bool
      VALUE abap_true.

    "========================================
    " SAFETY CHECK
    "========================================
    IF sy-mandt <> '100'.
      out->write(
        'ERROR: Only client 100 is allowed.'
      ).
      RETURN.
    ENDIF.

    "========================================
    " COUNT BEFORE DELETE
    "========================================

    SELECT COUNT( * )
      FROM zteam2_sched_ln
      INTO @DATA(lv_sched).

    SELECT COUNT( * )
      FROM zteam2_so_it
      INTO @DATA(lv_item).

    SELECT COUNT( * )
      FROM zteam2_so_hd
      INTO @DATA(lv_header).

    SELECT COUNT( * )
      FROM zteam2_sche_ln_d
      INTO @DATA(lv_sched_d).

    SELECT COUNT( * )
      FROM zteam2_so_it_d
      INTO @DATA(lv_item_d).

    SELECT COUNT( * )
      FROM zteam2_so_hd_d
      INTO @DATA(lv_header_d).

    DATA(lv_total) =
        lv_sched
      + lv_item
      + lv_header
      + lv_sched_d
      + lv_item_d
      + lv_header_d.

    out->write( '================================' ).
    out->write( 'SALES ORDER DATA RESET' ).
    out->write( 'CLIENT: 100' ).
    out->write( '================================' ).

    out->write( 'BEFORE DELETE:' ).

    out->write(
      |Active Schedule Lines: { lv_sched }|
    ).

    out->write(
      |Active Items: { lv_item }|
    ).

    out->write(
      |Active Headers: { lv_header }|
    ).

    out->write(
      |Draft Schedule Lines: { lv_sched_d }|
    ).

    out->write(
      |Draft Items: { lv_item_d }|
    ).

    out->write(
      |Draft Headers: { lv_header_d }|
    ).

    out->write(
      |TOTAL RECORDS: { lv_total }|
    ).

    "========================================
    " PREVIEW MODE
    "========================================

    IF lc_execute = abap_false.

      out->write(
        'PREVIEW ONLY - NO DATA DELETED'
      ).

      out->write(
        'Change lc_execute to abap_true to delete.'
      ).

      RETURN.

    ENDIF.

    "========================================
    " DELETE DRAFT DATA
    " CHILD -> PARENT
    "========================================

    DELETE FROM zteam2_sche_ln_d.
    DATA(lv_deleted_sched_d) = sy-dbcnt.

    DELETE FROM zteam2_so_it_d.
    DATA(lv_deleted_item_d) = sy-dbcnt.

    DELETE FROM zteam2_so_hd_d.
    DATA(lv_deleted_header_d) = sy-dbcnt.

    "========================================
    " DELETE ACTIVE DATA
    " CHILD -> PARENT
    "========================================

    DELETE FROM zteam2_sched_ln.
    DATA(lv_deleted_sched) = sy-dbcnt.

    DELETE FROM zteam2_so_it.
    DATA(lv_deleted_item) = sy-dbcnt.

    DELETE FROM zteam2_so_hd.
    DATA(lv_deleted_header) = sy-dbcnt.

    "========================================
    " REPORT DELETE RESULTS
    "========================================

    out->write( 'DELETE STATEMENTS EXECUTED:' ).

    out->write(
      |Draft Schedule Lines: { lv_deleted_sched_d }|
    ).

    out->write(
      |Draft Items: { lv_deleted_item_d }|
    ).

    out->write(
      |Draft Headers: { lv_deleted_header_d }|
    ).

    out->write(
      |Active Schedule Lines: { lv_deleted_sched }|
    ).

    out->write(
      |Active Items: { lv_deleted_item }|
    ).

    out->write(
      |Active Headers: { lv_deleted_header }|
    ).

    "========================================
    " VERIFY REMAINING RECORDS
    "========================================

    SELECT COUNT( * )
      FROM zteam2_sched_ln
      INTO @lv_sched.

    SELECT COUNT( * )
      FROM zteam2_so_it
      INTO @lv_item.

    SELECT COUNT( * )
      FROM zteam2_so_hd
      INTO @lv_header.

    SELECT COUNT( * )
      FROM zteam2_sche_ln_d
      INTO @lv_sched_d.

    SELECT COUNT( * )
      FROM zteam2_so_it_d
      INTO @lv_item_d.

    SELECT COUNT( * )
      FROM zteam2_so_hd_d
      INTO @lv_header_d.

    lv_total =
        lv_sched
      + lv_item
      + lv_header
      + lv_sched_d
      + lv_item_d
      + lv_header_d.

    out->write( '================================' ).
    out->write( 'AFTER DELETE - CURRENT TRANSACTION' ).
    out->write( |Remaining records: { lv_total }| ).

    IF lv_total = 0.

      out->write(
        'SUCCESS: All six tables are empty.'
      ).

    ELSE.

      out->write(
        'WARNING: Some records still remain.'
      ).

    ENDIF.

    out->write(
      'Check RAP draft administration separately.'
    ).

    out->write(
      'Number Range is not changed by this class.'
    ).

  ENDMETHOD.

ENDCLASS.

