@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval Rule - Projection'
@Metadata.allowExtensions: true
define view entity ZC_APPR_RULE
  as projection on ZR_APPR_RULE
{
      @EndUserText.label: 'Rule ID'
  key rule_id,

      @EndUserText.label: 'Object Type'
      object_type,

      @EndUserText.label: 'Description'
      rule_description,

      @EndUserText.label: 'Condition Field'
      condition_field,

      @EndUserText.label: 'Operator'
      condition_operator,

      @EndUserText.label: 'Condition Value'
      condition_value,

      @EndUserText.label: 'Approver Role'
      approver_role,

      @EndUserText.label: 'Level'
      approver_level,

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

      _ObjectType : redirected to parent ZC_APPR_OBJ_TYPE
}
