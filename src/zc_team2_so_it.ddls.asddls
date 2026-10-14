@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item Projection View'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_TEAM2_SO_IT
  as projection on ZI_TEAM2_SO_IT

{
  key SalesOrderId,
  key SalesOrderItemId,

      @ObjectModel.foreignKey.association: '_Product'
      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZC_TEAM2_PRODUCT_VH',
          element: 'ProductId'
        }
      }]
      ProductId,

      Plant,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      RequestedQuantity,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      ConfirmedQuantity,

      SalesUnit,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      NetPrice,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      NetAmount,
      DeliveryStatus,
      DeliverCriticality,
      
      
      CurrencyCode,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      ProductDescription,

      _Header       : redirected to parent ZCR_TEAM2_SO_HD,
      _ScheduleLine : redirected to composition child ZC_TEAM2_SCHED_LN,
      _Product      : redirected to ZCR_TEAM2_PRODUCTS

}
