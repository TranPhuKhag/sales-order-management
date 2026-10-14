CLASS lhc_Item DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
*&---------------------------------------------------------------------*
* Constants: Validation State Areas
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_state_area,
        product_id         TYPE string VALUE 'PRODUCT_ID',
        plant              TYPE string VALUE 'PLANT',
        requested_quantity TYPE string VALUE 'REQUESTED_QUANTITY',
        schedule_quantity  TYPE string VALUE 'SCHEDULE_QUANTITY',
      END OF lc_state_area.

*&---------------------------------------------------------------------*
* Early Numbering
*&---------------------------------------------------------------------*
    METHODS earlynumbering_cba_Schedulelin
      FOR NUMBERING
      IMPORTING entities FOR CREATE Item\_Scheduleline.
*&---------------------------------------------------------------------*
* Dynamic Feature Control
*&---------------------------------------------------------------------*
    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING keys
        REQUEST requested_features FOR Item
      RESULT result.
*&---------------------------------------------------------------------*
* Determinations
*&---------------------------------------------------------------------*
    METHODS calculate_item_net_amount
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculate_item_net_amount.

    METHODS calculate_header_net_amount
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~calculate_header_net_amount.

    METHODS set_product_details
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~set_product_details.

    METHODS set_delivery_status
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Item~set_delivery_status.

*&---------------------------------------------------------------------*
* Validations
*&---------------------------------------------------------------------*
    METHODS empty_on_save
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~empty_on_save.

    METHODS check_requested_quantity
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~check_requested_quantity.

    METHODS check_schedule_quantity
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Item~check_schedule_quantity.
    METHODS set_overall_status FOR DETERMINE ON MODIFY
       keys FOR Item~set_overall_status.
    METHODS recalc_item_delivery_status FOR MODIFY
      keys FOR ACTION Item~recalc_item_delivery_status.
    METHODS refresh_delivery_status FOR DETERMINE ON MODIFY
      keys FOR Item~refresh_delivery_status.

ENDCLASS.

CLASS lhc_Item IMPLEMENTATION.

METHOD get_instance_features.

  DATA:
    lv_can_edit_item        TYPE abap_bool,
    lv_can_create_schedule  TYPE abap_bool,
    lv_is_closed            TYPE abap_bool,
    lv_is_fully_delivered   TYPE abap_bool.

  " Read requested Sales Order Items.
  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item
      FIELDS ( RequestedQuantity ConfirmedQuantity DeliveryStatus )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_items).

  " Read parent Sales Order Headers.
  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item BY \_Header
      FIELDS ( LifecycleStatus OverallStatus )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers)
    LINK DATA(lt_header_links).

  LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>).

    CLEAR:
      lv_can_edit_item,
      lv_can_create_schedule,
      lv_is_closed,
      lv_is_fully_delivered.

    " Begin change: KHANGTP5 - 14/10/2026
    " Check whether the parent Sales Order is closed.
    READ TABLE lt_header_links
      ASSIGNING FIELD-SYMBOL(<lfs_link>)
      WITH KEY source-%tky = <lfs_item>-%tky.

    IF sy-subrc = 0.

      READ TABLE lt_headers
        ASSIGNING FIELD-SYMBOL(<lfs_header>)
        WITH KEY %tky = <lfs_link>-target-%tky.

      IF sy-subrc = 0.

        IF <lfs_header>-LifecycleStatus = 'COMPLETED'
           OR <lfs_header>-OverallStatus = 'COMPLETED'
           OR <lfs_header>-OverallStatus = 'CANCELLED'.

          lv_is_closed = abap_true.

        ENDIF.

      ENDIF.

    ENDIF.

    " Old logic:
    " IF <lfs_item>-DeliveryStatus = 'FULLY DELIVERED'
    "    OR <lfs_item>-ConfirmedQuantity >= <lfs_item>-RequestedQuantity.
    "   lv_editable = abap_false.
    " ENDIF.

    " A new Item with quantity 0 is not fully delivered.
    IF <lfs_item>-RequestedQuantity > 0
       AND ( <lfs_item>-DeliveryStatus = 'FULLY DELIVERED'
          OR <lfs_item>-ConfirmedQuantity >= <lfs_item>-RequestedQuantity ).

      lv_is_fully_delivered = abap_true.

    ENDIF.

    " Allow ScheduleLine creation while delivery is incomplete.
    IF lv_is_closed = abap_false
       AND lv_is_fully_delivered = abap_false.

      lv_can_create_schedule = abap_true.

    ENDIF.

    " Allow Item editing only before the first confirmation.
    IF lv_can_create_schedule = abap_true
       AND <lfs_item>-ConfirmedQuantity = 0.

      lv_can_edit_item = abap_true.

    ENDIF.

    " Return dynamic instance features.
    APPEND VALUE #(
      %tky = <lfs_item>-%tky

      %features-%update = COND #(
        WHEN lv_can_edit_item = abap_true
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

      %features-%delete = COND #(
        WHEN lv_can_edit_item = abap_true
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

      %assoc-_ScheduleLine = COND #(
        WHEN lv_can_create_schedule = abap_true
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled
      )

    ) TO result.
  ENDLOOP.

