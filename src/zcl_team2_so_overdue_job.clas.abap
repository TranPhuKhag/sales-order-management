
CLASS zcl_team2_so_overdue_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_rt_run.

  PRIVATE SECTION.
    CONSTANTS lc_batch_size TYPE i VALUE 200.

ENDCLASS.


CLASS zcl_team2_so_overdue_job IMPLEMENTATION.

  METHOD if_apj_rt_run~execute.

    DATA lt_actions TYPE TABLE FOR ACTION IMPORT zir_team2_so_hd~recalc_overall_status.


    DATA lv_from         TYPE i VALUE 1.
    DATA lv_to           TYPE i.
    DATA lv_failed_count TYPE i.

    " Read active Sales Orders requiring recalculation.
    " Read the table, not ZIR_TEAM2_SO_HD: the CDS access control only
    " returns orders created by the job user (or all for a Manager), so the
    " job would silently skip the Sales Orders of other users.
    SELECT FROM zteam2_so_hd
      FIELDS sales_order_id
      WHERE overall_status = 'OPEN'
         OR overall_status = 'PARTIAL'
         OR overall_status = 'OVERDUE'
      ORDER BY sales_order_id
      INTO TABLE @DATA(lt_orders).

    IF lt_orders IS INITIAL.
      RETURN.
    ENDIF.

    " Process Sales Orders in batches.
    WHILE lv_from <= lines( lt_orders ).

      lv_to = lv_from + lc_batch_size - 1.
      CLEAR lt_actions.

      " Prepare active Sales Order action requests.
      LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<lfs_order>)
        FROM lv_from TO lv_to.

        APPEND VALUE #(
          SalesOrderId = <lfs_order>-sales_order_id
          %is_draft    = if_abap_behv=>mk-off
        ) TO lt_actions.

      ENDLOOP.

      " Execute the RAP Action.
      MODIFY ENTITIES OF zir_team2_so_hd
        ENTITY Header
          EXECUTE recalc_overall_status
          FROM lt_actions
        FAILED DATA(lt_failed)
        REPORTED DATA(lt_reported).

      " Skip Sales Orders that cannot be changed now (e.g. locked by an open
      " draft) instead of aborting the whole job; they are retried next run.
      lv_failed_count += lines( lt_failed-header ).

      " Persist the successfully recalculated Sales Orders of this batch.
      COMMIT ENTITIES RESPONSE OF zir_team2_so_hd
        FAILED DATA(lt_failed_commit)
        REPORTED DATA(lt_reported_commit).

      IF sy-subrc <> 0
         OR lt_failed_commit IS NOT INITIAL.

        ROLLBACK ENTITIES.
        lv_failed_count += lines( lt_actions ) - lines( lt_failed-header ).

      ENDIF.

      " Continue with the next batch.
      lv_from = lv_to + 1.

    ENDWHILE.

    " All other Sales Orders are already saved; mark the run as failed so
    " the skipped Sales Orders are noticed in the Application Jobs app.
    IF lv_failed_count > 0.
      RAISE EXCEPTION TYPE cx_apj_rt_content
        MESSAGE ID 'ZTEAM2_SO'
        NUMBER 020
        WITH lv_failed_count.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

