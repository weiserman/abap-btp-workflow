@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval - Business Role Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZI_APPR_ROLE_VH
  as select from I_IAMBusinessRole as br
    left outer join I_IAMBusinessRoleText as brt
      on brt.BusinessRoleUUID = br.BusinessRoleUUID
{
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['description']
      @EndUserText.label: 'Business Role'
  key br.BusinessRole as role_id,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Description'
      cast( brt.Name as abap.char(80) ) as description
}
