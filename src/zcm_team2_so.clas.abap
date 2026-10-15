CLASS zcm_team2_so DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_abap_behv_message.
    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    METHODS constructor
      IMPORTING
        !im_textid           LIKE if_t100_message=>t100key OPTIONAL
        !im_severity         TYPE if_abap_behv_message=>t_severity OPTIONAL
        !im_sales_order_id   TYPE zteam2_so_hd-sales_order_id OPTIONAL
        !im_sold_to_party_id TYPE zteam2_so_hd-sold_to_party_id OPTIONAL
        !im_product_id       TYPE zteam2_so_it-product_id OPTIONAL
        !im_field_name       TYPE string OPTIONAL.


    " 001 - Customer &1 does not exist.
    CONSTANTS:
      BEGIN OF c_customer_not_exist,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'SOLD_TO_PARTY_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_customer_not_exist.

    " 002 - Product &1 does not exist.
    CONSTANTS:
      BEGIN OF c_product_not_exist,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE 'PRODUCT_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_product_not_exist.

    " 003 - Sales Order &1 does not exist.
    CONSTANTS:
      BEGIN OF c_sales_order_not_exist,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE 'SALES_ORDER_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_sales_order_not_exist.

    " 004 - Customer &1 is inactive.
    CONSTANTS:
      BEGIN OF c_customer_inactive,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE 'SOLD_TO_PARTY_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_customer_inactive.

    " 005 - Requested Delivery Date cannot be earlier than Sales Order Date.
    CONSTANTS:
      BEGIN OF c_invalid_delivery_date,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_invalid_delivery_date.

    " 006 - Field &1 is required.
    CONSTANTS:
      BEGIN OF c_missing_required_fields,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE 'FIELD_NAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_missing_required_fields.
    " 007 - Requested Quantity must be greater than 0.
    CONSTANTS:
      BEGIN OF c_invalid_requested_quantity,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '007',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_invalid_requested_quantity.
    " 008 - Total Schedule Line Requested Quantity must not exceed Item Requested Quantity.
    CONSTANTS:
      BEGIN OF c_schedule_quantity_exceeded,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '008',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_schedule_quantity_exceeded.

    " Begin change: KHANGTP5 - 14/10/2026
    " Add missing T100 messages for Sales Order RAP processing.

    " 009 - Sales Order number range is nearly exhausted.
    CONSTANTS:
      BEGIN OF c_number_range_warning,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '009',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_number_range_warning.

    " 010 - Not enough Sales Order numbers are available.
    CONSTANTS:
      BEGIN OF c_number_range_exhausted,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '010',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_number_range_exhausted.

    " 011 - Sales Order Items must use the same valid currency.
    CONSTANTS:
      BEGIN OF c_invalid_item_currency,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '011',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_invalid_item_currency.

    " 012 - Cannot recalculate Sales Order status.
    CONSTANTS:
      BEGIN OF c_recalc_overall_status_failed,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '012',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_recalc_overall_status_failed.

    " 013 - Sales area combination is invalid or inactive.
    CONSTANTS:
      BEGIN OF c_invalid_sales_area,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '013',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_invalid_sales_area.

    " 014 - Ship-to Party does not exist or is inactive.
    CONSTANTS:
      BEGIN OF c_invalid_ship_to_party,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '014',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_invalid_ship_to_party.

    " 015 - Item quantity/status recalculation failed.
    CONSTANTS:
      BEGIN OF c_recalc_item_status_failed,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '015',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_recalc_item_status_failed.

    " 016 - Sales Order Header status recalculation failed.
    CONSTANTS:
      BEGIN OF c_recalc_header_status_failed,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '016',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_recalc_header_status_failed.

    " 017 - Confirm Delivery is only allowed for active Sales Orders.
    CONSTANTS:
      BEGIN OF c_confirm_draft_not_allowed,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '017',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_confirm_draft_not_allowed.

    " 018 - Only AVAILABLE Schedule Lines can be confirmed.
    CONSTANTS:
      BEGIN OF c_schedule_not_available,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '018',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_schedule_not_available.

    " 019 - Item is complete, or requested delivery data is invalid.
    CONSTANTS:
      BEGIN OF c_invalid_delivery_data,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '019',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_invalid_delivery_data.

    " 020 - Confirmed quantity would exceed the Item Requested Quantity.
    CONSTANTS:
      BEGIN OF c_confirm_qty_exceeded,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '020',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_confirm_qty_exceeded.

    " 021 - Insufficient stock to confirm this Schedule Line.
    CONSTANTS:
      BEGIN OF c_insufficient_stock,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '021',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_insufficient_stock.

    " 022 - Product stock consumption failed.
    CONSTANTS:
      BEGIN OF c_stock_consumption_failed,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '022',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_stock_consumption_failed.

    " 023 - Could not recalculate the Item and Sales Order statuses.
    CONSTANTS:
      BEGIN OF c_recalc_delivery_failed,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '023',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_recalc_delivery_failed.

    " 024 - Confirmed Quantity or Delivery Date conflicts with availability status.
    CONSTANTS:
      BEGIN OF c_invalid_confirmed_quantity,
        msgid TYPE symsgid VALUE 'ZTEAM2_SO',
        msgno TYPE symsgno VALUE '024',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF c_invalid_confirmed_quantity.

    " End change: KHANGTP5 - 14/10/2026

    DATA:
      sales_order_id   TYPE zteam2_so_hd-sales_order_id,
      sold_to_party_id TYPE zteam2_so_hd-sold_to_party_id,
      product_id       TYPE zteam2_so_it-product_id,
      field_name       TYPE string
      .

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.


CLASS zcm_team2_so IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    CALL METHOD super->constructor( ).

    me->if_t100_message~t100key          = im_textid.
    me->if_abap_behv_message~m_severity = im_severity.

    IF im_sales_order_id IS NOT INITIAL.
      me->sales_order_id = im_sales_order_id.
    ENDIF.

    IF im_sold_to_party_id IS NOT INITIAL.
      me->sold_to_party_id = im_sold_to_party_id.
    ENDIF.

    IF im_product_id IS NOT INITIAL.
      me->product_id = im_product_id.
    ENDIF.
    IF im_field_name IS NOT INITIAL.
      me->field_name = im_field_name.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
