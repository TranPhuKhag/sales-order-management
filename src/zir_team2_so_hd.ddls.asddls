@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@ObjectModel.sapObjectNodeType.name: 'ZTEAM2_SO_HD'
@EndUserText.label: '###GENERATED Core Data Service Entity'
define root view entity ZIR_TEAM2_SO_HD
  as select from zteam2_so_hd as Header

  composition [0..*] of ZI_TEAM2_SO_IT     as _Item
  association [1]    to ZIR_TEAM2_CUSTOMER    as _Customer    on $projection.SoldToPartyId = _Customer.CustomerId
  association [0..1] to ZIR_TEAM2_CUSTOMER as _ShipToCustomer on $projection.ShipToPartyId = _ShipToCustomer.CustomerId
  association [0..*] to ZI_TEAM2_SCHED_LN  as _ScheduleLine   on $projection.SalesOrderId = _ScheduleLine.SalesOrderId
  association [0..1] to ZI_TEAM2_MANAGER   as _Manager        on _Manager.UserName = $session.user
  association [0..1] to ZC_TEAM2_SORG_VH   as _SalesOrgVH     on $projection.SalesOrganization = _SalesOrgVH.SalesOrganization


  association [0..1] to ZC_TEAM2_DCH_VH    as _ChannelVH      on $projection.DistributionChannel = _ChannelVH.DistributionChannel


  association [0..1] to ZC_TEAM2_DIV_VH    as _DivisionVH     on $projection.Division = _DivisionVH.Division


{
  key Header.sales_order_id          as SalesOrderId,

      Header.sales_order_type        as SalesOrderType,

      @ObjectModel.foreignKey.association: '_Customer'
      Header.sold_to_party_id        as SoldToPartyId,

      @ObjectModel.foreignKey.association: '_ShipToCustomer'
      Header.ship_to_party_id        as ShipToPartyId,

      Header.sales_organization      as SalesOrganization,
      Header.distribution_channel    as DistributionChannel,
      Header.division                as Division,

      Header.sales_order_date        as SalesOrderDate,
      Header.pricing_date            as PricingDate,
      Header.requested_delivery_date as RequestedDeliveryDate,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Header.net_amount              as NetAmount,

      Header.currency_code           as CurrencyCode,

      // Sales Order lifecycle status.
      Header.lifecycle_status        as LifecycleStatus,

      case Header.lifecycle_status
        when ''           then 0
        when 'OPEN'       then 0
        when 'IN_PROCESS' then 2
        when 'COMPLETED'  then 3
        else 0
      end                            as LifecycleStatusCriticality,

      // Overall Sales Order processing status.
      Header.overall_status          as OverallStatus,

      case Header.overall_status
        when ''          then 0
        when 'OPEN'      then 0
        when 'PARTIAL'   then 2
        when 'OVERDUE'   then 1
        when 'COMPLETED' then 3
        when 'CANCELLED' then 0
        else 0
      end                            as OverallStatusCriticality,

      // Rejection reason.
      Header.reason                  as Reason,

      @Semantics.user.createdBy: true
      Header.created_by              as CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      Header.created_at              as CreatedAt,

      @Semantics.user.localInstanceLastChangedBy: true
      Header.local_last_changed_by   as LocalLastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      Header.local_last_changed_at   as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      Header.last_changed_at         as LastChangedAt,

      _Item,
      _ScheduleLine,
      _Customer,
      _ShipToCustomer,
      _Manager,

      _SalesOrgVH,
      _ChannelVH,
      _DivisionVH

}
