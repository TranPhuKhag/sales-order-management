@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Schedule Line Projection View'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true

define view entity ZC_TEAM2_SCHED_LN
  as projection on ZI_TEAM2_SCHED_LN
{
  key SalesOrderId,
  key SalesOrderItemId,
  key ScheduleLineId,

      RequestedDeliveryDate,
      ConfirmedDeliveryDate,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      RequestedQuantity,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      ConfirmedQuantity,

      @Semantics.unitOfMeasure: true
      SalesUnit,

      AvailabilityStatus,
      AvailabilityCriticality,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      /* Associations */
      _Item   : redirected to parent ZC_TEAM2_SO_IT,
      _Header : redirected to ZCR_TEAM2_SO_HD
}
