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