ENDMETHOD.
**********************************************************************
* Early Numbering: Generate Schedule Line IDs
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Generate Schedule Line IDs during RAP Early Numbering.
*   Determine the highest existing Schedule Line ID for each Item.
*   Generate sequential IDs in format 0001, 0002, 0003, ...
*---------------------------------------------------------------------*
* Parameters:
* --> ENTITIES             : Schedule Lines to be created by association
* <-- MAPPED-SCHEDULELINE  : Schedule Lines with assigned IDs
*---------------------------------------------------------------------*
  METHOD earlynumbering_cba_Schedulelin.

    DATA:
      lv_max_sched_id  TYPE zteam2_sched_ln-schedule_line_id,
      lv_next_sched_id TYPE zteam2_sched_ln-schedule_line_id.


    " Read existing Schedule Lines from RAP transactional buffer.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item BY \_ScheduleLine
        FROM CORRESPONDING #( entities )
        LINK DATA(lt_sched_links).


    " Process each Item separately.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>)
         GROUP BY (
           SalesOrderId     = <ls_entity>-SalesOrderId
           SalesOrderItemId = <ls_entity>-SalesOrderItemId
           IsDraft          = <ls_entity>-%is_draft
         )
         ASSIGNING FIELD-SYMBOL(<ls_group>).


      CLEAR lv_max_sched_id.

      " Find the highest existing Schedule Line ID
      " of the current Sales Order Item.
      LOOP AT lt_sched_links ASSIGNING FIELD-SYMBOL(<ls_link>)
           WHERE source-SalesOrderId     = <ls_group>-SalesOrderId
             AND source-SalesOrderItemId = <ls_group>-SalesOrderItemId
             AND source-%is_draft        = <ls_group>-IsDraft.

        IF <ls_link>-target-ScheduleLineId > lv_max_sched_id.
          lv_max_sched_id = <ls_link>-target-ScheduleLineId.
        ENDIF.

      ENDLOOP.
      " Consider IDs already supplied in the current CREATE request.
      LOOP AT GROUP <ls_group>
        ASSIGNING FIELD-SYMBOL(<ls_parent>).
        LOOP AT <ls_parent>-%target
          ASSIGNING FIELD-SYMBOL(<ls_target>).
          IF <ls_target>-ScheduleLineId > lv_max_sched_id.
            lv_max_sched_id = <ls_target>-ScheduleLineId.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
      " Generate ScheduleLineId for new Schedule Lines.
      LOOP AT GROUP <ls_group>
        ASSIGNING <ls_parent>.

        LOOP AT <ls_parent>-%target
          ASSIGNING <ls_target>.
          " Keep existing ID if already supplied.
          IF <ls_target>-ScheduleLineId IS NOT INITIAL.

            APPEND VALUE #(
              %cid             = <ls_target>-%cid
              %is_draft        = <ls_target>-%is_draft
              SalesOrderId     = <ls_parent>-SalesOrderId
              SalesOrderItemId = <ls_parent>-SalesOrderItemId
              ScheduleLineId   = <ls_target>-ScheduleLineId
            ) TO mapped-ScheduleLine.
            CONTINUE.
          ENDIF.
          " Generate 0001, 0002, 0003, ...
          lv_next_sched_id =
            CONV #(
              zcl_team2_numbering_utility=>get_next_sequence(
                iv_current = CONV int8( lv_max_sched_id )
                iv_step    = 1
                iv_width   = 4
              )
            ).
          lv_max_sched_id = lv_next_sched_id.
          " Return generated key to RAP.
          APPEND VALUE #(
            %cid             = <ls_target>-%cid
            %is_draft        = <ls_target>-%is_draft
            SalesOrderId     = <ls_parent>-SalesOrderId
            SalesOrderItemId = <ls_parent>-SalesOrderItemId
            ScheduleLineId   = lv_next_sched_id
          ) TO mapped-ScheduleLine.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


