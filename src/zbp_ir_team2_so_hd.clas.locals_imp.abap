CLASS lhc_zir_team2_so_hd DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
*&---------------------------------------------------------------------*
* Constants: Validation State Areas
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_state_area,
        sales_order_date        TYPE string VALUE 'SALES_ORDER_DATE',
        sales_order_type        TYPE string VALUE 'SALES_ORDER_TYPE',
        sold_to_party           TYPE string VALUE 'SOLD_TO_PARTY',
        sold_to_party_required  TYPE string VALUE 'SOLD_TO_PARTY_REQUIRED',

        ship_to_party           TYPE string VALUE 'SHIP_TO_PARTY',
        requested_delivery_date TYPE string VALUE 'REQUESTED_DELIVERY_DATE',
        sales_organization      TYPE string VALUE 'SALES_ORGANIZATION',
        distribution_channel    TYPE string VALUE 'DISTRIBUTION_CHANNEL',
        division                TYPE string VALUE 'DIVISION',
        product                 TYPE string VALUE 'PRODUCT',
      END OF lc_state_area.
*&---------------------------------------------------------------------*
* Constants: Sales Order Overall Status
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_overall_status,
        open      TYPE string VALUE 'OPEN',
        partial   TYPE string VALUE 'PARTIAL',
        overdue   TYPE string VALUE 'OVERDUE',
        completed TYPE string VALUE 'COMPLETED',
      END OF lc_overall_status.

*&---------------------------------------------------------------------*
* Constants: Sales Order Item Delivery Status
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_delivery_status,
        not_delivered TYPE string VALUE 'NOT DELIVERED',
        partial       TYPE string VALUE 'PARTIALLY DELIVERED',
        partial_alt   TYPE string VALUE 'PARTIAL DELIVERED',
        fully         TYPE string VALUE 'FULLY DELIVERED',
      END OF lc_delivery_status.

*&---------------------------------------------------------------------*
* Constants: Number Range Configuration
*&---------------------------------------------------------------------*
    CONSTANTS:
      lc_number_range_object   TYPE string VALUE 'ZTEAM2_SO',
      lc_number_range_interval TYPE c LENGTH 2 VALUE '01',
      lc_item_number_step      TYPE i VALUE 10,
      lc_item_number_width     TYPE i VALUE 6.

*&---------------------------------------------------------------------*
* Determinations
*&---------------------------------------------------------------------*
    METHODS set_initial_status
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~set_initial_status.
*&---------------------------------------------------------------------*
* Authorization
*&---------------------------------------------------------------------*
    METHODS get_global_authorizations
      FOR GLOBAL AUTHORIZATION
      IMPORTING
      REQUEST requested_authorizations FOR Header
      RESULT result.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      keys
      REQUEST requested_authorizations FOR Header
      RESULT result.

*&---------------------------------------------------------------------*
* Dynamic Feature Control
*&---------------------------------------------------------------------*
    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING keys
                  REQUEST requested_features FOR Header
      RESULT    result.
*&---------------------------------------------------------------------*
* Early Numbering
*&---------------------------------------------------------------------*
    METHODS earlynumbering_create
      FOR NUMBERING
      IMPORTING entities FOR CREATE Header.

    METHODS earlynumbering_cba_item
      FOR NUMBERING
      IMPORTING entities FOR CREATE Header\_Item.

*&---------------------------------------------------------------------*
* Validations
*&---------------------------------------------------------------------*
    METHODS check_sold_to_party
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~check_sold_to_party.

    METHODS check_requested_delivery_date
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~check_requested_delivery_date.

    METHODS empty_on_save FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~empty_on_save.

*&---------------------------------------------------------------------*
* Internal Actions
*&---------------------------------------------------------------------*
    METHODS recalc_header_net_amount
      FOR MODIFY
      IMPORTING keys FOR ACTION Header~recalc_header_net_amount.
    METHODS recalc_overall_status FOR MODIFY
       keys FOR ACTION Header~recalc_overall_status.
    METHODS check_sales_area FOR VALIDATE ON SAVE
       keys FOR Header~check_sales_area.

    METHODS check_ship_to_party FOR VALIDATE ON SAVE
       keys FOR Header~check_ship_to_party.
ENDCLASS.

CLASS lhc_zir_team2_so_hd IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
  ENDMETHOD.
