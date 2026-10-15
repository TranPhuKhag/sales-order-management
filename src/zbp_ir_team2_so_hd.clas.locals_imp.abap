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
        sales_area              TYPE string VALUE 'SALES_AREA',
        product                 TYPE string VALUE 'PRODUCT',
      END OF lc_state_area.

*&---------------------------------------------------------------------*
* Constants: Sales Order Overall Status
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_overall_status,
        open      TYPE zteam2_so_hd-overall_status VALUE 'OPEN',
        partial   TYPE zteam2_so_hd-overall_status VALUE 'PARTIAL',
        overdue   TYPE zteam2_so_hd-overall_status VALUE 'OVERDUE',
        completed TYPE zteam2_so_hd-overall_status VALUE 'COMPLETED',
        cancelled TYPE zteam2_so_hd-overall_status VALUE 'CANCELLED',
      END OF lc_overall_status.
*&---------------------------------------------------------------------*
* Constants: Sales Order Lifecycle Status
*&---------------------------------------------------------------------*
    CONSTANTS:
      BEGIN OF lc_lifecycle_status,
        open       TYPE zteam2_so_hd-lifecycle_status VALUE 'OPEN',
        in_process TYPE zteam2_so_hd-lifecycle_status VALUE 'IN_PROCESS',
        completed  TYPE zteam2_so_hd-lifecycle_status VALUE 'COMPLETED',
      END OF lc_lifecycle_status.

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
      lc_number_range_object    type cl_numberrange_runtime=>nr_object VALUE 'ZTEAM2_SO',
      lc_number_range_interval TYPE c LENGTH 2 VALUE '01',
      lc_item_number_step      type int8 VALUE 10,
      lc_item_number_width     TYPE i VALUE 6.
*&---------------------------------------------------------------------*
* Authorization
*&---------------------------------------------------------------------*
    METHODS get_global_authorizations
      FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Header
      RESULT result.

    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION
      IMPORTING keys
                REQUEST requested_authorizations FOR Header
      RESULT result.

*&---------------------------------------------------------------------*
* Dynamic Feature Control
*&---------------------------------------------------------------------*
    METHODS get_instance_features
      FOR INSTANCE FEATURES
      IMPORTING keys
                REQUEST requested_features FOR Header
      RESULT result.

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

    METHODS empty_on_save
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~empty_on_save.

    METHODS check_sales_area
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~check_sales_area.

    METHODS check_ship_to_party
      FOR VALIDATE ON SAVE
      IMPORTING keys FOR Header~check_ship_to_party.

*&---------------------------------------------------------------------*
* Determinations
*&---------------------------------------------------------------------*
    METHODS set_initial_status
      FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~set_initial_status.

*&---------------------------------------------------------------------*
* Internal Actions
*&---------------------------------------------------------------------*
    METHODS recalc_header_net_amount
      FOR MODIFY
      IMPORTING keys FOR ACTION Header~recalc_header_net_amount.

    METHODS recalc_overall_status
      FOR MODIFY
      IMPORTING keys FOR ACTION Header~recalc_overall_status.

ENDCLASS.


CLASS lhc_zir_team2_so_hd IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD get_instance_features.
  ENDMETHOD.


