@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Instance - Projection'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['approval_number']
define root view entity ZC_APPR_INSTANCE
  provider contract transactional_query
  as projection on ZR_APPR_INSTANCE
{
      @EndUserText.label: 'Approval ID'
  key approval_id,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Approval Number'
      approval_number,

      @EndUserText.label: 'Object Type'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_APPR_OBJ_TYPE_VH', element: 'object_type' } }]
      object_type,

      @EndUserText.label: 'Object Key'
      object_key,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Object Name'
      object_name,

      @EndUserText.label: 'Object Type Name'
      ObjectTypeName,

      @EndUserText.label: 'Status'
      current_status,

      @EndUserText.label: 'Approver Role'
      approver_role,

      @EndUserText.label: 'Approval Level'
      approver_level,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Description'
      description,

      @EndUserText.label: 'Justification'
      justification,

      @EndUserText.label: 'Requested By'
      requested_by,

      @EndUserText.label: 'Requested At'
      requested_at,

      @EndUserText.label: 'Decided By'
      decided_by,

      @EndUserText.label: 'Decided At'
      decided_at,

      @EndUserText.label: 'Decision Comment'
      decision_comment,

      @EndUserText.label: 'Status Text'
      StatusText,

      StatusCriticality,

      @EndUserText.label: 'Created By'
      created_by,

      @EndUserText.label: 'Created At'
      created_at,

      @EndUserText.label: 'Last Changed By'
      last_changed_by,

      @EndUserText.label: 'Last Changed At'
      last_changed_at,

      local_last_changed,

      _Step    : redirected to composition child ZC_APPR_STEP,
      _Context : redirected to composition child ZC_APPR_INSTANCE_CTX
}