*&---------------------------------------------------------------------*
* Early Numbering: Generate Sales Order IDs
*&---------------------------------------------------------------------*
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Generate unique Sales Order IDs during RAP Early Numbering.
*   using the configured Number Range Object ZTEAM2_SO.
*   Handle numbering exceptions and Number Range status.
*---------------------------------------------------------------------*
* Parameters:
* --> ENTITIES       : Sales Order instances to be created
* <-- MAPPED-HEADER  : Sales Orders with assigned IDs
* <-- FAILED-HEADER  : Sales Orders that failed numbering
* <-- REPORTED-HEADER: Error and warning messages
*---------------------------------------------------------------------*
  METHOD earlynumbering_create.
    DATA:
      ls_entity         TYPE STRUCTURE FOR CREATE zir_team2_so_hd,
      lv_sales_order_id TYPE zteam2_so_hd-sales_order_id.
    " Handle instances that already have a Sales Order ID.
    LOOP AT entities INTO ls_entity
         WHERE SalesOrderId IS NOT INITIAL.

      APPEND VALUE #(
        %cid         = ls_entity-%cid
        SalesOrderId = ls_entity-SalesOrderId
        %is_draft    = ls_entity-%is_draft
      ) TO mapped-Header.

    ENDLOOP.
    " Keep only instances that require numbering.
    DATA(lt_entities_wo_id) = entities.
    DELETE lt_entities_wo_id  WHERE SalesOrderId IS NOT INITIAL.

    IF lt_entities_wo_id IS INITIAL.
      RETURN.
    ENDIF.

    " Request numbers from reusable numbering utility.
    TRY.
        zcl_team2_numbering_utility=>get_number_range(
          EXPORTING
            iv_object   = 'ZTEAM2_SO'
            iv_interval = '01'
            iv_quantity = CONV #(
                            lines( lt_entities_wo_id )  )
          IMPORTING
            ev_number       = DATA(lv_nr_key)
            ev_return_code  = DATA(lv_nr_return_code)
            ev_returned_qty = DATA(lv_nr_returned_qty)
        ).
      CATCH cx_nr_object_not_found INTO DATA(lx_object_not_found).

        LOOP AT lt_entities_wo_id INTO ls_entity.
          APPEND VALUE #(
            %cid      = ls_entity-%cid
            %key      = ls_entity-%key
            %is_draft = ls_entity-%is_draft
            %msg      = lx_object_not_found
          ) TO reported-Header.
          APPEND VALUE #(
            %cid      = ls_entity-%cid
            %key      = ls_entity-%key
            %is_draft = ls_entity-%is_draft
          ) TO failed-Header.
        ENDLOOP.
        RETURN.
      CATCH cx_number_ranges INTO DATA(lx_number_ranges).

        LOOP AT lt_entities_wo_id INTO ls_entity.
          APPEND VALUE #(
            %cid      = ls_entity-%cid
            %key      = ls_entity-%key
            %is_draft = ls_entity-%is_draft
            %msg      = lx_number_ranges
          ) TO reported-Header.
          APPEND VALUE #(
            %cid      = ls_entity-%cid
            %key      = ls_entity-%key
            %is_draft = ls_entity-%is_draft
          ) TO failed-Header.
        ENDLOOP.
        RETURN.

    ENDTRY.
    " Check Number Range status.
    CASE lv_nr_return_code.
      WHEN '1'.
        " Number Range is in critical range.
        LOOP AT lt_entities_wo_id INTO ls_entity.
          APPEND VALUE #(
            %cid      = ls_entity-%cid
            %key      = ls_entity-%key
            %is_draft = ls_entity-%is_draft
            %msg      = new_message_with_text(
                           severity = if_abap_behv_message=>severity-warning
                           text     = 'Sales Order number range is nearly exhausted.'
                         )
          ) TO reported-Header.
        ENDLOOP.
      WHEN '2' OR '3'.
        LOOP AT lt_entities_wo_id INTO ls_entity.
          APPEND VALUE #(
            %cid      = ls_entity-%cid
            %key      = ls_entity-%key
            %is_draft = ls_entity-%is_draft
            %msg      = new_message_with_text(
                           severity = if_abap_behv_message=>severity-error
                           text     = 'Not enough Sales Order numbers are available.'
                         )
          ) TO reported-Header.

          APPEND VALUE #(
            %cid        = ls_entity-%cid
            %key        = ls_entity-%key
            %is_draft   = ls_entity-%is_draft
            %fail-cause = if_abap_behv=>cause-conflict
          ) TO failed-Header.
        ENDLOOP.
        RETURN.
    ENDCASE.
    " Ensure all requested numbers were returned.
    ASSERT lv_nr_returned_qty = lines( lt_entities_wo_id ).

    " NUMBER_GET returns the highest number of the reserved block.
    lv_sales_order_id =  lv_nr_key - lv_nr_returned_qty.

    " Map every CREATE instance to its generated Sales Order ID.
    LOOP AT lt_entities_wo_id INTO ls_entity.

      lv_sales_order_id += 1.

      APPEND VALUE #(
        %cid         = ls_entity-%cid
        SalesOrderId = lv_sales_order_id
        %is_draft    = ls_entity-%is_draft
      ) TO mapped-Header.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Early Numbering: Generate Sales Order Item IDs
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Generate unique Sales Order Item IDs during RAP Early Numbering.
*   Determine the highest existing Item ID for each Sales Order.
*   Assign sequential Item IDs with an increment of 10.
*   Preserve Item IDs already provided in the CREATE request.
*---------------------------------------------------------------------*
* Parameters:
* --> ENTITIES       : Sales Order Items to be created by association
* <-- MAPPED-ITEM    : Sales Order Items with assigned Item IDs
*---------------------------------------------------------------------*
  METHOD earlynumbering_cba_item.
    DATA: lv_max_item_id  TYPE zteam2_so_it-sales_order_item_id,
          lv_next_item_id TYPE zteam2_so_it-sales_order_item_id.

    " Read existing Items of the affected Sales Orders
    " from the RAP transactional buffer.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header BY \_Item
      FROM CORRESPONDING #( entities )
      LINK DATA(lt_item_links).

    " Process each Sales Order separately.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<ls_entity>)
         GROUP BY ( SalesOrderId = <ls_entity>-SalesOrderId
                    IsDraft      = <ls_entity>-%is_draft )
         ASSIGNING FIELD-SYMBOL(<ls_group>).

      " Get the highest Item ID already existing
      " for the current Sales Order.
      lv_max_item_id = REDUCE #(
        INIT lv_max TYPE zteam2_so_it-sales_order_item_id

        FOR ls_link IN lt_item_links
        WHERE ( source-SalesOrderId = <ls_group>-SalesOrderId
                AND source-%is_draft = <ls_group>-IsDraft )

        NEXT lv_max = COND #(
          WHEN ls_link-target-SalesOrderItemId > lv_max
          THEN ls_link-target-SalesOrderItemId
          ELSE lv_max
        )
      ).

      " Also consider Item IDs already supplied
      " in the current CREATE request.
      lv_max_item_id = REDUCE #(
        INIT lv_max = lv_max_item_id

        FOR ls_cba IN entities
        WHERE ( SalesOrderId = <ls_group>-SalesOrderId
                AND %is_draft = <ls_group>-IsDraft )
        FOR ls_target IN ls_cba-%target

        NEXT lv_max = COND #(
          WHEN ls_target-SalesOrderItemId > lv_max
          THEN ls_target-SalesOrderItemId
          ELSE lv_max
        )
      ).

      " Number all Items belonging to this Sales Order.
      LOOP AT GROUP <ls_group> ASSIGNING FIELD-SYMBOL(<ls_parent>).
        LOOP AT <ls_parent>-%target ASSIGNING FIELD-SYMBOL(<ls_item>).

          " Keep an Item ID if one already exists.
          IF <ls_item>-SalesOrderItemId IS NOT INITIAL.

            APPEND VALUE #( %cid             = <ls_item>-%cid
                            %is_draft        = <ls_item>-%is_draft
                            SalesOrderId     = <ls_parent>-SalesOrderId
                            SalesOrderItemId = <ls_item>-SalesOrderItemId
                          ) TO mapped-Item.
            CONTINUE.
          ENDIF.

          " Generate next Item ID: 000010, 000020, ...
          lv_next_item_id = CONV #(
            zcl_team2_numbering_utility=>get_next_sequence(
              iv_current = CONV int8( lv_max_item_id )
              iv_step    = 10
              iv_width   = 6
            )
          ).

          lv_max_item_id = lv_next_item_id.

          " Map generated key back to RAP.
          APPEND VALUE #( %cid             = <ls_item>-%cid
                          %is_draft        = <ls_item>-%is_draft
                          SalesOrderId     = <ls_parent>-SalesOrderId
                          SalesOrderItemId = lv_next_item_id
                        ) TO mapped-Item.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check if Sold-to Party ID exists and is active
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Validate the Sold-to Party ID of Sales Order Header.
*   Check whether the Customer exists in the Customer Business
*   Object and verify that the Customer is active.
*   Reject invalid Sales Orders and report validation errors.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Header instances to be validated
* <-- FAILED-HEADER  : Sales Orders that failed validation
* <-- REPORTED-HEADER: Validation error messages
*---------------------------------------------------------------------*
  METHOD check_sold_to_party.
    DATA lt_customers TYPE SORTED TABLE OF zir_team2_customer WITH UNIQUE KEY CustomerId.

    " Read relevant instance data
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        ALL FIELDS WITH
        CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Optimization of BO read: extract distinct non-initial Customer IDs
    lt_customers = CORRESPONDING #(
      lt_headers
      DISCARDING DUPLICATES
      MAPPING CustomerId = SoldToPartyId
      EXCEPT *
    ).

    DELETE lt_customers WHERE CustomerId IS INITIAL.

    IF lt_customers IS NOT INITIAL.

      " Read Customer Business Object
      READ ENTITIES OF zir_team2_customer
        ENTITY Customer
          FIELDS ( CustomerId Is_Active )
          WITH CORRESPONDING #( lt_customers )
        RESULT DATA(lt_customer_db).

    ENDIF.

    " Validate each Sales Order instance
    LOOP AT lt_headers INTO DATA(ls_header).

      " Clear previous state messages
      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = lc_state_area-sold_to_party
      ) TO reported-header.

      " Find the referenced Customer
      READ TABLE lt_customer_db
        WITH TABLE KEY entity
        COMPONENTS CustomerId = ls_header-SoldToPartyId
        INTO DATA(ls_customer).

      IF sy-subrc <> 0.
        " Reject input data
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-header.

        " Raise message
        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = lc_state_area-sold_to_party

          %msg = NEW zcm_team2_so(
            im_textid           = zcm_team2_so=>c_customer_not_exist
            im_severity         = if_abap_behv_message=>severity-error
            im_sold_to_party_id = ls_header-SoldToPartyId

          )
          %element-SoldToPartyId = if_abap_behv=>mk-on

        ) TO reported-header.
      ELSEIF ls_customer-Is_Active = abap_false.

        " Reject input data
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-header.

        " Raise message
        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = lc_state_area-sold_to_party

          %msg = NEW zcm_team2_so(
            im_textid           = zcm_team2_so=>c_customer_inactive
            im_severity         = if_abap_behv_message=>severity-error
            im_sold_to_party_id = ls_header-SoldToPartyId
          )
          %element-SoldToPartyId = if_abap_behv=>mk-on
        ) TO reported-header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check if Requested Delivery Date is valid
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Validate the Requested Delivery Date of Sales Order Header.
*   Ensure that the Requested Delivery Date is not earlier
*   than the Sales Order Date.
*   Reject invalid Sales Orders and report validation errors.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Header instances to be validated
* <-- FAILED-HEADER  : Sales Orders that failed validation
* <-- REPORTED-HEADER: Validation error messages
*---------------------------------------------------------------------*
  METHOD check_requested_delivery_date.

    " Read relevant instance data
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        FIELDS ( SalesOrderDate RequestedDeliveryDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Check if Requested Delivery Date is before Sales Order Date
    LOOP AT lt_headers INTO DATA(ls_header).
      " Clear previous state messages
      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = lc_state_area-requested_delivery_date
      ) TO reported-header.

      IF ls_header-RequestedDeliveryDate IS NOT INITIAL
         AND ls_header-SalesOrderDate IS NOT INITIAL
         AND ls_header-RequestedDeliveryDate < ls_header-SalesOrderDate.

        " Reject input data
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-header.

        " Raise message
        APPEND VALUE #(
          %tky = ls_header-%tky
          %state_area = lc_state_area-requested_delivery_date
          %msg = NEW zcm_team2_so(
            im_textid   = zcm_team2_so=>c_invalid_delivery_date
            im_severity = if_abap_behv_message=>severity-error
          )
          %element-RequestedDeliveryDate = if_abap_behv=>mk-on
        ) TO reported-header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
