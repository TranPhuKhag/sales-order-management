
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Schedule Line Interface View'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_TEAM2_SCHED_LN
  as select from zteam2_sched_ln as ScheduleLine

  association to parent ZI_TEAM2_SO_IT as _Item
    on  $projection.SalesOrderId     = _Item.SalesOrderId
    and $projection.SalesOrderItemId = _Item.SalesOrderItemId

  association to ZIR_TEAM2_SO_HD as _Header
    on $projection.SalesOrderId = _Header.SalesOrderId


{
  key ScheduleLine.sales_order_id          as SalesOrderId,
  key ScheduleLine.sales_order_item_id     as SalesOrderItemId,
  key ScheduleLine.schedule_line_id        as ScheduleLineId,

      ScheduleLine.requested_delivery_date as RequestedDeliveryDate,
      ScheduleLine.confirmed_delivery_date as ConfirmedDeliveryDate,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      ScheduleLine.requested_quantity      as RequestedQuantity,

      @Semantics.quantity.unitOfMeasure: 'SalesUnit'
      ScheduleLine.confirmed_quantity      as ConfirmedQuantity,

      ScheduleLine.sales_unit              as SalesUnit,

      ScheduleLine.availability_status     as AvailabilityStatus, // CANCELLED / PENDING / CONFIRMED

case
  when ScheduleLine.availability_status = 'CONFIRMED' then 0
  when ScheduleLine.availability_status = 'AVAILABLE'   then 0
  when ScheduleLine.availability_status = 'UNAVAILABLE' then 0
  else 0
end as AvailabilityCriticality,

      ScheduleLine.created_by              as CreatedBy,
      ScheduleLine.created_at              as CreatedAt,
      ScheduleLine.local_last_changed_by   as LocalLastChangedBy,
      ScheduleLine.local_last_changed_at   as LocalLastChangedAt,
      ScheduleLine.last_changed_at         as LastChangedAt,

      _Item,
      _Header
}
