CLASS lhc_scheduleline DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.
*&---------------------------------------------------------------------*
* Constants: Availability Status
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_status,
        unavailable TYPE string VALUE 'UNAVAILABLE',
        available   TYPE string VALUE 'AVAILABLE',
        confirmed   TYPE string VALUE 'CONFIRMED',
      END OF lc_status.

*&---------------------------------------------------------------------*
* Constants: Validation State Areas
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_state_area,
        requested_quantity TYPE string VALUE 'VALIDATE_SCHEDULE_QUANTITY',
      END OF lc_state_area.

*&---------------------------------------------------------------------*
* Dynamic Feature Control
*&---------------------------------------------------------------------*
    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING keys
                  REQUEST requested_features FOR ScheduleLine
      RESULT    result.

*&---------------------------------------------------------------------*
* Authorization
*&---------------------------------------------------------------------*
    METHODS get_global_authorizations
      FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR ScheduleLine
      RESULT result.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING keys
                  REQUEST requested_authorizations FOR ScheduleLine
      RESULT    result.

*&---------------------------------------------------------------------*
* Actions
*&---------------------------------------------------------------------*
    METHODS confirmDelivery
      FOR MODIFY
      IMPORTING keys   FOR ACTION ScheduleLine~confirmDelivery
      RESULT    result.

*&---------------------------------------------------------------------*
* Determinations
*&---------------------------------------------------------------------*
    METHODS setAvailability
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ScheduleLine~setAvailability.

    METHODS set_sales_unit
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ScheduleLine~set_sales_unit.

    METHODS set_delivery_status
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ScheduleLine~set_delivery_status.

*&---------------------------------------------------------------------*
* Validations
*&---------------------------------------------------------------------*
    METHODS check_confirmed_quantity
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR ScheduleLine~check_confirmed_quantity.

    METHODS check_requested_quantity
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR ScheduleLine~check_requested_quantity.

ENDCLASS.