*&---------------------------------------------------------------------*
* Internal Action: Recalculate Sales Order Header Net Amount
*&---------------------------------------------------------------------*
* Created by         : KHANGTP5
* Changed date       : 14/10/2026
* Content explanation:
*   Recalculate Header NetAmount from related Items.
*   Derive Header CurrencyCode from Item CurrencyCode.
*   Prevent aggregation of different currencies.
*   Avoid unnecessary updates to Header and its ETag.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS : Sales Order Headers requiring recalculation
*---------------------------------------------------------------------*
METHOD recalc_header_net_amount.

  DATA:
    lt_headers_update    TYPE TABLE FOR UPDATE zir_team2_so_hd\\Header,
    lv_header_net_amount TYPE zteam2_so_hd-net_amount,
    lv_currency_code     TYPE zteam2_so_hd-currency_code,
    lv_currency_invalid  TYPE abap_bool.

  " Read relevant Sales Order Headers from the transactional buffer.
  " Begin change: KHANGTP5 - 14/10/2026
  " Old: FIELDS ( NetAmount )
  " New: Read CurrencyCode together with NetAmount.
  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Header
      FIELDS ( NetAmount CurrencyCode )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers).

  IF lt_headers IS INITIAL.
    RETURN.
  ENDIF.

  " Read all Items belonging to the affected Sales Order Headers.
  " Old: FIELDS ( NetAmount )
  " New: Also read Item CurrencyCode.
  READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Header BY \_Item
      FIELDS ( NetAmount CurrencyCode )
      WITH CORRESPONDING #( lt_headers )
    LINK DATA(lt_item_links)
    RESULT DATA(lt_items).

  " Recalculate Net Amount for each Sales Order Header.
  LOOP AT lt_headers INTO DATA(ls_header).

    CLEAR:
      lv_header_net_amount,
      lv_currency_code,
      lv_currency_invalid.

    " Preserve the existing Header currency if one is maintained.
    lv_currency_code = ls_header-CurrencyCode.

    " Process Items belonging to the current Sales Order.
    LOOP AT lt_item_links INTO DATA(ls_link)
      WHERE source-%tky = ls_header-%tky.

      " Read the associated Sales Order Item.
      READ TABLE lt_items INTO DATA(ls_item)
        WITH TABLE KEY id
        COMPONENTS %tky = ls_link-target-%tky.

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " Add Item Net Amount to the Header total.
      " Keep SAP internal currency representation unchanged.
      lv_header_net_amount += ls_item-NetAmount.

      " Derive the Header currency from the first valid Item currency.
      IF ls_item-CurrencyCode IS NOT INITIAL.

        IF lv_currency_code IS INITIAL.

          lv_currency_code = ls_item-CurrencyCode.

        ELSEIF lv_currency_code <> ls_item-CurrencyCode.

          " Do not add amounts expressed in different currencies.
          lv_currency_invalid = abap_true.

        ENDIF.

      ELSEIF ls_item-NetAmount <> 0.

        " A nonzero monetary amount must have a currency.
        lv_currency_invalid = abap_true.

      ENDIF.

    ENDLOOP.

    " Reject inconsistent currency assignments.
    IF lv_currency_invalid = abap_true.

      APPEND VALUE #(
        %tky = ls_header-%tky
      ) TO failed-Header.

      APPEND VALUE #(
        %tky = ls_header-%tky
        %msg = new_message_with_text(
          text     = 'Sales Order Items must use the same valid currency.'
          severity = if_abap_behv_message=>severity-error
        )
        %element-CurrencyCode = if_abap_behv=>mk-on
      ) TO reported-Header.

      CONTINUE.

    ENDIF.

    " Skip updating when both amount and currency are unchanged.
    IF ls_header-NetAmount = lv_header_net_amount
       AND ls_header-CurrencyCode = lv_currency_code.

      CONTINUE.

    ENDIF.

    " Prepare Header data with the calculated amount and currency.
    APPEND VALUE #(
      %tky         = ls_header-%tky
      NetAmount    = lv_header_net_amount
      CurrencyCode = lv_currency_code
    ) TO lt_headers_update.

  ENDLOOP.

  IF lt_headers_update IS INITIAL.
    RETURN.
  ENDIF.

  " Update Header NetAmount and CurrencyCode in the RAP buffer.
  MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
    ENTITY Header
      UPDATE FIELDS ( NetAmount CurrencyCode )
      WITH lt_headers_update
    FAILED DATA(ls_failed)
    REPORTED DATA(ls_reported).

  " Forward failed updates to the RAP response.
  LOOP AT ls_failed-Header INTO DATA(ls_failed_header).
    APPEND CORRESPONDING #( ls_failed_header ) TO failed-Header.
  ENDLOOP.

  " Forward generated messages.
  LOOP AT ls_reported-Header INTO DATA(ls_reported_header).
    APPEND CORRESPONDING #( ls_reported_header ) TO reported-Header.
  ENDLOOP.
  " End change: KHANGTP5 - 14/10/2026

