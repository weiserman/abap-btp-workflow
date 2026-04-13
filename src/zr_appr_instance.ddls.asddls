@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Instance'
define root view entity ZR_APPR_INSTANCE
  as select from zappr_instance
  composition [0..*] of ZR_APPR_STEP as _Step
{
  key approval_id,

      approval_number,

      object_type,
      object_key,
      object_name,

      current_status,
      approver_role,
      approver_level,

      description,
      justification,
      requested_by,
      requested_at,

      decided_by,
      decided_at,
      decision_comment,

      case current_status
        when 'DR' then 'Draft'
        when 'SB' then 'Submitted'
        when 'AP' then 'Approved'
        when 'RJ' then 'Rejected'
        when 'WD' then 'Withdrawn'
        else 'Unknown'
      end                          as StatusText,

      case current_status
        when 'DR' then 0
        when 'SB' then 2
        when 'AP' then 3
        when 'RJ' then 1
        when 'WD' then 0
        else 0
      end                          as StatusCriticality,

      @Semantics.user.createdBy: true
      created_by,
      @Semantics.systemDateTime.createdAt: true
      created_at,
      @Semantics.user.lastChangedBy: true
      last_changed_by,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed,

      _Step
}
