@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Instance - Projection'
@Metadata.allowExtensions: true
@Search.searchable: true
@ObjectModel.semanticKey: ['approval_number']
define root view entity ZC_APPR_INSTANCE
  provider contract transactional_query
  as projection on ZR_APPR_INSTANCE
{
  key approval_id,

      @Search.defaultSearchElement: true
      approval_number,

      object_type,
      object_key,

      @Search.defaultSearchElement: true
      object_name,

      current_status,
      approver_role,
      approver_level,

      @Search.defaultSearchElement: true
      description,
      justification,

      requested_by,
      requested_at,

      decided_by,
      decided_at,
      decision_comment,

      StatusText,
      StatusCriticality,

      created_by,
      created_at,
      last_changed_by,
      last_changed_at,
      local_last_changed,

      _Step : redirected to composition child ZC_APPR_STEP
}
