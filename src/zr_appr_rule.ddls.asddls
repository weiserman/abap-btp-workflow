@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Routing Rule'
define root view entity ZR_APPR_RULE
  as select from zappr_rule
{
  key rule_id,

      object_type,
      rule_description,
      condition_field,
      condition_operator,
      condition_value,
      approver_role,
      approver_level,
      is_active,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed
}