CLASS lhc_scheduleline IMPLEMENTATION.


  METHOD get_instance_features.
      " Only active AVAILABLE lines of an uncompleted Item can be confirmed.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine
        FIELDS ( AvailabilityStatus ConfirmedQuantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_schedule_lines).

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine BY \_Item
        FIELDS ( DeliveryStatus ConfirmedQuantity RequestedQuantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      LINK DATA(lt_links).

    LOOP AT lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_schedule_line>).
      DATA(lv_allowed) = abap_false.

      READ TABLE lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
        WITH KEY source-%tky = <lfs_schedule_line>-%tky.
      IF sy-subrc = 0.
        READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>)
          WITH KEY %tky = <lfs_link>-target-%tky.
        IF sy-subrc = 0
           AND <lfs_item>-DeliveryStatus <> 'FULLY DELIVERED'
           AND <lfs_item>-ConfirmedQuantity < <lfs_item>-RequestedQuantity.
          lv_allowed = abap_true.
        ENDIF.
      ENDIF.

      DATA(lv_can_confirm) = COND #( WHEN lv_allowed = abap_true
                                     AND <lfs_schedule_line>-%is_draft = if_abap_behv=>mk-off
                                     AND <lfs_schedule_line>-AvailabilityStatus = lc_status-available
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled ).

      DATA(lv_can_edit) = COND #( WHEN lv_allowed = abap_true
                                  AND <lfs_schedule_line>-AvailabilityStatus <> lc_status-confirmed
                                  THEN if_abap_behv=>fc-o-enabled
                                  ELSE if_abap_behv=>fc-o-disabled ).

      APPEND VALUE #( %tky                    = <lfs_schedule_line>-%tky
                      %action-confirmDelivery = lv_can_confirm
                      %features-%update                 = lv_can_edit
                      %features-%delete                 = lv_can_edit
                    ) TO result.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD confirmDelivery.

    TYPES: BEGIN OF ty_reserved,
             sales_order_id      TYPE zteam2_so_it-sales_order_id,
             sales_order_item_id TYPE zteam2_so_it-sales_order_item_id,
             quantity            TYPE decfloat34,
           END OF ty_reserved.

    FIELD-SYMBOLS <lfs_reserved> TYPE ty_reserved.

    DATA: lt_schedule_updates TYPE TABLE FOR UPDATE zir_team2_so_hd\\ScheduleLine,
          lt_stock_requests   TYPE TABLE FOR ACTION IMPORT zir_team2_products\\Products~consume_stock,
          lt_reserved         TYPE HASHED TABLE OF ty_reserved WITH UNIQUE KEY sales_order_id sales_order_item_id.

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine
        FIELDS ( SalesOrderId SalesOrderItemId AvailabilityStatus RequestedQuantity RequestedDeliveryDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_schedule_lines).

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine BY \_Item
        FIELDS ( SalesOrderId SalesOrderItemId ProductId RequestedQuantity ConfirmedQuantity SalesUnit DeliveryStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      LINK DATA(lt_links).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_line>).

      " Never consume stock for an uncommitted draft.
      IF <lfs_line>-%is_draft = if_abap_behv=>mk-on.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        APPEND VALUE #( %tky = <lfs_line>-%tky
                        %msg = new_message_with_text(
                          text = 'Confirm Delivery is only allowed for active Sales Orders.'
                          severity = if_abap_behv_message=>severity-error ) ) TO reported-ScheduleLine.
        CONTINUE.
      ENDIF.

      IF <lfs_line>-AvailabilityStatus <> lc_status-available.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        APPEND VALUE #( %tky = <lfs_line>-%tky
                        %msg = NEW zcm_team2_so(
  im_textid   = zcm_team2_so=>c_schedule_not_available
  im_severity = if_abap_behv_message=>severity-error
)
                        %element-AvailabilityStatus = if_abap_behv=>mk-on ) TO reported-ScheduleLine.
        CONTINUE.
      ENDIF.

      READ TABLE lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
        WITH KEY source-%tky = <lfs_line>-%tky.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        CONTINUE.
      ENDIF.
      READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>)
        WITH KEY %tky = <lfs_link>-target-%tky.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        CONTINUE.
      ENDIF.

      " A completed Item is immutable even when a stale button remains visible.
      IF <lfs_item>-DeliveryStatus = 'FULLY DELIVERED'
         OR <lfs_item>-ConfirmedQuantity >= <lfs_item>-RequestedQuantity
         OR <lfs_line>-RequestedQuantity <= 0
         OR <lfs_line>-RequestedDeliveryDate IS INITIAL.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        APPEND VALUE #( %tky = <lfs_line>-%tky
                        %msg = new_message_with_text(
                          text = 'Item is complete, or requested delivery data is invalid.'
                          severity = if_abap_behv_message=>severity-error ) ) TO reported-ScheduleLine.
        CONTINUE.
      ENDIF.

      UNASSIGN <lfs_reserved>.
      READ TABLE lt_reserved ASSIGNING <lfs_reserved>
        WITH TABLE KEY sales_order_id = <lfs_item>-SalesOrderId
                       sales_order_item_id = <lfs_item>-SalesOrderItemId.
      DATA(lv_batch_qty) = CONV decfloat34( 0 ).
      IF sy-subrc = 0.
        lv_batch_qty = <lfs_reserved>-quantity.
      ENDIF.

      " Batch guard: multiple ScheduleLines in one request may not exceed Item quantity.
      IF CONV decfloat34( <lfs_item>-ConfirmedQuantity ) + lv_batch_qty
         + CONV decfloat34( <lfs_line>-RequestedQuantity )
         > CONV decfloat34( <lfs_item>-RequestedQuantity ).
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        APPEND VALUE #( %tky = <lfs_line>-%tky
                        %msg = new_message_with_text(
                          text = 'Confirmed quantity would exceed the Item Requested Quantity.'
                          severity = if_abap_behv_message=>severity-error )
                        %element-RequestedQuantity = if_abap_behv=>mk-on ) TO reported-ScheduleLine.
        CONTINUE.
      ENDIF.

      " Check current Product stock again; the displayed availability may be stale.
      DATA(lv_available) = zcl_team2_util=>is_available(
        iv_product_id = <lfs_item>-ProductId
        iv_sales_unit = <lfs_item>-SalesUnit
        iv_quantity   = CONV decfloat34( <lfs_line>-RequestedQuantity ) ).
      IF lv_available = abap_false.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        APPEND VALUE #( %tky = <lfs_line>-%tky
                        %msg = new_message_with_text(
                          text = 'Insufficient stock to confirm this Schedule Line.'
                          severity = if_abap_behv_message=>severity-error )
                        %element-AvailabilityStatus = if_abap_behv=>mk-on ) TO reported-ScheduleLine.
        CONTINUE.
      ENDIF.

      " Product BO must also check stock atomically during consume_stock.
      CLEAR lt_stock_requests.
      APPEND VALUE #( ProductId = <lfs_item>-ProductId
                      %param = VALUE #( QuantityToConsume = <lfs_line>-RequestedQuantity
                                        SalesUnit = <lfs_item>-SalesUnit ) ) TO lt_stock_requests.
      MODIFY ENTITIES OF zir_team2_products
        ENTITY Products EXECUTE consume_stock
        FROM lt_stock_requests
        FAILED DATA(ls_failed_stock)
        REPORTED DATA(ls_reported_stock).

      IF ls_failed_stock IS NOT INITIAL.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        LOOP AT ls_reported_stock-Products ASSIGNING FIELD-SYMBOL(<lfs_stock_msg>) WHERE %msg IS BOUND.
          APPEND VALUE #( %tky = <lfs_line>-%tky
                          %msg = <lfs_stock_msg>-%msg
                          %element-AvailabilityStatus = if_abap_behv=>mk-on ) TO reported-ScheduleLine.
        ENDLOOP.
        IF ls_reported_stock-Products IS INITIAL.
          APPEND VALUE #( %tky = <lfs_line>-%tky
                          %msg = new_message_with_text(
                            text = 'Product stock consumption failed.'
                            severity = if_abap_behv_message=>severity-error ) ) TO reported-ScheduleLine.
        ENDIF.
        CONTINUE.
      ENDIF.

      IF <lfs_reserved> IS ASSIGNED.
        <lfs_reserved>-quantity += CONV decfloat34( <lfs_line>-RequestedQuantity ).
      ELSE.
        INSERT VALUE #( sales_order_id = <lfs_item>-SalesOrderId
                        sales_order_item_id = <lfs_item>-SalesOrderItemId
                        quantity = CONV decfloat34( <lfs_line>-RequestedQuantity ) ) INTO TABLE lt_reserved.
      ENDIF.

      " Persist the actual delivery confirmation, not the planned date.
      APPEND VALUE #( %tky                  = <lfs_line>-%tky
                      AvailabilityStatus    = lc_status-confirmed
                      ConfirmedQuantity     = <lfs_line>-RequestedQuantity
                      ConfirmedDeliveryDate = lv_today ) TO lt_schedule_updates.

    ENDLOOP.

    IF lt_schedule_updates IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine
        UPDATE FIELDS ( AvailabilityStatus ConfirmedQuantity ConfirmedDeliveryDate )
        WITH lt_schedule_updates
      FAILED DATA(ls_failed_update)
      REPORTED DATA(ls_reported_update).

    APPEND LINES OF ls_failed_update-ScheduleLine TO failed-ScheduleLine.
    APPEND LINES OF ls_reported_update-ScheduleLine TO reported-ScheduleLine.

    " Recalculate Items after the confirmation data is already in the RAP buffer.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
        FIELDS ( SalesOrderId SalesOrderItemId )
        WITH VALUE #( FOR ls_update IN lt_schedule_updates
                      ( SalesOrderId     = ls_update-SalesOrderId
                        SalesOrderItemId = ls_update-SalesOrderItemId
                        %is_draft        = ls_update-%is_draft ) )
      RESULT DATA(lt_affected_items).

    SORT lt_affected_items BY %tky.
    DELETE ADJACENT DUPLICATES FROM lt_affected_items COMPARING %tky.
    IF lt_affected_items IS NOT INITIAL.
      MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
        ENTITY Item EXECUTE recalc_item_delivery_status
        FROM VALUE #( FOR ls_item IN lt_affected_items ( %tky = ls_item-%tky ) )
        FAILED DATA(ls_failed_recalc)
        REPORTED DATA(ls_reported_recalc).
      IF ls_failed_recalc IS NOT INITIAL.
        " An aggregate failure must not lead to a successful-looking confirmation.
        LOOP AT lt_schedule_updates ASSIGNING FIELD-SYMBOL(<lfs_update>).
          APPEND VALUE #( %tky = <lfs_update>-%tky ) TO failed-ScheduleLine.
          APPEND VALUE #( %tky = <lfs_update>-%tky
                          %msg = new_message_with_text(
                            text = 'Could not recalculate the Item and Sales Order statuses.'
                            severity = if_abap_behv_message=>severity-error ) ) TO reported-ScheduleLine.
        ENDLOOP.
      ENDIF.
    ENDIF.

    " Return only successfully confirmed Schedule Lines.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine ALL FIELDS
      WITH VALUE #( FOR ls_update IN lt_schedule_updates ( %tky = ls_update-%tky ) )
      RESULT DATA(lt_updated_lines).

    LOOP AT lt_updated_lines INTO DATA(ls_updated_line).
      IF line_exists( failed-ScheduleLine[ %tky = ls_updated_line-%tky ] ).
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = ls_updated_line-%tky
                      %param = ls_updated_line ) TO result.
    ENDLOOP.
  ENDMETHOD.


