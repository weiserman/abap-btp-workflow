@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Approval Instance Context - Projection'
@Metadata.allowExtensions: true
define view entity ZC_APPR_INSTANCE_CTX
  as projection on ZR_APPR_INSTANCE_CTX
{
      @EndUserText.label: 'Approval ID'
  key approval_id,

      @EndUserText.label: 'Field Name'
  key field_name,

      @EndUserText.label: 'Field Value'
      field_value,

      _Instance : redirected to parent ZC_APPR_INSTANCE
}
