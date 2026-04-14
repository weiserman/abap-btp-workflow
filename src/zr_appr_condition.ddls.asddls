@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rule Condition'
define view entity ZR_APPR_CONDITION
  as select from zappr_condition
  association to parent ZR_APPR_RULE as _Rule
    on $projection.rule_uuid = _Rule.rule_id
  association [1..1] to ZR_APPR_OBJ_TYPE as _ObjectType
    on $projection.object_type = _ObjectType.object_type
{
  key condition_uuid,
      rule_uuid,
      object_type,
      field_name,
      operator,
      value_low,
      value_high,

      _Rule,
      _ObjectType
}
