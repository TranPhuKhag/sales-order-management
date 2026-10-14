@EndUserText.label: 'Distribution Channel Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
define view entity ZC_TEAM2_DCH_VH
  as select from zteam2_dist_chn
{
  key distribution_channel as DistributionChannel,
      channel_name as ChannelName
      
}
where is_active = 'X'
