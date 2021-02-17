output "database_url" {
    value = "postgresql://${var.dbuser}:${var.dbpasswd}@${aws_rds_cluster.postgresql.endpoint}/${var.dbname}"
}