**********************************************************************
* Determination: Calculate Sales Order Item Net Amount
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Automatically calculate the Net Amount of Sales Order Items.
*   Multiply Requested Quantity by Net Price.
*   Update the calculated amount in the RAP transactional buffer.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Items to be calculated
* <-- REPORTED-ITEM  : Messages returned during processing
*---------------------------------------------------------------------*
  METHOD calculate_item_net_amount.

    DATA:
      lt_items_update TYPE TABLE FOR UPDATE zir_team2_so_hd\\Item,
      lv_net_amount   TYPE zteam2_so_it-net_amount.

    " Read relevant Sales Order Items from the transactional buffer.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
        FIELDS ( RequestedQuantity NetPrice NetAmount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    " Calculate Net Amount for each Sales Order Item.
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).

      " Calculate Net Amount based on Requested Quantity and Net Price.
      lv_net_amount = <ls_item>-RequestedQuantity * <ls_item>-NetPrice.

      " Skip updating if Net Amount has not changed.
      IF <ls_item>-NetAmount = lv_net_amount.
        CONTINUE.
      ENDIF.

      " Prepare Item data with the calculated Net Amount.
      APPEND VALUE #(
        %tky      = <ls_item>-%tky
        NetAmount = lv_net_amount
      ) TO lt_items_update.

    ENDLOOP.

    " Update calculated Net Amount in the transactional buffer.
    IF lt_items_update IS NOT INITIAL.

      MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
        ENTITY Item
          UPDATE FIELDS ( NetAmount )
          WITH lt_items_update
        REPORTED DATA(lt_reported).

      " Forward messages returned by the update operation.
      reported = CORRESPONDING #( DEEP lt_reported ).
    ENDIF.
  ENDMETHOD.

