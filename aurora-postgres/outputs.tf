output "database_url" {
    value = "postgresql://${var.dbuser}:${var.dbpasswd}@${aws_rds_cluster.postgresql.endpoint}/${var.dbname}"
}

output "vpc_id" {
    value = aws_vpc.vpc.id
}

output "vpc_security_group_id" {
    value = aws_security_group.default.id
}

output "pubsubnet_one" {
    value = aws_subnet.pub_subnet_one.id
}

output "pubsubnet_two" {
    value = aws_subnet.pub_subnet_two.id
}
