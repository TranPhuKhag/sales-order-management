@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@EndUserText: {
  label: '###GENERATED Core Data Service Entity'
}
@ObjectModel: {
  sapObjectNodeType.name: 'ZTEAM2_SO_HD'
}
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZCR_TEAM2_SO_HD
  provider contract transactional_query
  as projection on ZIR_TEAM2_SO_HD
{
  key SalesOrderId,

      SalesOrderType,

      @EndUserText.label: 'Sold-to Party'
      @ObjectModel.text.element: ['SoldToPartyName']
      @UI.textArrangement: #TEXT_LAST
      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZCR_TEAM2_CUSTOMER',
          element: 'CustomerId'
        }
      }]
      SoldToPartyId,

      // Show the selected Ship-to Customer ID and descriptive text.
      @EndUserText.label: 'Ship-to Party'
      @ObjectModel.text.element: ['ShipToPartyName']
      @UI.textArrangement: #TEXT_LAST
      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZCR_TEAM2_CUSTOMER',
          element: 'CustomerId'
        }
      }]
      ShipToPartyId,

      @EndUserText.label: 'Sales Organization'
      @ObjectModel.text.element: ['SalesOrgName']
      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZC_TEAM2_SORG_VH',
          element: 'SalesOrganization'
        }
      }]
      SalesOrganization,

      @EndUserText.label: 'Sales Organization Name'
      @UI.hidden: true
      _SalesOrgVH.SalesOrgName     as SalesOrgName,


      @EndUserText.label: 'Distribution Channel'
      @ObjectModel.text.element: ['ChannelName']
      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZC_TEAM2_SAREA_VH',
          element: 'DistributionChannel'
        },
        additionalBinding: [
          {
            element: 'SalesOrganization',
            localElement: 'SalesOrganization',
            usage: #FILTER
          }
        ]
      }]
      DistributionChannel,

      @EndUserText.label: 'Distribution Channel Name'
      @UI.hidden: true
      _ChannelVH.ChannelName       as ChannelName,


      @EndUserText.label: 'Division'
      @ObjectModel.text.element: ['DivisionName']
      @Consumption.valueHelpDefinition: [{
        entity: {
          name: 'ZC_TEAM2_SAREA_VH',
          element: 'Division'
        },
        additionalBinding: [
          {
            element: 'SalesOrganization',
            localElement: 'SalesOrganization',
            usage: #FILTER
          },
          {
            element: 'DistributionChannel',
            localElement: 'DistributionChannel',
            usage: #FILTER
          }
        ]
      }]
      Division,

      @EndUserText.label: 'Division Name'
      @UI.hidden: true
      _DivisionVH.DivisionName     as DivisionName,


      SalesOrderDate,
      PricingDate,
      RequestedDeliveryDate,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      NetAmount,

      @Consumption.valueHelpDefinition: [{
        entity.name: 'I_CurrencyStdVH',
        entity.element: 'Currency',
        useForValidation: true
      }]
      CurrencyCode,

      LifecycleStatus,
      LifecycleStatusCriticality,

      OverallStatus,
      OverallStatusCriticality,

      Reason,

      @Semantics.user.createdBy: true
      CreatedBy,

      @Semantics.systemDateTime.createdAt: true
      CreatedAt,

      @Semantics.user.localInstanceLastChangedBy: true
      LocalLastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      
      // Sold-to Customer information.
      _Customer.CustomerName       as SoldToPartyName,
      _Customer.Street             as SoldToPartyStreet,
      _Customer.City               as SoldToPartyCity,
      _Customer.Country            as SoldToPartyCountry,
      _Customer.Phone              as SoldToPartyPhone,
      _Customer.Email              as SoldToPartyEmail,

      // Ship-to Customer information.
      _ShipToCustomer.CustomerName as ShipToPartyName,
      _ShipToCustomer.Street       as ShipToPartyStreet,
      _ShipToCustomer.City         as ShipToPartyCity,
      _ShipToCustomer.Country      as ShipToPartyCountry,
      _ShipToCustomer.Phone        as ShipToPartyPhone,
      _ShipToCustomer.Email        as ShipToPartyEmail,

      _Item           : redirected to composition child ZC_TEAM2_SO_IT,

      _Customer       : redirected to ZCR_TEAM2_CUSTOMER,

      _ShipToCustomer : redirected to ZCR_TEAM2_CUSTOMER,

      _Manager
}
