
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


    DATA lv_from TYPE i VALUE 1.
    DATA lv_to   TYPE i.

    " Read active Sales Orders requiring recalculation.
    SELECT FROM zir_team2_so_hd
      FIELDS SalesOrderId
      WHERE OverallStatus = 'OPEN'
         OR OverallStatus = 'PARTIAL'
         OR OverallStatus = 'OVERDUE'
      ORDER BY SalesOrderId
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
          SalesOrderId = <lfs_order>-SalesOrderId
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

      " Stop if any Action fails.
      IF lt_failed IS NOT INITIAL.

        ROLLBACK ENTITIES.

        RAISE EXCEPTION TYPE cx_apj_rt_content
          MESSAGE ID 'ZTEAM2_SO'
          NUMBER 020.

      ENDIF.

      " Persist the batch through RAP.
      COMMIT ENTITIES RESPONSE OF zir_team2_so_hd
        FAILED DATA(lt_failed_commit)
        REPORTED DATA(lt_reported_commit).

      IF sy-subrc <> 0
         OR lt_failed_commit IS NOT INITIAL.

        ROLLBACK ENTITIES.

        RAISE EXCEPTION TYPE cx_apj_rt_content
          MESSAGE ID 'ZTEAM2_SO'
          NUMBER 021.

      ENDIF.

      " Continue with the next batch.
      lv_from = lv_to + 1.

    ENDWHILE.

  ENDMETHOD.

ENDCLASS.

