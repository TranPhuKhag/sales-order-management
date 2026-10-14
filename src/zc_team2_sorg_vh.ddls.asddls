@EndUserText.label: 'Sales Organization Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
define view entity ZC_TEAM2_SORG_VH
  as select from zteam2_sales_org
{
  key sales_organization as SalesOrganization,
      sales_org_name as SalesOrgName
}
where is_active = 'X'
