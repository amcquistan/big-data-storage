variable "region" {
  default = "us-east-2"
}
variable "vpc_cidr" {
    default = "10.192.0.0/16"
}
variable "pub_subnet_one" {
    default = "10.192.10.0/24"
}
variable "pub_subnet_two" {
    default = "10.192.20.0/24"
}
variable "dbname" {
    default = "pagila"
}
variable "dbuser" {
    default = "postgres"
}
variable "dbpasswd" {}
variable "instance_class" {
    default = "db.t3.medium"
}
variable "engine" {
    default = "aurora-postgresql"
}
variable "engine_version" {
    default = "11.9"
}
variable "backup_retention_period" {
    default = 1
}
variable "preferred_backup_window" {
    default = "03:00-05:00"
}
variable "publicly_accessible" {
    default = true
}
variable "performance_insights_enabled" {
    default = false
}
variable "monitoring_interval" {
    default = 0
}
variable "skip_final_snapshot" {
    default = true
}