**********************************************************************
* Determination: Set Schedule Line Availability Status
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 10/10/2026
* Content explanation:
*   Check Product stock availability for each Schedule Line.
*   Set availability status based on the parent Sales Order Item.
*   Keep confirmed Schedule Lines unchanged.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Schedule Lines that trigger the determination
*---------------------------------------------------------------------*
  METHOD setAvailability.
     DATA lt_schedule_updates TYPE TABLE FOR UPDATE zir_team2_so_hd\\ScheduleLine.

    " Read affected Schedule Lines in the transactional buffer.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine
        FIELDS ( RequestedQuantity AvailabilityStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_schedule_lines).

    " Read Product and Sales Unit from the related Sales Order Items.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine BY \_Item
        FIELDS ( ProductId SalesUnit RequestedQuantity ConfirmedQuantity DeliveryStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      LINK DATA(lt_links).

    LOOP AT lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_schedule_line>).

      " Preserve a confirmed delivery.
      IF <lfs_schedule_line>-AvailabilityStatus = lc_status-confirmed.
        CONTINUE.
      ENDIF.

      READ TABLE lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
        WITH KEY source-%tky = <lfs_schedule_line>-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>)
        WITH KEY %tky = <lfs_link>-target-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Reject stock checks for invalid quantities or already completed Items.
      DATA(lv_is_available) = abap_false.
      IF <lfs_schedule_line>-RequestedQuantity > 0
         AND <lfs_item>-DeliveryStatus <> 'FULLY DELIVERED'
         AND <lfs_item>-ConfirmedQuantity + <lfs_schedule_line>-RequestedQuantity <= <lfs_item>-RequestedQuantity.
        lv_is_available = zcl_team2_util=>is_available(
          iv_product_id = <lfs_item>-ProductId
          iv_sales_unit = <lfs_item>-SalesUnit
          iv_quantity   = CONV decfloat34( <lfs_schedule_line>-RequestedQuantity ) ).
      ENDIF.

      DATA(lv_new_status) = COND zteam2_sched_ln-availability_status(
        WHEN lv_is_available = abap_true THEN lc_status-available
        ELSE lc_status-unavailable ).

      IF <lfs_schedule_line>-AvailabilityStatus = lv_new_status.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky               = <lfs_schedule_line>-%tky
                      AvailabilityStatus = lv_new_status
                    ) TO lt_schedule_updates.
    ENDLOOP.

    IF lt_schedule_updates IS INITIAL.
      RETURN.
    ENDIF.

    " Update only the persistent status field.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine
        UPDATE FIELDS ( AvailabilityStatus )
        WITH lt_schedule_updates
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
  ENDMETHOD.


