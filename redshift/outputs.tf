output "database_url" {
  value = "postgresql://${var.redshift_dbuser}:${var.redshift_dbpasswd}@${aws_redshift_cluster.redshift.endpoint}/${var.redshift_dbname}"
}

output "s3_bucket" {
  value = aws_s3_bucket.glue_bucket.id
}

output "redshift_iam_role_arn" {
  value = aws_iam_role.redshift.arn
}
