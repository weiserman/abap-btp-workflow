@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Step - Projection'
@Metadata.allowExtensions: true
define view entity ZC_APPR_STEP
  as projection on ZR_APPR_STEP
{
  key step_id,
  key approval_id,

      sequence,
      from_status,
      to_status,
      FromStatusText,
      ToStatusText,
      approver_role,
      performed_by,
      performed_at,
      step_comment,

      local_last_changed,

      _Instance : redirected to parent ZC_APPR_INSTANCE
}