**********************************************************************
* Determination: Recalculate Sales Order Header Net Amount
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Identify the parent Sales Order Headers of affected Items.
*   Trigger the Header Net Amount recalculation action.
*   Recalculate the Header Net Amount based on its Sales Order Items.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Items that trigger recalculation
*---------------------------------------------------------------------*
  METHOD calculate_header_net_amount.

    " Read the parent Sales Order Headers of affected Items.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item BY \_Header
        FIELDS ( SalesOrderId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Trigger Net Amount recalculation on the Header.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        EXECUTE recalc_header_net_amount
        FROM CORRESPONDING #( lt_headers ).

  ENDMETHOD.

  METHOD set_product_details.
    DATA: lt_items_update TYPE TABLE FOR UPDATE zir_team2_so_hd\\Item,
          lt_products     TYPE STANDARD TABLE OF zir_team2_products WITH EMPTY KEY,
          lt_prices       TYPE STANDARD TABLE OF zi_team2_prices WITH EMPTY KEY,
          lr_product_id   TYPE RANGE OF zir_team2_products-ProductId,
          lr_price_id     TYPE RANGE OF zi_team2_prices-ProductId,
          lv_description  TYPE zeteam2_product_desc,
          lv_sales_unit   TYPE zteam2_so_it-sales_unit,
          lv_net_price    TYPE zteam2_so_it-net_price,
          lv_currency     TYPE zteam2_so_it-currency_code,
          lv_best_date    TYPE zi_team2_prices-ValidityStartDate,
          lv_price_count  TYPE i.

    " Read relevant Sales Order Items.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
        FIELDS ( ProductId ProductDescription SalesUnit NetPrice CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Prepare Product IDs for lookup.
    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>)
         WHERE ProductId IS NOT INITIAL.

      APPEND VALUE #(
        sign   = 'I'
        option = 'EQ'
        low    = CONV zir_team2_products-ProductId( <ls_item>-ProductId )
      ) TO lr_product_id.

      APPEND VALUE #(
        sign   = 'I'
        option = 'EQ'
        low    = CONV zi_team2_prices-ProductId( <ls_item>-ProductId )
      ) TO lr_price_id.

    ENDLOOP.

    IF lr_product_id IS NOT INITIAL.

      " Read Product Master Data.
      SELECT FROM zir_team2_products
        FIELDS ProductId, ProductDesc, BaseUnit
        WHERE ProductId IN @lr_product_id
        INTO CORRESPONDING FIELDS OF TABLE @lt_products.

      " Read currently valid and active Product Prices.
      SELECT FROM zi_team2_prices
        FIELDS ProductId, UnitPrices, CurrencyCode,
               ValidityStartDate, ValidityEndDate
        WHERE ProductId IN @lr_price_id
          AND Active = @abap_true
          AND ValidityStartDate <= @sy-datum
        INTO CORRESPONDING FIELDS OF TABLE @lt_prices.

      " Sort prices by the newest validity start date.
      SORT lt_prices BY ProductId ASCENDING
                        ValidityStartDate DESCENDING.

    ENDIF.

    " Prepare Sales Order Item updates.
    LOOP AT lt_items ASSIGNING <ls_item>.

      CLEAR: lv_description,
             lv_sales_unit,
             lv_net_price,
             lv_currency,
             lv_best_date,
             lv_price_count.

      " Find Product Master Data.
      READ TABLE lt_products ASSIGNING FIELD-SYMBOL(<ls_product>)
        WITH KEY ProductId =
          CONV zir_team2_products-ProductId( <ls_item>-ProductId ).

      IF sy-subrc = 0.

        " Set Product Description and Sales Unit.
        lv_description = <ls_product>-ProductDesc.
        lv_sales_unit  = <ls_product>-BaseUnit.

        " Prepare Product ID for price lookup.
        DATA(lv_price_product_id) =
          CONV zi_team2_prices-ProductId( <ls_item>-ProductId ).

        " Find the newest valid Product Price.
        LOOP AT lt_prices ASSIGNING FIELD-SYMBOL(<ls_price>)
             WHERE ProductId = lv_price_product_id.

          IF lv_price_count = 0.

            lv_best_date   = <ls_price>-ValidityStartDate.
            lv_net_price   = <ls_price>-UnitPrices.
            lv_currency    = <ls_price>-CurrencyCode.
            lv_price_count = 1.

          ELSEIF <ls_price>-ValidityStartDate = lv_best_date.

            " Multiple prices exist for the same newest date.
            lv_price_count += 1.

          ELSE.
            " Older prices are not considered.
            EXIT.
          ENDIF.
        ENDLOOP.
        " Do not select an ambiguous Product Price.
        IF lv_price_count > 1.
          CLEAR: lv_net_price, lv_currency.
        ENDIF.

      ENDIF.

      " Skip updating if dependent fields have not changed.
      IF <ls_item>-ProductDescription = lv_description
         AND <ls_item>-SalesUnit      = lv_sales_unit
         AND <ls_item>-NetPrice       = lv_net_price
         AND <ls_item>-CurrencyCode   = lv_currency.
        CONTINUE.
      ENDIF.

      " Prepare dependent field updates.
      APPEND VALUE #(
        %tky               = <ls_item>-%tky
        ProductDescription = lv_description
        SalesUnit          = lv_sales_unit
        NetPrice           = lv_net_price
        CurrencyCode       = lv_currency
      ) TO lt_items_update.

    ENDLOOP.

    IF lt_items_update IS INITIAL.
      RETURN.
    ENDIF.

    " Update Sales Order Items in RAP transactional buffer.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
        UPDATE FIELDS ( ProductDescription SalesUnit NetPrice CurrencyCode )
        WITH lt_items_update
      FAILED DATA(ls_failed_update)
      REPORTED DATA(ls_reported_update).

  ENDMETHOD.