**********************************************************************
* Determination: Set Sales Unit from Parent Item
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 11/10/2026
* Content explanation:
*   Set the Sales Unit of each Schedule Line from its parent Item.
*   Read the parent Sales Order Item through the _Item association.
*   Copy the parent Item Sales Unit to the Schedule Line.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Schedule Lines that trigger the determination
*---------------------------------------------------------------------*
  METHOD set_sales_unit.
 DATA lt_schedule_updates TYPE TABLE FOR UPDATE zir_team2_so_hd\\ScheduleLine.

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine FIELDS ( SalesUnit )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_schedule_lines).

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine BY \_Item
        FIELDS ( SalesUnit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      LINK DATA(lt_links).

    LOOP AT lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_schedule_line>).
      READ TABLE lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
        WITH KEY source-%tky = <lfs_schedule_line>-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>)
        WITH KEY %tky = <lfs_link>-target-%tky.
      IF sy-subrc <> 0 OR <lfs_schedule_line>-SalesUnit = <lfs_item>-SalesUnit.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = <lfs_schedule_line>-%tky
                      SalesUnit = <lfs_item>-SalesUnit ) TO lt_schedule_updates.
    ENDLOOP.

    IF lt_schedule_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
        ENTITY ScheduleLine UPDATE FIELDS ( SalesUnit )
        WITH lt_schedule_updates
        FAILED DATA(ls_failed)
        REPORTED DATA(ls_reported).
    ENDIF.
  ENDMETHOD.
  METHOD check_confirmed_quantity.
    " Validate the server-managed confirmation values before save.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine
        FIELDS ( AvailabilityStatus RequestedQuantity ConfirmedQuantity ConfirmedDeliveryDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_schedule_lines).

    LOOP AT lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_line>).
      APPEND VALUE #( %tky = <lfs_line>-%tky
                      %state_area = 'CONFIRMED_QUANTITY' ) TO reported-ScheduleLine.

      DATA(lv_invalid) = abap_false.
      IF <lfs_line>-ConfirmedQuantity < 0
         OR <lfs_line>-ConfirmedQuantity > <lfs_line>-RequestedQuantity.
        lv_invalid = abap_true.
      ENDIF.

      IF <lfs_line>-AvailabilityStatus = lc_status-confirmed.
        IF <lfs_line>-ConfirmedQuantity <> <lfs_line>-RequestedQuantity
           OR <lfs_line>-ConfirmedDeliveryDate IS INITIAL.
          lv_invalid = abap_true.
        ENDIF.
      ELSEIF <lfs_line>-ConfirmedQuantity <> 0
          OR <lfs_line>-ConfirmedDeliveryDate IS NOT INITIAL.
        lv_invalid = abap_true.
      ENDIF.

      IF lv_invalid = abap_true.
        APPEND VALUE #( %tky = <lfs_line>-%tky ) TO failed-ScheduleLine.
        APPEND VALUE #( %tky = <lfs_line>-%tky
                        %state_area = 'CONFIRMED_QUANTITY'
                        %msg = new_message_with_text(
                          text     = 'Confirmed Quantity or delivery date is inconsistent with availability status.'
                          severity = if_abap_behv_message=>severity-error )
                        %element-ConfirmedQuantity = if_abap_behv=>mk-on
                      ) TO reported-ScheduleLine.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
