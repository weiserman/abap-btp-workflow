@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval - Object Type Value Help'
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZI_APPR_OBJ_TYPE_VH
  as select from zappr_obj_type
{
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['object_type_name']
      @EndUserText.label: 'Object Type'
  key object_type,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Name'
      object_type_name,

      @EndUserText.label: 'Description'
      object_description
}
where is_active = 'X'