**********************************************************************
* Validation: Check Required Sales Order Item Fields
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 11/10/2026
* Content explanation:
*   Validate required fields of the Sales Order Item before saving.
*   Check whether Plant has been entered.
*   Reject the Sales Order Item and report an error if Plant is missing.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Items to be validated
* <-- FAILED-ITEM    : Sales Order Items that fail validation
* <-- REPORTED-ITEM  : Validation messages and highlighted fields
  METHOD empty_on_save.
    " Read relevant Sales Order Items.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
      FIELDS ( Plant )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).
    LOOP AT lt_items INTO DATA(ls_item).
      DATA(lv_has_error) = abap_false.

      " Clear previous state messages.
      APPEND VALUE #( %tky        = ls_item-%tky
                      %state_area = lc_state_area-plant
                    ) TO reported-item.
      " Validate Plant
      IF ls_item-plant IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = ls_item-%tky
          %state_area = lc_state_area-plant
          %msg        = NEW zcm_team2_so(
            im_textid     = zcm_team2_so=>c_missing_required_fields
            im_severity   = if_abap_behv_message=>severity-error
            im_field_name = 'Plant'
          )
          %element-plant = if_abap_behv=>mk-on
        ) TO reported-item.
      ENDIF.
      " Reject Sales Order Item if any required field is missing
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky = ls_item-%tky
        ) TO failed-item.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

**********************************************************************
* Validation: Check Sales Order Item Requested Quantity
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 12/10/2026
* Content explanation:
*   Validate the Requested Quantity of Sales Order Items before saving.
*   Ensure that Requested Quantity is greater than zero.
*   Reject the Sales Order Item and report an error if the quantity
*   is zero or negative.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Items to be validated
* <-- FAILED-ITEM    : Sales Order Items that fail validation
* <-- REPORTED-ITEM  : Validation messages and highlighted fields
*---------------------------------------------------------------------*
  METHOD check_requested_quantity.
    " Read relevant Sales Order Items.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
      FIELDS ( RequestedQuantity )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).
    LOOP AT lt_items INTO DATA(ls_item).
      " Clear previous state messages.
      APPEND VALUE #( %tky        = ls_item-%tky
                      %state_area = lc_state_area-requested_quantity
                    ) TO reported-item.
      " Validate Requested Quantity must be greater than zero.
      IF ls_item-RequestedQuantity <= 0.
        APPEND VALUE #(
          %tky        = ls_item-%tky
          %state_area = lc_state_area-requested_quantity
          %msg        = NEW zcm_team2_so(
            im_textid   = zcm_team2_so=>c_invalid_requested_quantity
            im_severity = if_abap_behv_message=>severity-error
          )
          %element-RequestedQuantity = if_abap_behv=>mk-on
          ) TO reported-item.
        " Reject Sales Order Item if Requested Quantity is invalid.
        APPEND VALUE #(
          %tky = ls_item-%tky
        ) TO failed-item.

      ENDIF.
    ENDLOOP.
  ENDMETHOD.
*&---------------------------------------------------------------------*
* Determination: Set Initial Delivery Status for Sales Order Items
*&---------------------------------------------------------------------*
* Created by         : KHANGTP5
* Created date       : 10/10/2026
* Content explanation:
*   Initialize the Delivery Status of Sales Order Items.
*   Set Delivery Status to NOT DELIVERED and Criticality to 1.
*   Preserve existing Delivery Status values.
*   Update only Items without an assigned Delivery Status.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS : Sales Order Items requiring status initialization
*---------------------------------------------------------------------*
  METHOD set_delivery_status.
    DATA: lt_items_update TYPE TABLE FOR UPDATE zir_team2_so_hd\\Item.

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item FIELDS ( DeliveryStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>).
      " Preserve a previously calculated delivery status.
      IF <lfs_item>-DeliveryStatus IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = <lfs_item>-%tky
                      DeliveryStatus = 'NOT DELIVERED' ) TO lt_items_update.
    ENDLOOP.

    IF lt_items_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item UPDATE FIELDS ( DeliveryStatus )
      WITH lt_items_update
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).
  ENDMETHOD.