ENDMETHOD.
**********************************************************************
* Instance Authorization: Check Sales Order Update Authorization
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Determine update authorization for each Sales Order Header.
*   Allow Managers to update all Sales Orders.
*   Allow regular users to update only Sales Orders they created.
*   Deny update authorization for all other users.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Header instances to be checked
* --> REQUESTED_AUTHORIZATIONS : Requested authorization operations
* <-- RESULT         : Authorization result for each Sales Order
*---------------------------------------------------------------------*
  METHOD get_instance_authorizations.

    DATA(lv_user_name) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_is_manager) = zcl_team2_util=>is_manager( ).

    " Read Sales Orders requested for authorization.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( CreatedBy )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      " Default: Unauthorized.
      DATA(lv_is_authorized) = if_abap_behv=>auth-unauthorized.

      " Manager can update all Sales Orders.
      IF lv_is_manager = abap_true.
        lv_is_authorized = if_abap_behv=>auth-allowed.
      ELSEIF ls_header-CreatedBy = lv_user_name.

        " Owner can update their own Sales Order.
        lv_is_authorized = if_abap_behv=>auth-allowed.
      ENDIF.
      APPEND VALUE #( %tky    = ls_header-%tky
                      %update = lv_is_authorized
                    ) TO result.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check Required Sales Order Fields
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Validate required fields of the Sales Order Header before saving.
*   Check Sales Order Date, Sales Order Type, and Sold-to Party.
*   Reject the Sales Order and report an error for each missing field.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers to be validated
* <-- FAILED-HEADER  : Sales Orders that fail required field validation
* <-- REPORTED-HEADER: Validation messages and highlighted fields
*---------------------------------------------------------------------*
  METHOD empty_on_save.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        FIELDS ( SalesOrderDate SalesOrderType SoldToPartyId
                 SalesOrganization DistributionChannel Division )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      DATA(lv_has_error) = abap_false.

      " Clear previous state messages.
      APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = lc_state_area-sales_order_date
        ) TO reported-header.

      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = lc_state_area-sales_order_type
      ) TO reported-header.

      APPEND VALUE #(
        %tky        = ls_header-%tky
