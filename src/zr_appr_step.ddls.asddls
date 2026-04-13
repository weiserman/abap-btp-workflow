@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Step'
define view entity ZR_APPR_STEP
  as select from zappr_step
  association to parent ZR_APPR_INSTANCE as _Instance
    on $projection.approval_id = _Instance.approval_id
{
  key step_id,
  key approval_id,

      sequence,
      from_status,
      to_status,

      case from_status
        when 'DR' then 'Draft'
        when 'SB' then 'Submitted'
        when 'AP' then 'Approved'
        when 'RJ' then 'Rejected'
        when 'WD' then 'Withdrawn'
        else ''
      end                          as FromStatusText,

      case to_status
        when 'DR' then 'Draft'
        when 'SB' then 'Submitted'
        when 'AP' then 'Approved'
        when 'RJ' then 'Rejected'
        when 'WD' then 'Withdrawn'
        else ''
      end                          as ToStatusText,

      approver_role,
      performed_by,
      performed_at,
      step_comment,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed,

      _Instance
}