*---------------------------------------------------------------------*
* Determination: Set Sales Order Overall Status
*---------------------------------------------------------------------*
* Created by         : KHANGTP5
* Created date       : 13/10/2026
* Content explanation:
*   Recalculate the Sales Order Header Overall Status.
*   Read all Sales Order Items belonging to the affected Headers.
*   Determine the status based on Item delivery progress.
*   Set COMPLETED when all Items are fully delivered.
*   Set OVERDUE when delivery is incomplete and past due.
*   Set PARTIAL when at least one Item has been delivered.
*   Set OPEN when no Items have been delivered.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Items with changed DeliveryStatus
*---------------------------------------------------------------------*
  METHOD set_overall_status.
    " Call shared Header calculation after Item DeliveryStatus changes.
    " Use parent SalesOrderId so DELETE requests also resolve the Header.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header FIELDS ( SalesOrderId )
      WITH VALUE #( FOR ls_key IN keys
                    ( SalesOrderId = ls_key-SalesOrderId
                      %is_draft    = ls_key-%is_draft ) )
      RESULT DATA(lt_headers).

    SORT lt_headers BY %tky.
    DELETE ADJACENT DUPLICATES FROM lt_headers COMPARING %tky.

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header EXECUTE recalc_overall_status
      FROM VALUE #( FOR ls_header IN lt_headers ( %tky = ls_header-%tky ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
  ENDMETHOD.

  METHOD recalc_item_delivery_status.
  " Bo dem lv_count_pending / lv_count_confirmed; KHONG su dung PENDING.
  " Moi: tong so luong xac nhan quyet dinh DeliveryStatus.
  DATA lt_items_update TYPE TABLE FOR UPDATE zir_team2_so_hd\\Item.

  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item
      FIELDS ( SalesOrderId SalesOrderItemId RequestedQuantity ConfirmedQuantity DeliveryStatus )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_items).

  IF lt_items IS INITIAL.
    RETURN.
  ENDIF.

  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item BY \_ScheduleLine
      FIELDS ( AvailabilityStatus ConfirmedQuantity )
      WITH CORRESPONDING #( lt_items )
    RESULT DATA(lt_schedule_lines)
    LINK DATA(lt_links).

  LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>).
    DATA lv_confirmed_qty TYPE zteam2_so_it-confirmed_quantity.
    CLEAR lv_confirmed_qty.

    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
      WHERE source-%tky = <lfs_item>-%tky.
      READ TABLE lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_line>)
        WITH KEY %tky = <lfs_link>-target-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Count only confirmed Schedule Lines.
      IF <lfs_line>-AvailabilityStatus = 'CONFIRMED'.
        lv_confirmed_qty += <lfs_line>-ConfirmedQuantity.
      ENDIF.
    ENDLOOP.

    DATA(lv_status) = CONV zteam2_so_it-delivery_status( 'NOT DELIVERED' ).
    IF <lfs_item>-RequestedQuantity > 0.
      IF lv_confirmed_qty >= <lfs_item>-RequestedQuantity.
        lv_status = 'FULLY DELIVERED'.
      ELSEIF lv_confirmed_qty > 0.
        lv_status = 'PARTIALLY DELIVERED'.
      ENDIF.
    ENDIF.

    IF <lfs_item>-ConfirmedQuantity = lv_confirmed_qty
       AND <lfs_item>-DeliveryStatus = lv_status.
      CONTINUE.
    ENDIF.

    APPEND VALUE #( %tky = <lfs_item>-%tky
                    ConfirmedQuantity = lv_confirmed_qty
                    DeliveryStatus = lv_status ) TO lt_items_update.
  ENDLOOP.

  IF lt_items_update IS NOT INITIAL.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item UPDATE FIELDS ( ConfirmedQuantity DeliveryStatus )
      WITH lt_items_update
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
    IF ls_failed IS NOT INITIAL.
      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<lfs_failed_item>).
        APPEND VALUE #( %tky = <lfs_failed_item>-%tky ) TO failed-Item.
        APPEND VALUE #( %tky = <lfs_failed_item>-%tky
                        %msg = new_message_with_text(
                          text = 'Item quantity/status recalculation failed.'
                          severity = if_abap_behv_message=>severity-error ) ) TO reported-Item.
      ENDLOOP.
      RETURN.
    ENDIF.
  ENDIF.

  " Trigger Header calculation immediately; do not depend on determination order.
  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Header FIELDS ( SalesOrderId )
    WITH VALUE #( FOR ls_item IN lt_items
                  ( SalesOrderId = ls_item-SalesOrderId
                    %is_draft    = ls_item-%is_draft ) )
    RESULT DATA(lt_headers).

  SORT lt_headers BY %tky.
  DELETE ADJACENT DUPLICATES FROM lt_headers COMPARING %tky.
  IF lt_headers IS NOT INITIAL.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header EXECUTE recalc_overall_status
      FROM VALUE #( FOR ls_header IN lt_headers ( %tky = ls_header-%tky ) )
      FAILED DATA(ls_failed_header)
      REPORTED DATA(ls_reported_header).
    IF ls_failed_header IS NOT INITIAL.
      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<lfs_failed_header_item>).
        APPEND VALUE #( %tky = <lfs_failed_header_item>-%tky ) TO failed-Item.
        APPEND VALUE #( %tky = <lfs_failed_header_item>-%tky
                        %msg = new_message_with_text(
                          text = 'Sales Order Header status recalculation failed.'
                          severity = if_abap_behv_message=>severity-error ) ) TO reported-Item.
      ENDLOOP.
    ENDIF.
  ENDIF.

  ENDMETHOD.