%state_area = lc_state_area-sold_to_party_required
      ) TO reported-header.

      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = lc_state_area-sales_organization
      ) TO reported-header.

      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = lc_state_area-distribution_channel
      ) TO reported-header.

      APPEND VALUE #(
        %tky        = ls_header-%tky
        %state_area = lc_state_area-division
      ) TO reported-header.

      " Validate Sales Order Date
      IF ls_header-SalesOrderDate IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = lc_state_area-sales_order_date
          %msg        = NEW zcm_team2_so(
            im_textid     = zcm_team2_so=>c_missing_required_fields
            im_severity   = if_abap_behv_message=>severity-error
            im_field_name = 'Sales Order Date'
          )
          %element-SalesOrderDate = if_abap_behv=>mk-on
        ) TO reported-header.

      ENDIF.

      " Validate Sales Order Type
      IF ls_header-SalesOrderType IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = lc_state_area-sales_order_type
          %msg        = NEW zcm_team2_so(
            im_textid     = zcm_team2_so=>c_missing_required_fields
            im_severity   = if_abap_behv_message=>severity-error
            im_field_name = 'Sales Order Type'
          )
          %element-SalesOrderType = if_abap_behv=>mk-on
        ) TO reported-header.

      ENDIF.

      " Validate Sold-to Party
      IF ls_header-SoldToPartyId IS INITIAL.
        lv_has_error = abap_true.
        APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = lc_state_area-sold_to_party
          %msg        = NEW zcm_team2_so(
            im_textid     = zcm_team2_so=>c_missing_required_fields
            im_severity   = if_abap_behv_message=>severity-error
            im_field_name = 'Sold-to Party'
          )
          %element-SoldToPartyId = if_abap_behv=>mk-on
        ) TO reported-header.

      ENDIF.

      " Validate Sales Organization.
      IF ls_header-SalesOrganization IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = lc_state_area-sales_organization
          %msg        = NEW zcm_team2_so(
            im_textid     = zcm_team2_so=>c_missing_required_fields
            im_severity   = if_abap_behv_message=>severity-error
            im_field_name = 'Sales Organization'
          )
          %element-SalesOrganization = if_abap_behv=>mk-on
        ) TO reported-header.

      ENDIF.

      " Validate Distribution Channel.
      IF ls_header-DistributionChannel IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = lc_state_area-distribution_channel
          %msg        = NEW zcm_team2_so(
            im_textid     = zcm_team2_so=>c_missing_required_fields
            im_severity   = if_abap_behv_message=>severity-error
            im_field_name = 'Distribution Channel'
          )
          %element-DistributionChannel = if_abap_behv=>mk-on
        ) TO reported-header.

      ENDIF.

      " Validate Division.
      IF ls_header-Division IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #(
          %tky        = ls_header-%tky
          %state_area = lc_state_area-division
          %msg        = NEW zcm_team2_so(
            im_textid     = zcm_team2_so=>c_missing_required_fields
            im_severity   = if_abap_behv_message=>severity-error
            im_field_name = 'Division'
          )
          %element-Division = if_abap_behv=>mk-on
        ) TO reported-header.

      ENDIF.
      " Reject Sales Order if any required field is missing
      IF lv_has_error = abap_true.
        APPEND VALUE #(
          %tky = ls_header-%tky
        ) TO failed-header.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Determination: Set Initial Sales Order Status
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Initialize the lifecycle and fulfillment status of a new Sales Order.
*   Preserve existing status values.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers that trigger initialization
*---------------------------------------------------------------------*
  METHOD set_initial_status.
    DATA lt_headers_update TYPE TABLE FOR UPDATE zir_team2_so_hd\\Header.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        FIELDS ( LifecycleStatus OverallStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers ASSIGNING FIELD-SYMBOL(<lfs_header>).
      IF <lfs_header>-LifecycleStatus IS NOT INITIAL
         AND <lfs_header>-OverallStatus IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = <lfs_header>-%tky
                      LifecycleStatus = COND #( WHEN <lfs_header>-LifecycleStatus IS INITIAL THEN 'OPEN' ELSE <lfs_header>-LifecycleStatus )
                      OverallStatus   = COND #( WHEN <lfs_header>-OverallStatus IS INITIAL THEN 'OPEN' ELSE <lfs_header>-OverallStatus )
                    ) TO lt_headers_update.
    ENDLOOP.

    IF lt_headers_update IS NOT INITIAL.
      MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
        ENTITY Header UPDATE FIELDS ( LifecycleStatus OverallStatus )
        WITH lt_headers_update
        FAILED DATA(lt_failed)
        REPORTED DATA(lt_reported).
    ENDIF.
  ENDMETHOD.

  METHOD recalc_overall_status.
    DATA: lt_headers_update   TYPE TABLE FOR UPDATE zir_team2_so_hd\\Header,
          lv_overall_status   TYPE zteam2_so_hd-overall_status,
          lv_lifecycle_status TYPE zteam2_so_hd-lifecycle_status.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        FIELDS ( SalesOrderId RequestedDeliveryDate LifecycleStatus OverallStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header BY \_Item
        FIELDS ( RequestedQuantity ConfirmedQuantity DeliveryStatus )
        WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_items)
      LINK DATA(lt_links).

    LOOP AT lt_headers ASSIGNING FIELD-SYMBOL(<lfs_header>).

      " Do not reopen a cancelled order (reserved for a future cancel action).
      IF <lfs_header>-OverallStatus = 'CANCELLED'.
        CONTINUE.
      ENDIF.

      DATA(lv_item_count) = 0.
      DATA(lv_fully_delivered_count) = 0.
      DATA(lv_any_delivery) = abap_false.

      LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
        WHERE source-%tky = <lfs_header>-%tky.
        READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>)
          WITH KEY %tky = <lfs_link>-target-%tky.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        lv_item_count += 1.
        IF <lfs_item>-RequestedQuantity > 0
           AND <lfs_item>-ConfirmedQuantity >= <lfs_item>-RequestedQuantity
           AND <lfs_item>-DeliveryStatus = 'FULLY DELIVERED'.
          lv_fully_delivered_count += 1.
        ENDIF.
        IF <lfs_item>-ConfirmedQuantity > 0.
          lv_any_delivery = abap_true.
        ENDIF.
      ENDLOOP.

      " An empty Sales Order remains OPEN; it is not treated as completed.
      lv_overall_status   = 'OPEN'.
      lv_lifecycle_status = 'OPEN'.
      IF lv_item_count > 0.
        IF lv_fully_delivered_count = lv_item_count.
          lv_overall_status   = 'COMPLETED'.
          lv_lifecycle_status = 'COMPLETED'.
        ELSEIF <lfs_header>-RequestedDeliveryDate IS NOT INITIAL
           AND <lfs_header>-RequestedDeliveryDate < lv_today.
          lv_overall_status   = 'OVERDUE'.
          lv_lifecycle_status = 'IN_PROCESS'.
        ELSEIF lv_any_delivery = abap_true.
          lv_overall_status   = 'PARTIAL'.
          lv_lifecycle_status = 'IN_PROCESS'.
        ENDIF.
      ENDIF.

      IF <lfs_header>-OverallStatus = lv_overall_status
         AND <lfs_header>-LifecycleStatus = lv_lifecycle_status.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = <lfs_header>-%tky
                      OverallStatus   = lv_overall_status
                      LifecycleStatus = lv_lifecycle_status ) TO lt_headers_update.
    ENDLOOP.

    IF lt_headers_update IS INITIAL.
      RETURN.
    ENDIF.

    " Criticality fields are calculated by the Header CDS, not persisted.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header UPDATE FIELDS ( LifecycleStatus OverallStatus )
      WITH lt_headers_update
      FAILED DATA(ls_failed_update)
      REPORTED DATA(ls_reported_update).

    LOOP AT ls_failed_update-Header ASSIGNING FIELD-SYMBOL(<lfs_failed>).
      APPEND VALUE #( %tky = <lfs_failed>-%tky ) TO failed-Header.
      APPEND VALUE #( %tky = <lfs_failed>-%tky
                      %msg = new_message_with_text(
                        text = 'Cannot recalculate Sales Order status.'
                        severity = if_abap_behv_message=>severity-error ) ) TO reported-Header.
    ENDLOOP.
  ENDMETHOD.
  METHOD check_sales_area.
    "Validate a complete active sales-area tuple + customer assignment.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        FIELDS ( SalesOrganization DistributionChannel Division SoldToPartyId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_hd).
      APPEND VALUE #(
        %tky        = ls_hd-%tky
        %state_area = 'SALES_AREA'
      ) TO reported-Header.

      "empty_on_save handles missing input separately.
      IF ls_hd-SalesOrganization IS INITIAL
         OR ls_hd-DistributionChannel IS INITIAL
         OR ls_hd-Division IS INITIAL
         OR ls_hd-SoldToPartyId IS INITIAL.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zteam2_s_area AS area
        INNER JOIN zteam2_sales_org AS org
          ON org~sales_organization = area~sales_organization
        INNER JOIN zteam2_dist_chn AS chn
          ON chn~distribution_channel = area~distribution_channel
        INNER JOIN zteam2_division AS div
          ON div~division = area~division
        FIELDS area~is_active
        WHERE area~sales_organization   = @ls_hd-SalesOrganization
          AND area~distribution_channel = @ls_hd-DistributionChannel
          AND area~division             = @ls_hd-Division
          AND org~is_active             = @abap_true
          AND chn~is_active             = @abap_true
          AND div~is_active             = @abap_true
        INTO @DATA(lv_area_active).

      IF sy-subrc <> 0 OR lv_area_active <> abap_true.
        APPEND VALUE #( %tky = ls_hd-%tky ) TO failed-Header.
        APPEND VALUE #(
          %tky        = ls_hd-%tky
          %state_area = 'SALES_AREA'
          %msg        = new_message_with_text(
                          text = 'Sales Organization / Channel / Division combination is invalid or inactive.'
                          severity = if_abap_behv_message=>severity-error )
          %element-SalesOrganization = if_abap_behv=>mk-on
          %element-DistributionChannel = if_abap_behv=>mk-on
          %element-Division = if_abap_behv=>mk-on
        ) TO reported-Header.
        CONTINUE.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.


  METHOD check_ship_to_party.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
        FIELDS ( ShipToPartyId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_hd).
      APPEND VALUE #(
        %tky = ls_hd-%tky
        %state_area = 'SHIP_TO_PARTY'
      ) TO reported-Header.
      "Optional on save; required later in Confirm action.
      IF ls_hd-ShipToPartyId IS INITIAL.
        CONTINUE.
      ENDIF.
      "Reuse the existing Customer BO, not direct access to draft DB tables.
      READ ENTITIES OF zir_team2_customer
        ENTITY Customer
          FIELDS ( CustomerId Is_Active )
          WITH VALUE #( ( CustomerId = ls_hd-ShipToPartyId ) )
        RESULT DATA(lt_customers).

      READ TABLE lt_customers INTO DATA(ls_cust) WITH KEY CustomerId = ls_hd-ShipToPartyId.


      IF sy-subrc <> 0 OR ls_cust-Is_Active <> abap_true.
        APPEND VALUE #( %tky = ls_hd-%tky ) TO failed-Header.
        APPEND VALUE #(
          %tky = ls_hd-%tky
          %state_area = 'SHIP_TO_PARTY'
          %msg = new_message_with_text(
            text = 'Ship-to Party does not exist or is inactive.'
            severity = if_abap_behv_message=>severity-error )
          %element-ShipToPartyId = if_abap_behv=>mk-on
        ) TO reported-Header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


ENDCLASS.
