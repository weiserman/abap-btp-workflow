@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval - Object Type Config'
define root view entity ZR_APPR_OBJ_TYPE
  as select from zappr_obj_type
{
  key object_type,

      object_type_name,
      object_description,
      is_active,

      @Semantics.user.createdBy: true
      created_by,
      @Semantics.systemDateTime.createdAt: true
      created_at,
      @Semantics.user.lastChangedBy: true
      last_changed_by,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed
}
