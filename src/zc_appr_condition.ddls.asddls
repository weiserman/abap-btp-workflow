@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rule Condition - Projection'
@Metadata.allowExtensions: true
define view entity ZC_APPR_CONDITION
  as projection on ZR_APPR_CONDITION
{
      @EndUserText.label: 'Condition ID'
  key condition_uuid,

      @EndUserText.label: 'Rule ID'
      rule_uuid,

      @EndUserText.label: 'Object Type'
      object_type,

      @EndUserText.label: 'Field Name'
      field_name,

      @EndUserText.label: 'Operator'
      operator,

      @EndUserText.label: 'Value'
      value_low,

      @EndUserText.label: 'Value High'
      value_high,

      _Rule       : redirected to parent ZC_APPR_RULE,
      _ObjectType : redirected to ZC_APPR_OBJ_TYPE
}
