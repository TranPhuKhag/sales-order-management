@EndUserText.label: 'Sales Area Combination Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
define view entity ZC_TEAM2_SAREA_VH
  as select from zteam2_s_area as Area
    inner join zteam2_sales_org as SalesOrg
      on SalesOrg.sales_organization = Area.sales_organization
    inner join zteam2_dist_chn as Channel
      on Channel.distribution_channel = Area.distribution_channel
    inner join zteam2_division as Div
      on Div.division = Area.division
{
  key Area.sales_organization as SalesOrganization,
  key Area.distribution_channel as DistributionChannel,
  key Area.division as Division,
      Area.sales_area_name as SalesAreaName
}
where Area.is_active = 'X'
  and SalesOrg.is_active = 'X'
  and Channel.is_active = 'X'
  and Div.is_active = 'X'
