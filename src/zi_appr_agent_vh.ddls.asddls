@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval - Agent Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_APPR_AGENT_VH
  as select from I_BusinessUserVH
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Agent Type'
  key cast( 'USER' as abap.char(4) )           as agent_type,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Agent ID'
  key cast( UserID as abap.char(40) )          as agent_id,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Description'
      cast( PersonFullName as abap.char(80) )  as description
}

union all

  select from ZI_APPR_ROLE_VH
{
  key cast( 'ROLE' as abap.char(4) )       as agent_type,
  key cast( role_id as abap.char(40) )     as agent_id,
      cast( description as abap.char(80) ) as description
}
