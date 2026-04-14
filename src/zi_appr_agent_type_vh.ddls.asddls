@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval - Agent Type Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZI_APPR_AGENT_TYPE_VH
  as select from zappr_agent_type
{
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['description']
      @EndUserText.label: 'Agent Type'
  key agent_type,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Description'
      description
}
where is_active = 'X'