**********************************************************************
* Early Numbering: Generate Sales Order IDs
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Generate unique Sales Order IDs during RAP Early Numbering.
*   Use the configured Number Range Object ZTEAM2_SO.
*   Handle Number Range exceptions and return codes.
*---------------------------------------------------------------------*
* Parameters:
* --> ENTITIES       : Sales Order instances to be created
* <-- MAPPED-HEADER  : Sales Orders with assigned IDs
* <-- FAILED-HEADER  : Sales Orders that failed numbering
* <-- REPORTED-HEADER: Numbering messages
*---------------------------------------------------------------------*
  METHOD earlynumbering_create.

    DATA: ls_entity         TYPE STRUCTURE FOR CREATE zir_team2_so_hd,
          lv_sales_order_id TYPE zteam2_so_hd-sales_order_id.

    " Handle instances that already have a Sales Order ID.
    LOOP AT entities INTO ls_entity
      WHERE SalesOrderId IS NOT INITIAL.

      APPEND VALUE #( %cid         = ls_entity-%cid
                      SalesOrderId = ls_entity-SalesOrderId
                      %is_draft    = ls_entity-%is_draft
                    ) TO mapped-Header.

    ENDLOOP.

    " Keep only instances that require numbering.
    DATA(lt_entities_without_id) = entities.

    DELETE lt_entities_without_id WHERE SalesOrderId IS NOT INITIAL.

    IF lt_entities_without_id IS INITIAL.
      RETURN.
    ENDIF.

    " Request a Number Range block for all Sales Orders.
    TRY.

        zcl_team2_numbering_utility=>get_number_range(
          EXPORTING
            iv_object   = lc_number_range_object
            iv_interval = lc_number_range_interval
            iv_quantity = CONV #( lines( lt_entities_without_id ) )
          IMPORTING
            ev_number       = DATA(lv_number_range_key)
            ev_return_code  = DATA(lv_return_code)
            ev_returned_qty = DATA(lv_returned_quantity)
        ).

      CATCH cx_nr_object_not_found INTO DATA(lx_object_not_found).

        LOOP AT lt_entities_without_id INTO ls_entity.

          APPEND VALUE #( %cid      = ls_entity-%cid
                          %key      = ls_entity-%key
                          %is_draft = ls_entity-%is_draft
                          %msg      = lx_object_not_found
                        ) TO reported-Header.

          APPEND VALUE #( %cid      = ls_entity-%cid
                          %key      = ls_entity-%key
                          %is_draft = ls_entity-%is_draft
                        ) TO failed-Header.

        ENDLOOP.

        RETURN.

      CATCH cx_number_ranges INTO DATA(lx_number_ranges).

        LOOP AT lt_entities_without_id INTO ls_entity.

          APPEND VALUE #( %cid      = ls_entity-%cid
                          %key      = ls_entity-%key
                          %is_draft = ls_entity-%is_draft
                          %msg      = lx_number_ranges
                        ) TO reported-Header.

          APPEND VALUE #( %cid      = ls_entity-%cid
                          %key      = ls_entity-%key
                          %is_draft = ls_entity-%is_draft
                        ) TO failed-Header.

        ENDLOOP.

        RETURN.

    ENDTRY.

    " Check Number Range return status.
    CASE lv_return_code.

      WHEN '1'.

        " Report a warning when the Number Range is nearly exhausted.
        LOOP AT lt_entities_without_id INTO ls_entity.

          APPEND VALUE #( %cid      = ls_entity-%cid
                          %key      = ls_entity-%key
                          %is_draft = ls_entity-%is_draft
                          %msg      = new_message_with_text(
                            severity = if_abap_behv_message=>severity-warning
                            text     = 'Sales Order number range is nearly exhausted.'
                          )
                        ) TO reported-Header.

        ENDLOOP.

      WHEN '2' OR '3'.

        " Reject creation when insufficient numbers are available.
        LOOP AT lt_entities_without_id INTO ls_entity.

          APPEND VALUE #( %cid      = ls_entity-%cid
                          %key      = ls_entity-%key
                          %is_draft = ls_entity-%is_draft
                          %msg      = new_message_with_text(
                            severity = if_abap_behv_message=>severity-error
                            text     = 'Not enough Sales Order numbers are available.'
                          )
                        ) TO reported-Header.

          APPEND VALUE #( %cid        = ls_entity-%cid
                          %key        = ls_entity-%key
                          %is_draft   = ls_entity-%is_draft
                          %fail-cause = if_abap_behv=>cause-conflict
                        ) TO failed-Header.

        ENDLOOP.

        RETURN.

    ENDCASE.

    " Ensure that all requested numbers were returned.
    ASSERT lv_returned_quantity = lines( lt_entities_without_id ).

    " NUMBER_GET returns the highest number of the reserved block.
    lv_sales_order_id = lv_number_range_key - lv_returned_quantity.

    " Map each CREATE instance to its generated Sales Order ID.
    LOOP AT lt_entities_without_id INTO ls_entity.

      lv_sales_order_id += 1.

      APPEND VALUE #( %cid         = ls_entity-%cid
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
*   Assign Item IDs with an increment of 10.
*   Preserve Item IDs already provided by the CREATE request.
*---------------------------------------------------------------------*
* Parameters:
* --> ENTITIES       : Sales Order Items created by association
* <-- MAPPED-ITEM    : Sales Order Items with assigned Item IDs
*---------------------------------------------------------------------*
  METHOD earlynumbering_cba_item.

    DATA: lv_max_item_id  TYPE zteam2_so_it-sales_order_item_id,
          lv_next_item_id TYPE zteam2_so_it-sales_order_item_id.

    " Read existing Items from the RAP transactional buffer.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header BY \_Item
      FROM CORRESPONDING #( entities )
      LINK DATA(lt_item_links).

    " Process each Sales Order separately.
    LOOP AT entities ASSIGNING FIELD-SYMBOL(<lfs_entity>)
      GROUP BY ( SalesOrderId = <lfs_entity>-SalesOrderId
                 IsDraft      = <lfs_entity>-%is_draft )
      ASSIGNING FIELD-SYMBOL(<lfs_group>).

      " Determine the highest existing Item ID.
      lv_max_item_id = REDUCE #(
        INIT lv_max TYPE zteam2_so_it-sales_order_item_id
        FOR ls_link IN lt_item_links
        WHERE ( source-SalesOrderId = <lfs_group>-SalesOrderId
                AND source-%is_draft = <lfs_group>-IsDraft )
        NEXT lv_max = COND #(
          WHEN ls_link-target-SalesOrderItemId > lv_max
          THEN ls_link-target-SalesOrderItemId
          ELSE lv_max
        )
      ).

      " Consider Item IDs supplied in the current CREATE request.
      lv_max_item_id = REDUCE #(
        INIT lv_max = lv_max_item_id
        FOR ls_cba IN entities
        WHERE ( SalesOrderId = <lfs_group>-SalesOrderId
                AND %is_draft = <lfs_group>-IsDraft )
        FOR ls_target IN ls_cba-%target
        NEXT lv_max = COND #(
          WHEN ls_target-SalesOrderItemId > lv_max
          THEN ls_target-SalesOrderItemId
          ELSE lv_max
        )
      ).

      " Number all Items belonging to the current Sales Order.
      LOOP AT GROUP <lfs_group> ASSIGNING FIELD-SYMBOL(<lfs_parent>).

        LOOP AT <lfs_parent>-%target ASSIGNING FIELD-SYMBOL(<lfs_item>).

          " Preserve an Item ID if one is already supplied.
          IF <lfs_item>-SalesOrderItemId IS NOT INITIAL.

            APPEND VALUE #( %cid             = <lfs_item>-%cid
                            %is_draft        = <lfs_item>-%is_draft
                            SalesOrderId     = <lfs_parent>-SalesOrderId
                            SalesOrderItemId = <lfs_item>-SalesOrderItemId
                          ) TO mapped-Item.

            CONTINUE.

          ENDIF.

          " Generate next Item ID: 000010, 000020, 000030, ...
          lv_next_item_id = CONV #(
            zcl_team2_numbering_utility=>get_next_sequence(
              iv_current = CONV int8( lv_max_item_id )
              iv_step    = lc_item_number_step
              iv_width   = lc_item_number_width
            )
          ).

          lv_max_item_id = lv_next_item_id.

          " Map the generated Item ID back to RAP.
          APPEND VALUE #( %cid             = <lfs_item>-%cid
                          %is_draft        = <lfs_item>-%is_draft
                          SalesOrderId     = <lfs_parent>-SalesOrderId
                          SalesOrderItemId = lv_next_item_id
                        ) TO mapped-Item.

        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check Sold-to Party
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Validate the Sold-to Party of each Sales Order Header.
*   Ensure that the referenced Customer exists and is active.
*   Reject Sales Orders with an invalid or inactive Customer.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers to be validated
* <-- FAILED-HEADER  : Sales Orders that fail validation
* <-- REPORTED-HEADER: Validation messages
*---------------------------------------------------------------------*
  METHOD check_sold_to_party.

    DATA lt_customers TYPE SORTED TABLE OF zir_team2_customer
      WITH UNIQUE KEY CustomerId.

    " Read relevant Sales Order Headers.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    " Extract distinct non-initial Customer IDs.
    lt_customers = CORRESPONDING #(
      lt_headers
      DISCARDING DUPLICATES
      MAPPING CustomerId = SoldToPartyId
      EXCEPT *
    ).

    DELETE lt_customers WHERE CustomerId IS INITIAL.

    IF lt_customers IS NOT INITIAL.

      " Read Customer Business Object.
      READ ENTITIES OF zir_team2_customer
        ENTITY Customer
        FIELDS ( CustomerId Is_Active )
        WITH CORRESPONDING #( lt_customers )
        RESULT DATA(lt_customer_db).

    ENDIF.

    " Validate each Sales Order Header.
    LOOP AT lt_headers INTO DATA(ls_header).

      " Clear previous Sold-to Party state messages.
      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-sold_to_party
                    ) TO reported-Header.

      " Skip existence validation when Sold-to Party is empty.
      " The required-field validation handles this case separately.
      IF ls_header-SoldToPartyId IS INITIAL.
        CONTINUE.
      ENDIF.

      " Find the referenced Customer.
      READ TABLE lt_customer_db
        WITH TABLE KEY entity
        COMPONENTS CustomerId = ls_header-SoldToPartyId
        INTO DATA(ls_customer).

      IF sy-subrc <> 0.

        " Reject Sales Order when Customer does not exist.
        APPEND VALUE #( %tky = ls_header-%tky
                      ) TO failed-Header.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-sold_to_party
                        %msg        = NEW zcm_team2_so(
                          im_textid           = zcm_team2_so=>c_customer_not_exist
                          im_severity         = if_abap_behv_message=>severity-error
                          im_sold_to_party_id = ls_header-SoldToPartyId
                        )
                        %element-SoldToPartyId = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ELSEIF ls_customer-Is_Active = abap_false.

        " Reject Sales Order when Customer is inactive.
        APPEND VALUE #( %tky = ls_header-%tky
                      ) TO failed-Header.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-sold_to_party
                        %msg        = NEW zcm_team2_so(
                          im_textid           = zcm_team2_so=>c_customer_inactive
                          im_severity         = if_abap_behv_message=>severity-error
                          im_sold_to_party_id = ls_header-SoldToPartyId
                        )
                        %element-SoldToPartyId = if_abap_behv=>mk-on
                      ) TO reported-Header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check Requested Delivery Date
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
* Content explanation:
*   Validate the Requested Delivery Date of Sales Order Headers.
*   Ensure that it is not earlier than the Sales Order Date.
*   Reject Sales Orders with an invalid delivery date.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers to be validated
* <-- FAILED-HEADER  : Sales Orders that fail validation
* <-- REPORTED-HEADER: Validation messages
*---------------------------------------------------------------------*
  METHOD check_requested_delivery_date.

    " Read relevant Sales Order Header dates.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( SalesOrderDate RequestedDeliveryDate )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      " Clear previous Requested Delivery Date state messages.
      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-requested_delivery_date
                    ) TO reported-Header.

      " Validate Requested Delivery Date against Sales Order Date.
      IF ls_header-RequestedDeliveryDate IS NOT INITIAL
         AND ls_header-SalesOrderDate IS NOT INITIAL
         AND ls_header-RequestedDeliveryDate < ls_header-SalesOrderDate.

        APPEND VALUE #( %tky = ls_header-%tky
                      ) TO failed-Header.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-requested_delivery_date
                        %msg        = NEW zcm_team2_so(
                          im_textid   = zcm_team2_so=>c_invalid_delivery_date
                          im_severity = if_abap_behv_message=>severity-error
                        )
                        %element-RequestedDeliveryDate = if_abap_behv=>mk-on
                      ) TO reported-Header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Internal Action: Recalculate Sales Order Header Net Amount
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 08/10/2026
*---------------------------------------------------------------------*
* Change History:
* 14/10/2026 KHANGTP5 - Added Header CurrencyCode derivation and
*                       currency consistency validation.
*---------------------------------------------------------------------*
* Content explanation:
*   Recalculate Header Net Amount from related Sales Order Items.
*   Derive Header Currency Code from Item Currency Code.
*   Reject aggregation when Item currencies are inconsistent.
*   Avoid unnecessary updates to the Header and ETag.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers requiring recalculation
* <-- FAILED-HEADER  : Headers that fail recalculation
* <-- REPORTED-HEADER: Recalculation messages
*---------------------------------------------------------------------*
  METHOD recalc_header_net_amount.

    DATA: lt_headers_update    TYPE TABLE FOR UPDATE zir_team2_so_hd\\Header,
          lv_header_net_amount TYPE zteam2_so_hd-net_amount,
          lv_currency_code     TYPE zteam2_so_hd-currency_code,
          lv_currency_invalid  TYPE abap_bool.

    " Read relevant Sales Order Headers from the transactional buffer.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( NetAmount CurrencyCode )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Read Item Net Amount and Currency Code.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header BY \_Item
      FIELDS ( NetAmount CurrencyCode )
      WITH CORRESPONDING #( lt_headers )
      LINK DATA(lt_item_links)
      RESULT DATA(lt_items).

    " Recalculate each Sales Order Header.
    LOOP AT lt_headers INTO DATA(ls_header).

      CLEAR: lv_header_net_amount,
             lv_currency_code,
             lv_currency_invalid.

      " Preserve the existing Header currency when maintained.
      lv_currency_code = ls_header-CurrencyCode.

      " Process Items belonging to the current Sales Order Header.
      LOOP AT lt_item_links INTO DATA(ls_link)
        WHERE source-%tky = ls_header-%tky.

        " Find the associated Sales Order Item.
        READ TABLE lt_items INTO DATA(ls_item)
          WITH TABLE KEY id
          COMPONENTS %tky = ls_link-target-%tky.

        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        " Add Item Net Amount to the Header total.
        lv_header_net_amount += ls_item-NetAmount.

        " Validate and derive Header Currency Code.
        IF ls_item-CurrencyCode IS NOT INITIAL.
          IF lv_currency_code IS INITIAL.

            lv_currency_code = ls_item-CurrencyCode.

          ELSEIF lv_currency_code <> ls_item-CurrencyCode.
            lv_currency_invalid = abap_true.

          ENDIF.

        ELSEIF ls_item-NetAmount <> 0.
          " A nonzero monetary amount must have a currency.
          lv_currency_invalid = abap_true.

        ENDIF.

      ENDLOOP.

      " Reject inconsistent Item currencies.
      IF lv_currency_invalid = abap_true.

        APPEND VALUE #( %tky = ls_header-%tky
                      ) TO failed-Header.

        APPEND VALUE #( %tky                  = ls_header-%tky
                        %msg                  = new_message_with_text(
                          text     = 'Sales Order Items must use the same valid currency.'
                          severity = if_abap_behv_message=>severity-error
                        )
                        %element-CurrencyCode = if_abap_behv=>mk-on
                      ) TO reported-Header.

        CONTINUE.

      ENDIF.

      " Skip update when amount and currency are unchanged.
      IF ls_header-NetAmount = lv_header_net_amount
         AND ls_header-CurrencyCode = lv_currency_code.
        CONTINUE.
      ENDIF.

      " Prepare Header Net Amount and Currency Code update.
      APPEND VALUE #( %tky         = ls_header-%tky
                      NetAmount    = lv_header_net_amount
                      CurrencyCode = lv_currency_code
                    ) TO lt_headers_update.

    ENDLOOP.

    IF lt_headers_update IS INITIAL.
      RETURN.
    ENDIF.

    " Update Header data in the RAP transactional buffer.
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

    " Forward generated messages to the RAP response.
    LOOP AT ls_reported-Header INTO DATA(ls_reported_header).
      APPEND CORRESPONDING #( ls_reported_header ) TO reported-Header.
    ENDLOOP.

  ENDMETHOD.
