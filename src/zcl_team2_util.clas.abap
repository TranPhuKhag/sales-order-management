CLASS zcl_team2_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS is_manager
      RETURNING VALUE(rv_is_manager) TYPE abap_bool.

    CLASS-METHODS is_available
      IMPORTING
        iv_product_id       TYPE zteam2_so_it-product_id
        iv_sales_unit       TYPE zteam2_so_it-sales_unit
        iv_quantity         TYPE decfloat34
      RETURNING
        VALUE(rv_available) TYPE abap_bool.
  PROTECTED SECTION.

  PRIVATE SECTION.

    CONSTANTS:
      lc_manager_role TYPE zteam2_role-role_name VALUE 'MANAGER'.

ENDCLASS.


CLASS zcl_team2_util IMPLEMENTATION.

  METHOD is_manager.

*&---------------------------------------------------------------------*
* Authorization Utility: Check Manager Role
*&---------------------------------------------------------------------*
* Created by         : KHANGTP5
* Created date       : 09/10/2026
* Content explanation:
*   Check whether the current logged-in user has an active MANAGER role.
*   Validate the user-role assignment and its validity period.
*---------------------------------------------------------------------*
* Parameters:
* <-- RV_IS_MANAGER  : ABAP_TRUE if the user has a valid Manager role
*---------------------------------------------------------------------*

    " Set default authorization result.
    rv_is_manager = abap_false.

    " Get current logged-in user.
    DATA(lv_user_name) = cl_abap_context_info=>get_user_technical_name( ).

    " Get current system date.
    DATA(lv_current_date) = cl_abap_context_info=>get_system_date( ).

    " Check active Manager Role assignment.
    SELECT SINGLE
      FROM zteam2_user_role AS UserRole
      INNER JOIN zteam2_role AS Role
        ON UserRole~role_id = Role~role_id
      FIELDS Role~role_id
      WHERE UserRole~user_name  = @lv_user_name
        AND UserRole~is_active  = @abap_true
        AND UserRole~valid_from <= @lv_current_date
        AND UserRole~valid_to   >= @lv_current_date
        AND Role~role_name      = @lc_manager_role
        AND Role~is_active      = @abap_true
      INTO @DATA(lv_role_id).

    " Grant authorization if a valid Manager role exists.
    IF sy-subrc = 0.
      rv_is_manager = abap_true.
    ENDIF.

  ENDMETHOD.
  METHOD is_available.

    rv_available = abap_false.

    " Reject invalid requested quantities.
    IF iv_quantity <= 0.
      RETURN.
    ENDIF.

    " Read available quantity from Product Master.
    SELECT SINGLE FROM zir_team2_products
      FIELDS AvailableQuantity, BaseUnit
      WHERE ProductId = @iv_product_id
      INTO @DATA(ls_product).

    " Reject products that do not exist.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " Quantity units must be compatible.
    IF ls_product-BaseUnit <> iv_sales_unit.
      RETURN.
    ENDIF.

    " Check whether stock satisfies the requested quantity.
    IF ls_product-AvailableQuantity >= iv_quantity.
      rv_available = abap_true.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
