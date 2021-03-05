###################################################################################
# Providers
###################################################################################
provider "aws" {
    region     = var.region
}


###################################################################################
# Data
###################################################################################
data "aws_availability_zones" "available" {}


###################################################################################
# Resources
###################################################################################
resource "aws_vpc" "vpc" {
    cidr_block           = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support   = true
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "pub_subnet_one" {
    cidr_block              = var.pub_subnet_one
    vpc_id                  = aws_vpc.vpc.id
    map_public_ip_on_launch = true
    availability_zone       = data.aws_availability_zones.available.names[0]
    tags = {
        Name    = "public-subnet-one"
        Type    = "public-subnet"
    }
}

resource "aws_subnet" "pub_subnet_two" {
    cidr_block              = var.pub_subnet_two
    vpc_id                  = aws_vpc.vpc.id
    map_public_ip_on_launch = true
    availability_zone       = data.aws_availability_zones.available.names[1] 
    tags = {
        Name    = "public-subnet-two"
        Type    = "public-subnet"
    }
}

resource "aws_route_table" "pub_route_tbl" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "pub_subnet_one_asn" {
    subnet_id       = aws_subnet.pub_subnet_one.id
    route_table_id  = aws_route_table.pub_route_tbl.id 
}

resource "aws_route_table_association" "pub_subnet_two_asn" {
    subnet_id       = aws_subnet.pub_subnet_two.id
    route_table_id  = aws_route_table.pub_route_tbl.id 
}

resource "aws_security_group" "default" {
    name       = "ecs-dev-vpc-default-sg"
    vpc_id     = aws_vpc.vpc.id
    depends_on = [ aws_vpc.vpc ]
    ingress {
        from_port = "0"
        to_port   = "0"
        protocol  = "-1"
        self      = true
    }
    egress {
        from_port = "0"
        to_port   = "0"
        protocol  = "-1"
        self      = true
    }
}

resource "aws_security_group" "postgres" {
    name         = "postgres_sg"
    description  = "Allow access to Aurora Postgres RDS"
    vpc_id       = aws_vpc.vpc.id

    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0", aws_vpc.vpc.cidr_block]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_db_subnet_group" "db_subnet" {
    name     = "aurora-pg-subnet"
    subnet_ids = [aws_subnet.pub_subnet_one.id, aws_subnet.pub_subnet_two.id]
}

resource "aws_vpc_endpoint" "s3" {
    vpc_id       = aws_vpc.vpc.id
    service_name = "com.amazonaws.${var.region}.s3"
}

resource "aws_vpc_endpoint_route_table_association" "route_tbl_assoc" {
  route_table_id  = aws_route_table.pub_route_tbl.id 
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_iam_role" "rds_s3" {
    assume_role_policy = jsonencode({
        Version   = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Sid    = ""
                Principal = {
                    Service = "rds.amazonaws.com"
                }
            }
        ]
    })
    path         = "/"
}

resource "aws_iam_role_policy_attachment" "rds_managed_policies" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    role       = aws_iam_role.rds_s3.name
}

resource "aws_rds_cluster" "postgresql" {
    cluster_identifier              = "oltp-olap-pagila-db"
    engine                          = var.engine
    engine_version                  = var.engine_version
    database_name                   = var.dbname
    master_username                 = var.dbuser
    master_password                 = var.dbpasswd
    backup_retention_period         = var.backup_retention_period
    preferred_backup_window         = var.preferred_backup_window
    enabled_cloudwatch_logs_exports = [ "postgresql" ]
    # iam_roles                       = [ aws_iam_role.rds_s3.arn ]
    port                            = "5432"
    db_subnet_group_name            = aws_db_subnet_group.db_subnet.name
    vpc_security_group_ids          = [aws_security_group.postgres.id]
    skip_final_snapshot             = var.skip_final_snapshot

    lifecycle {
        ignore_changes = [ iam_roles ]
    }

    provisioner "local-exec" {
        command = "aws rds add-role-to-db-cluster --db-cluster-identifier ${aws_rds_cluster.postgresql.id} --role-arn ${aws_iam_role.rds_s3.arn} --feature-name s3Export --region ${var.region}"
    }
}

resource "aws_rds_cluster_instance" "postgresql_instance" {
    identifier                   = "${aws_rds_cluster.postgresql.cluster_identifier}-instance"
    cluster_identifier           = aws_rds_cluster.postgresql.id
    instance_class               = var.instance_class
    engine                       = aws_rds_cluster.postgresql.engine
    engine_version               = aws_rds_cluster.postgresql.engine_version
    publicly_accessible          = var.publicly_accessible
    db_subnet_group_name         = aws_db_subnet_group.db_subnet.name 
    monitoring_interval          = var.monitoring_interval
    performance_insights_enabled = var.performance_insights_enabled
}

# resource "aws_db_instance_role_association" "s3_export" {
#     db_instance_identifier = aws_rds_cluster_instance.postgresql_instance.identifier
#     feature_name           = "s3Export"
#     role_arn               = aws_iam_role.rds_s3.arn
# }