**********************************************************************
* Instance Authorization: Check Sales Order Update Authorization
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Determine update authorization for each Sales Order Header.
*   Allow Managers to update all Sales Orders.
*   Allow the owner to update their own Sales Orders.
*   Deny update authorization for all other users.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS                     : Sales Order Headers to be checked
* --> REQUESTED_AUTHORIZATIONS : Requested authorization operations
* <-- RESULT                   : Instance authorization result
*---------------------------------------------------------------------*
  METHOD get_instance_authorizations.

    DATA(lv_user_name)  = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_is_manager) = zcl_team2_util=>is_manager( ).

    " Read Sales Orders requested for authorization.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( CreatedBy )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      " Deny update authorization by default.
      DATA(lv_is_authorized) = if_abap_behv=>auth-unauthorized.

      " Allow Managers to update all Sales Orders.
      IF lv_is_manager = abap_true.

        lv_is_authorized = if_abap_behv=>auth-allowed.

      ELSEIF ls_header-CreatedBy = lv_user_name.

        " Allow the creator to update their own Sales Order.
        lv_is_authorized = if_abap_behv=>auth-allowed.

      ENDIF.

      APPEND VALUE #( %tky    = ls_header-%tky
                      %update = lv_is_authorized
                    ) TO result.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check Required Sales Order Header Fields
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Validate required fields of the Sales Order Header before saving.
*   Check Sales Order Date, Type, Sold-to Party, and Sales Area.
*   Reject the Sales Order and report an error for each missing field.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers to be validated
* <-- FAILED-HEADER  : Sales Orders that fail validation
* <-- REPORTED-HEADER: Validation messages and highlighted fields
*---------------------------------------------------------------------*
  METHOD empty_on_save.

    " Read required Sales Order Header fields.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( SalesOrderDate SalesOrderType SoldToPartyId
               SalesOrganization DistributionChannel Division )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      DATA(lv_has_error) = abap_false.

      " Clear previous required-field state messages.
      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-sales_order_date
                    ) TO reported-Header.

      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-sales_order_type
                    ) TO reported-Header.

      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-sold_to_party_required
                    ) TO reported-Header.

      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-sales_organization
                    ) TO reported-Header.

      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-distribution_channel
                    ) TO reported-Header.

      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-division
                    ) TO reported-Header.

      " Validate Sales Order Date.
      IF ls_header-SalesOrderDate IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-sales_order_date
                        %msg        = NEW zcm_team2_so(
                          im_textid     = zcm_team2_so=>c_missing_required_fields
                          im_severity   = if_abap_behv_message=>severity-error
                          im_field_name = 'Sales Order Date'
                        )
                        %element-SalesOrderDate = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.

      " Validate Sales Order Type.
      IF ls_header-SalesOrderType IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-sales_order_type
                        %msg        = NEW zcm_team2_so(
                          im_textid     = zcm_team2_so=>c_missing_required_fields
                          im_severity   = if_abap_behv_message=>severity-error
                          im_field_name = 'Sales Order Type'
                        )
                        %element-SalesOrderType = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.

      " Validate Sold-to Party.
      IF ls_header-SoldToPartyId IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-sold_to_party_required
                        %msg        = NEW zcm_team2_so(
                          im_textid     = zcm_team2_so=>c_missing_required_fields
                          im_severity   = if_abap_behv_message=>severity-error
                          im_field_name = 'Sold-to Party'
                        )
                        %element-SoldToPartyId = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.

      " Validate Sales Organization.
      IF ls_header-SalesOrganization IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-sales_organization
                        %msg        = NEW zcm_team2_so(
                          im_textid     = zcm_team2_so=>c_missing_required_fields
                          im_severity   = if_abap_behv_message=>severity-error
                          im_field_name = 'Sales Organization'
                        )
                        %element-SalesOrganization = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.

      " Validate Distribution Channel.
      IF ls_header-DistributionChannel IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-distribution_channel
                        %msg        = NEW zcm_team2_so(
                          im_textid     = zcm_team2_so=>c_missing_required_fields
                          im_severity   = if_abap_behv_message=>severity-error
                          im_field_name = 'Distribution Channel'
                        )
                        %element-DistributionChannel = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.

      " Validate Division.
      IF ls_header-Division IS INITIAL.

        lv_has_error = abap_true.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-division
                        %msg        = NEW zcm_team2_so(
                          im_textid     = zcm_team2_so=>c_missing_required_fields
                          im_severity   = if_abap_behv_message=>severity-error
                          im_field_name = 'Division'
                        )
                        %element-Division = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.

      " Reject the Sales Order when any required field is missing.
      IF lv_has_error = abap_true.

        APPEND VALUE #( %tky = ls_header-%tky
                      ) TO failed-Header.

      ENDIF.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Determination: Set Initial Sales Order Status
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Initialize lifecycle and fulfillment statuses for new Sales Orders.
*   Set missing Lifecycle Status and Overall Status to OPEN.
*   Preserve status values that have already been assigned.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers that trigger initialization
*---------------------------------------------------------------------*
  METHOD set_initial_status.

    DATA lt_headers_update TYPE TABLE FOR UPDATE zir_team2_so_hd\\Header.

    " Read current Sales Order status values.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( LifecycleStatus OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers ASSIGNING FIELD-SYMBOL(<lfs_header>).

      " Preserve Headers with both statuses already assigned.
      IF <lfs_header>-LifecycleStatus IS NOT INITIAL
         AND <lfs_header>-OverallStatus IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      " Prepare initial Sales Order status values.
      APPEND VALUE #( %tky            = <lfs_header>-%tky
                      LifecycleStatus = COND #(
                        WHEN <lfs_header>-LifecycleStatus IS INITIAL
                        THEN lc_lifecycle_status-open
                        ELSE <lfs_header>-LifecycleStatus
                      )
                      OverallStatus   = COND #(
                        WHEN <lfs_header>-OverallStatus IS INITIAL
                        THEN lc_overall_status-open
                        ELSE <lfs_header>-OverallStatus
                      )
                    ) TO lt_headers_update.

    ENDLOOP.

    IF lt_headers_update IS INITIAL.
      RETURN.
    ENDIF.

    " Update initial statuses in the RAP transactional buffer.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( LifecycleStatus OverallStatus )
      WITH lt_headers_update.

  ENDMETHOD.
