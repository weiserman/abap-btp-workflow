@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Step - Projection'
@Metadata.allowExtensions: true
define view entity ZC_APPR_STEP
  as projection on ZR_APPR_STEP
{
      @EndUserText.label: 'Step ID'
  key step_id,

      @EndUserText.label: 'Approval ID'
  key approval_id,

      @EndUserText.label: 'Step #'
      sequence,

      @EndUserText.label: 'From Status'
      from_status,

      @EndUserText.label: 'To Status'
      to_status,

      @EndUserText.label: 'From Status'
      FromStatusText,

      @EndUserText.label: 'To Status'
      ToStatusText,

      @EndUserText.label: 'Approver Role'
      approver_role,

      @EndUserText.label: 'Performed By'
      performed_by,

      @EndUserText.label: 'Performed At'
      performed_at,

      @EndUserText.label: 'Comment'
      step_comment,

      local_last_changed,

      _Instance : redirected to parent ZC_APPR_INSTANCE
}
