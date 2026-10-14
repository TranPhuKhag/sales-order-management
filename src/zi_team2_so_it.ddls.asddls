@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_TEAM2_SO_IT
  as select from zteam2_so_it as Item

  association        to parent ZIR_TEAM2_SO_HD as _Header  on $projection.SalesOrderId = _Header.SalesOrderId
  association [1..1] to ZIR_TEAM2_PRODUCTS     as _Product on $projection.ProductId = _Product.ProductId
  composition [0..*] of ZI_TEAM2_SCHED_LN as _ScheduleLine

{
  key Item.sales_order_id        as SalesOrderId,
  key Item.sales_order_item_id   as SalesOrderItemId,
      Item.product_id            as ProductId,
      Item.plant                 as Plant,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      Item.requested_quantity    as RequestedQuantity,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      Item.confirmed_quantity    as ConfirmedQuantity,

      Item.sales_unit            as SalesUnit,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Item.net_price             as NetPrice,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Item.net_amount            as NetAmount,
      Item.delivery_status       as DeliveryStatus, // Not Delivered // Partially Delivered // Fully Delivered

      case Item.delivery_status
        when 'NOT DELIVERED'       then 1
        when 'PARTIALLY DELIVERED' then 2
        when 'FULLY DELIVERED'           then 3
        else 0
      end                        as DeliverCriticality,

      Item.currency_code         as CurrencyCode,

      Item.created_by            as CreatedBy,
      Item.created_at            as CreatedAt,
      Item.local_last_changed_by as LocalLastChangedBy,
      Item.local_last_changed_at as LocalLastChangedAt,
      Item.last_changed_at       as LastChangedAt,

      _Product.ProductDesc       as ProductDescription,


      _Header,
      _ScheduleLine,
      _Product
}
