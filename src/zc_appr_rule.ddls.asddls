@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approval Rule - Projection'
@Metadata.allowExtensions: true
@ObjectModel.representativeKey: 'rule_id'
define view entity ZC_APPR_RULE
  as projection on ZR_APPR_RULE
{
      @EndUserText.label: 'Rule ID'
  key rule_id,

      @EndUserText.label: 'Object Type'
      object_type,

      @EndUserText.label: 'Description'
      rule_description,

      @EndUserText.label: 'Level'
      approver_level,

      @EndUserText.label: 'Priority'
      priority,

      @EndUserText.label: 'Agent Type'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_APPR_AGENT_TYPE_VH', element: 'agent_type' } }]
      agent_type,

      @EndUserText.label: 'Agent ID'
      @ObjectModel.text.element: ['user_name']
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_APPR_AGENT_VH', element: 'agent_id' },
        additionalBinding: [
          { localElement: 'agent_type', element: 'agent_type' }
        ]
      }]
      agent_id,

      @EndUserText.label: 'User Name'
      _User.PersonFullName as user_name,

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

      _ObjectType : redirected to parent ZC_APPR_OBJ_TYPE,
      _Condition  : redirected to composition child ZC_APPR_CONDITION
}
