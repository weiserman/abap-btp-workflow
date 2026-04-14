@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval Routing Rule'
define view entity ZR_APPR_RULE
  as select from zappr_rule
  composition [0..*] of ZR_APPR_CONDITION as _Condition
  association to parent ZR_APPR_OBJ_TYPE as _ObjectType
    on $projection.object_type = _ObjectType.object_type
  association [0..1] to I_BusinessUserVH as _User
    on $projection.agent_id = _User.UserID
  association [0..1] to ZI_APPR_ROLE_VH as _Role
    on $projection.agent_id = _Role.role_id
{
  key rule_id,
      object_type,

      rule_description,
      approver_level,
      priority,
      agent_type,
      agent_id,
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
      local_last_changed,

      _ObjectType,
      _Condition,
      _User,
      _Role
}
