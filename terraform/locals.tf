# Resource control policy requiring specific storage class in tagged S3 buckets
# github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering
# GPLv3, Copyright Paul Marcelin

locals {
  module_directory = basename(path.module)
  rcp_scp_tags = merge(
    {
      terraform = "1"
      source    = "https://github.com/sqlxpert/aws-rcp-s3-require-intelligent-tiering/blob/main/${local.module_directory}"
      rights    = "GPLv3. Copyright Paul Marcelin."
    },
    var.rcp_scp_tags,
  )

  generate_scp = (length(var.scp_principal_condition) > 0)
}
