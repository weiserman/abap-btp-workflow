@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Instance Context'
define view entity ZR_APPR_INSTANCE_CTX
  as select from zappr_inst_ctx
  association to parent ZR_APPR_INSTANCE as _Instance
    on $projection.approval_id = _Instance.approval_id
{
  key approval_id,
  key field_name,

      field_value,

      _Instance
}
