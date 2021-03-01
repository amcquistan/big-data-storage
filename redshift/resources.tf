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


locals {
  az_suffixes = ["a", "b", "c"]
}

###################################################################################
# Resources
###################################################################################
resource "aws_iam_role" "redshift" {
    assume_role_policy = jsonencode({
        Version   = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Sid    = ""
                Principal = {
                    Service = "redshift.amazonaws.com"
                }
            }
        ]
    })

    path              = "/"
}

resource "aws_iam_role_policy_attachment" "redshift_managed_policies" {
    count      = length(var.redshift_policy_arns)
    policy_arn = var.redshift_policy_arns[count.index]
    role       = aws_iam_role.redshift.name
}

resource "aws_redshift_subnet_group" "redshift_subnet" {
  name       = "redshift-subnet-group"
  subnet_ids = var.redshift_subnet_ids
}

resource "aws_security_group" "redshift" {
    name         = "redshift_sg"
    description  = "Allow access to Redshift"
    vpc_id       = var.vpc_id

    ingress {
        from_port   = 5439
        to_port     = 5439
        protocol    = "tcp"
        cidr_blocks = [var.redshift_cidr]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_redshift_cluster" "redshift" {
  cluster_identifier        = var.redshift_id
  database_name             = var.redshift_dbname
  master_username           = var.redshift_dbuser
  master_password           = var.redshift_dbpasswd
  node_type                 = var.node_type
  number_of_nodes           = var.node_count
  cluster_type              = var.cluster_type
  port                      = var.redshift_dbport
  skip_final_snapshot       = var.skip_final_snapshot
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_subnet.name
  iam_roles                 = [ aws_iam_role.redshift.arn ]
  vpc_security_group_ids    = [ aws_security_group.redshift.id ]
}

resource "aws_iam_role" "glue_default" {
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Sid    = ""
                Principal = {
                    Service = "glue.amazonaws.com"
                }
            }
        ]
    })

    path              = "/"
}

resource "aws_iam_role_policy_attachment" "glue_managed_policies" {
    count      = length(var.glue_policy_arns)
    policy_arn = var.glue_policy_arns[count.index]
    role       = aws_iam_role.glue_default.name
}

resource "aws_glue_connection" "glue_connection" {
  count           = length(var.redshift_subnet_ids)
  name            = "glue-vpc-connection-${count.index}"
  connection_type = "NETWORK"

  connection_properties = {
    connection_type = "NETWORK"
  }

  physical_connection_requirements {
    availability_zone      = "${var.region}${local.az_suffixes[count.index]}"
    security_group_id_list = [ var.vpc_security_group_id ]
    subnet_id              = var.redshift_subnet_ids[count.index]
  }
}

resource "aws_s3_bucket" "glue_bucket" {
    bucket_prefix = "glue-etl"
    acl           = "private"
    versioning {
        enabled = true
    }
}


resource "aws_s3_bucket_object" "etl_raw_events" {
    bucket   = aws_s3_bucket.glue_bucket.id
    key      = var.etl_script_s3_key
    acl      = "private"
    source   = var.local_etl_script_path
    etag     = filemd5(var.local_etl_script_path)
}

resource "aws_glue_job" "etl" {
    depends_on = [ aws_s3_bucket.glue_bucket, aws_iam_role.glue_default, aws_glue_connection.glue_connection ]
    role_arn          = aws_iam_role.glue_default.arn
    name              = "postgres-to-redshift-etl"
    glue_version      = "1.0"
    max_capacity      = 1
    max_retries       = 2
    timeout           = 10
    default_arguments = {
        "--s3_bucket"                       = aws_s3_bucket.glue_bucket.id
        "--redshift_dbname"                 = var.redshift_dbname
        "--redshift_dbhost"                 = aws_redshift_cluster.redshift.endpoint
        "--redshift_dbport"                 = aws_redshift_cluster.redshift.port
        "--redshift_dbuser"                 = var.redshift_dbuser
        "--redshift_dbpasswd"               = var.redshift_dbpasswd
        "--postgres_dbname"                 = var.postgres_dbname
        "--postgres_dbhost"                 = var.postgres_dbhost
        "--postgres_dbport"                 = var.postgres_dbport
        "--postgres_dbuser"                 = var.postgres_dbuser
        "--postgres_dbpasswd"               = var.postgres_dbpasswd
    }

    # connections = [ for suffix in local.az_suffixes : aws_glue_connection.glue_connection[index(local.az_suffixes, suffix)].id ]
    connections = [ for conn in aws_glue_connection.glue_connection : conn.id ]

    command {
      name            = "pythonshell"
      script_location = "${aws_s3_bucket.glue_bucket.id}/${var.etl_script_s3_key}"
      python_version  = "3"
    }
}

resource "aws_glue_trigger" "etl_tgr" {
    name     = "postgres-to-redshift-etl"
    type     = "SCHEDULED"
    schedule = "cron(1 1 * * ? *)"
    actions {
        job_name = aws_glue_job.etl.name
    }
}