**********************************************************************
* Internal Action: Recalculate Sales Order Overall Status
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 13/10/2026
* Content explanation:
*   Recalculate Overall Status and Lifecycle Status of Sales Orders.
*   Evaluate delivery progress of all related Sales Order Items.
*   Set COMPLETED, OVERDUE, PARTIAL, or OPEN as appropriate.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers requiring recalculation
* <-- FAILED-HEADER  : Headers that fail status update
* <-- REPORTED-HEADER: Status recalculation messages
*---------------------------------------------------------------------*
  METHOD recalc_overall_status.

    DATA: lt_headers_update   TYPE TABLE FOR UPDATE zir_team2_so_hd\\Header,
          lv_overall_status   TYPE zteam2_so_hd-overall_status,
          lv_lifecycle_status TYPE zteam2_so_hd-lifecycle_status.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    " Read relevant Sales Order Headers.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( SalesOrderId RequestedDeliveryDate LifecycleStatus
               OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    IF lt_headers IS INITIAL.
      RETURN.
    ENDIF.

    " Read all Items belonging to the affected Headers.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header BY \_Item
      FIELDS ( RequestedQuantity ConfirmedQuantity DeliveryStatus )
      WITH CORRESPONDING #( lt_headers )
      RESULT DATA(lt_items)
      LINK DATA(lt_links).

    " Recalculate statuses for each Sales Order Header.
    LOOP AT lt_headers ASSIGNING FIELD-SYMBOL(<lfs_header>).

      " Preserve cancelled Sales Orders.
      IF <lfs_header>-OverallStatus = lc_overall_status-cancelled.
        CONTINUE.
      ENDIF.

      DATA(lv_item_count)            = 0.
      DATA(lv_fully_delivered_count) = 0.
      DATA(lv_any_delivery)          = abap_false.

      " Evaluate all Items belonging to the current Header.
      LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<lfs_link>)
        WHERE source-%tky = <lfs_header>-%tky.

        READ TABLE lt_items ASSIGNING FIELD-SYMBOL(<lfs_item>)
          WITH KEY %tky = <lfs_link>-target-%tky.

        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        lv_item_count += 1.

        " Count Items that are completely delivered.
        IF <lfs_item>-RequestedQuantity > 0
           AND <lfs_item>-ConfirmedQuantity >= <lfs_item>-RequestedQuantity
           AND <lfs_item>-DeliveryStatus = lc_delivery_status-fully.

          lv_fully_delivered_count += 1.

        ENDIF.

        " Check whether any quantity has already been delivered.
        IF <lfs_item>-ConfirmedQuantity > 0.
          lv_any_delivery = abap_true.
        ENDIF.
      ENDLOOP.

      " An empty Sales Order remains OPEN.
      lv_overall_status   = lc_overall_status-open.
      lv_lifecycle_status = lc_lifecycle_status-open.

      IF lv_item_count > 0.

        IF lv_fully_delivered_count = lv_item_count.

          " All Sales Order Items are fully delivered.
          lv_overall_status   = lc_overall_status-completed.
          lv_lifecycle_status = lc_lifecycle_status-completed.

        ELSEIF <lfs_header>-RequestedDeliveryDate IS NOT INITIAL
           AND <lfs_header>-RequestedDeliveryDate < lv_today.

          " Delivery is incomplete and the requested date has passed.
          lv_overall_status   = lc_overall_status-overdue.
          lv_lifecycle_status = lc_lifecycle_status-in_process.

        ELSEIF lv_any_delivery = abap_true.

          " At least one Item has been partially delivered.
          lv_overall_status   = lc_overall_status-partial.
          lv_lifecycle_status = lc_lifecycle_status-in_process.
        ENDIF.
      ENDIF.
      " Skip Headers whose statuses have not changed.
      IF <lfs_header>-OverallStatus = lv_overall_status
         AND <lfs_header>-LifecycleStatus = lv_lifecycle_status.
        CONTINUE.
      ENDIF.

      " Prepare Sales Order Header status update.
      APPEND VALUE #( %tky            = <lfs_header>-%tky
                      OverallStatus   = lv_overall_status
                      LifecycleStatus = lv_lifecycle_status
                    ) TO lt_headers_update.

    ENDLOOP.

    IF lt_headers_update IS INITIAL.
      RETURN.
    ENDIF.

    " Criticality fields are calculated by the Header CDS.
    MODIFY ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( LifecycleStatus OverallStatus )
      WITH lt_headers_update
      FAILED DATA(ls_failed_update)
      REPORTED DATA(ls_reported_update).

    " Forward failed updates to the Action response.
    LOOP AT ls_failed_update-Header ASSIGNING FIELD-SYMBOL(<lfs_failed>).

      APPEND VALUE #( %tky = <lfs_failed>-%tky
                    ) TO failed-Header.

      APPEND VALUE #( %tky = <lfs_failed>-%tky
                      %msg = new_message_with_text(
                        text     = 'Cannot recalculate Sales Order status.'
                        severity = if_abap_behv_message=>severity-error
                      )
                    ) TO reported-Header.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check Sales Area
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 14/10/2026
* Content explanation:
*   Validate the Sales Organization, Distribution Channel, and Division.
*   Ensure that the complete Sales Area combination exists and is active.
*   Reject Sales Orders with an invalid or inactive Sales Area.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers to be validated
* <-- FAILED-HEADER  : Sales Orders that fail Sales Area validation
* <-- REPORTED-HEADER: Sales Area validation messages
*---------------------------------------------------------------------*
  METHOD check_sales_area.

    " Read relevant Sales Area fields.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( SalesOrganization DistributionChannel Division
               SoldToPartyId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      " Clear previous Sales Area state messages.
      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-sales_area
                    ) TO reported-Header.

      " Required-field validation handles incomplete Sales Area input.
      IF ls_header-SalesOrganization IS INITIAL
         OR ls_header-DistributionChannel IS INITIAL
         OR ls_header-Division IS INITIAL
         OR ls_header-SoldToPartyId IS INITIAL.
        CONTINUE.
      ENDIF.

      " Validate the active Sales Area combination.
      SELECT SINGLE FROM zteam2_s_area AS area
        INNER JOIN zteam2_sales_org AS org
          ON org~sales_organization = area~sales_organization
        INNER JOIN zteam2_dist_chn AS chn
          ON chn~distribution_channel = area~distribution_channel
        INNER JOIN zteam2_division AS div
          ON div~division = area~division
        FIELDS area~is_active
        WHERE area~sales_organization = @ls_header-SalesOrganization
          AND area~distribution_channel = @ls_header-DistributionChannel
          AND area~division = @ls_header-Division
          AND org~is_active = @abap_true
          AND chn~is_active = @abap_true
          AND div~is_active = @abap_true
        INTO @DATA(lv_sales_area_active).

      IF sy-subrc <> 0
         OR lv_sales_area_active <> abap_true.
        APPEND VALUE #( %tky = ls_header-%tky
                      ) TO failed-Header.

        APPEND VALUE #( %tky                         = ls_header-%tky
                        %state_area                  = lc_state_area-sales_area
                        %msg                         = new_message_with_text(
                          text     = 'Sales Organization / Channel / Division combination is invalid or inactive.'
                          severity = if_abap_behv_message=>severity-error
                        )
                        %element-SalesOrganization   = if_abap_behv=>mk-on
                        %element-DistributionChannel = if_abap_behv=>mk-on
                        %element-Division            = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.
    ENDLOOP.
  ENDMETHOD.
