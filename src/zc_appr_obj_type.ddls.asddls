@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval - Object Type Projection'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['object_type']
define root view entity ZC_APPR_OBJ_TYPE
  provider contract transactional_query
  as projection on ZR_APPR_OBJ_TYPE
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Object Type Code'
  key object_type,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Object Type Name'
      object_type_name,

      @EndUserText.label: 'Description'
      object_description,

      @EndUserText.label: 'Active'
      is_active,

      @EndUserText.label: 'Created By'
      created_by,
      @EndUserText.label: 'Created At'
      created_at,
      @EndUserText.label: 'Last Changed By'
      last_changed_by,
      @EndUserText.label: 'Last Changed At'
      last_changed_at,
      local_last_changed,

      _Rule     : redirected to composition child ZC_APPR_RULE,
      _Instance : redirected to ZC_APPR_INSTANCE
}
