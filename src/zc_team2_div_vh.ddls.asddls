@EndUserText.label: 'Division Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
define view entity ZC_TEAM2_DIV_VH
  as select from zteam2_division
{
  key division as Division,
      division_name as DivisionName
}
where is_active = 'X'