**********************************************************************
* Determination: Refresh Item Delivery After Quantity Changes
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 14/10/2026
* Content explanation:
*   Recompute Item delivery status after changing Requested Quantity.
*   Recalculate the parent Header through the shared internal action.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Items whose Requested Quantity changed
*---------------------------------------------------------------------*
METHOD refresh_delivery_status.
  MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item EXECUTE recalc_item_delivery_status
    FROM CORRESPONDING #( keys )
    FAILED DATA(ls_failed)
    REPORTED DATA(ls_reported).

  " Schedule Line availability depends on the Item Requested Quantity;
  " re-evaluate it, otherwise the status stays as calculated for the old quantity.
  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item BY \_ScheduleLine
      FROM CORRESPONDING #( keys )
    LINK DATA(lt_sched_links).

  IF lt_sched_links IS INITIAL.
    RETURN.
  ENDIF.

  MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY ScheduleLine EXECUTE recalc_availability
    FROM VALUE #( FOR ls_link IN lt_sched_links ( %tky = ls_link-target-%tky ) )
    FAILED DATA(ls_failed_sched)
    REPORTED DATA(ls_reported_sched).
ENDMETHOD.

**********************************************************************
* Validation: Item Requested Quantity vs. Schedule Line Quantities
**********************************************************************
* Content explanation:
*   The total Requested Quantity of all Schedule Lines must not exceed
*   the Item Requested Quantity. The Schedule Line validation only runs
*   when a Schedule Line changes; this one covers lowering the Item
*   quantity below the already planned Schedule Lines.
*---------------------------------------------------------------------*
METHOD check_schedule_quantity.
  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item
      FIELDS ( RequestedQuantity )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_items).

  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Item BY \_ScheduleLine
      FIELDS ( RequestedQuantity )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_schedule_lines)
    LINK DATA(lt_links).

  LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>).
    " Clear previous state messages.
    APPEND VALUE #( %tky        = <lfs_item>-%tky
                    %state_area = lc_state_area-schedule_quantity
                  ) TO reported-item.

    DATA(lv_total_quantity) = CONV decfloat34( 0 ).
    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
      WHERE source-%tky = <lfs_item>-%tky.
      READ TABLE lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_line>)
        WITH KEY %tky = <lfs_link>-target-%tky.
      IF sy-subrc = 0.
        lv_total_quantity += CONV decfloat34( <lfs_line>-RequestedQuantity ).
      ENDIF.
    ENDLOOP.

    IF lv_total_quantity > CONV decfloat34( <lfs_item>-RequestedQuantity ).
      APPEND VALUE #( %tky = <lfs_item>-%tky ) TO failed-item.
      APPEND VALUE #(
        %tky        = <lfs_item>-%tky
        %state_area = lc_state_area-schedule_quantity
        %msg        = NEW zcm_team2_so(
          im_textid   = zcm_team2_so=>c_schedule_quantity_exceeded
          im_severity = if_abap_behv_message=>severity-error
        )
        %element-RequestedQuantity = if_abap_behv=>mk-on
      ) TO reported-item.
    ENDIF.
  ENDLOOP.
ENDMETHOD.
ENDCLASS.