*&---------------------------------------------------------------------*
* Validation: Check Requested Quantity of Schedule Lines
*&---------------------------------------------------------------------*
* Created by         : KHANGTP5
* Created date       : 10/10/2026
* Content explanation:
*   Validate the total Requested Quantity of confirmed Schedule Lines.
*   Ensure the total does not exceed the parent Sales Order Item quantity.
*   Clear previous validation messages and report errors with entity paths.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS                  : Schedule Lines requiring validation
* <-- FAILED-SCHEDULELINE   : Schedule Lines that failed validation
* <-- REPORTED-SCHEDULELINE : Validation errors and field messages
*---------------------------------------------------------------------*
  METHOD check_requested_quantity.
    " Read the Schedule Lines that triggered the validation.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine
        FIELDS ( RequestedQuantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_schedule_lines).

    " Read the parent Sales Order Items and association links.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine BY \_Item
        FIELDS ( RequestedQuantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items)
      LINK DATA(lt_links).

    " Read root Header association links.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY ScheduleLine BY \_Header
        FROM CORRESPONDING #( lt_schedule_lines )
      LINK DATA(lt_header_links).

    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>).
      " Find the parent Sales Order Item.
      READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>) WITH KEY %tky = <lfs_link>-target-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      " Find the current Schedule Line.
      READ TABLE lt_schedule_lines ASSIGNING FIELD-SYMBOL(<lfs_schedule_line>) WITH KEY %tky = <lfs_link>-source-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      " Find the corresponding root Header.
      READ TABLE lt_header_links   ASSIGNING FIELD-SYMBOL(<lfs_header_link>)   WITH KEY source-%tky = <lfs_schedule_line>-%tky.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Clear previous state messages.
      APPEND VALUE #(
        %tky        = <lfs_schedule_line>-%tky
        %state_area = lc_state_area-requested_quantity
      ) TO reported-ScheduleLine.

      " Read all Schedule Lines belonging to the same parent Item,
      " including confirmed and unconfirmed Schedule Lines.
      READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
        ENTITY Item BY \_ScheduleLine
          FIELDS ( RequestedQuantity )
          WITH VALUE #( ( %tky = <lfs_item>-%tky ) )
        RESULT DATA(lt_all_schedule_lines).

      " Calculate the total Requested Quantity of all Schedule Lines.
      DATA(lv_total_quantity) = REDUCE decfloat34(
        INIT lv_sum = CONV decfloat34( 0 )
        FOR ls_line IN lt_all_schedule_lines
        NEXT lv_sum = lv_sum + CONV decfloat34( ls_line-RequestedQuantity )
      ).
      " Validate total quantity against the parent Item Requested Quantity.
      IF lv_total_quantity > CONV decfloat34( <lfs_item>-RequestedQuantity ).

        " Reject the invalid Schedule Line.
        APPEND VALUE #(
          %tky = <lfs_schedule_line>-%tky
        ) TO failed-ScheduleLine.


        " Report validation error with the entity path.
        IF <lfs_header_link> IS ASSIGNED.

          APPEND VALUE #(
            %tky        = <lfs_schedule_line>-%tky
            %state_area = lc_state_area-requested_quantity


            %path = VALUE #(
              Header-%tky = <lfs_header_link>-target-%tky
              Item-%tky   = <lfs_item>-%tky
            )
            %msg = NEW zcm_team2_so(
              im_textid   = zcm_team2_so=>c_schedule_quantity_exceeded
              im_severity = if_abap_behv_message=>severity-error
            )
            %element-RequestedQuantity = if_abap_behv=>mk-on

          ) TO reported-ScheduleLine.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD set_delivery_status.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
        FIELDS ( SalesOrderId SalesOrderItemId )
        WITH VALUE #( FOR ls_key IN keys
                      ( SalesOrderId     = ls_key-SalesOrderId
                        SalesOrderItemId = ls_key-SalesOrderItemId
                        %is_draft        = ls_key-%is_draft ) )
      RESULT DATA(lt_items).

    SORT lt_items BY %tky.
    DELETE ADJACENT DUPLICATES FROM lt_items COMPARING %tky.
    IF lt_items IS INITIAL.
      RETURN.
    ENDIF.

    " Delegate all quantity calculations to one shared internal action.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Item
        EXECUTE recalc_item_delivery_status
        FROM VALUE #( FOR ls_item IN lt_items ( %tky = ls_item-%tky ) )
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).
  ENDMETHOD.

ENDCLASS.