**********************************************************************
* Validation: Check Ship-to Party
**********************************************************************
* Created by         : KHANGTP5
* Created date       : 14/10/2026
* Content explanation:
*   Validate the optional Ship-to Party of the Sales Order Header.
*   Ensure that the referenced Customer exists and is active.
*   Leave an empty Ship-to Party valid during normal save processing.
*---------------------------------------------------------------------*
* Parameters:
* --> KEYS           : Sales Order Headers to be validated
* <-- FAILED-HEADER  : Sales Orders that fail Ship-to Party validation
* <-- REPORTED-HEADER: Ship-to Party validation messages
*---------------------------------------------------------------------*
  METHOD check_ship_to_party.

    " Read Ship-to Party from relevant Sales Order Headers.
    READ ENTITIES OF zir_team2_so_hd IN LOCAL MODE
      ENTITY Header
      FIELDS ( ShipToPartyId )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers).

    LOOP AT lt_headers INTO DATA(ls_header).

      " Clear previous Ship-to Party state messages.
      APPEND VALUE #( %tky        = ls_header-%tky
                      %state_area = lc_state_area-ship_to_party
                    ) TO reported-Header.

      " Ship-to Party is optional during normal save processing.
      IF ls_header-ShipToPartyId IS INITIAL.
        CONTINUE.
      ENDIF.

      " Read the Customer Business Object instead of draft DB tables.
      READ ENTITIES OF zir_team2_customer
        ENTITY Customer
        FIELDS ( CustomerId Is_Active )
        WITH VALUE #( ( CustomerId = ls_header-ShipToPartyId ) )
        RESULT DATA(lt_customers).

      " Find the referenced Ship-to Party.
      READ TABLE lt_customers INTO DATA(ls_customer) WITH KEY CustomerId = ls_header-ShipToPartyId.

      IF sy-subrc <> 0
         OR ls_customer-Is_Active <> abap_true.

        APPEND VALUE #( %tky = ls_header-%tky
                      ) TO failed-Header.

        APPEND VALUE #( %tky        = ls_header-%tky
                        %state_area = lc_state_area-ship_to_party
                        %msg        = new_message_with_text(
                          text     = 'Ship-to Party does not exist or is inactive.'
                          severity = if_abap_behv_message=>severity-error
                        )
                        %element-ShipToPartyId = if_abap_behv=>mk-on
                      ) TO reported-Header.

      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
