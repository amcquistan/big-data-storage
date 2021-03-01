
variable "region" {
  default = "us-east-2"
}

variable "redshift_id" {
  default = "redshift-demo"
}

variable "redshift_dbname" {}
variable "redshift_dbuser" {
  default = "redshift"
}
variable "redshift_dbpasswd" {}
variable "redshift_dbport" {
  default = "5439"
}

variable "postgres_dbhost" {}
variable "postgres_dbname" {}
variable "postgres_dbuser" {}
variable "postgres_dbpasswd" {}
variable "postgres_dbport" {
  default = "5432"
}


variable "cluster_type" {
   # single-node
   # multi-node
  default = "single-node"
}

variable "node_count" {
  default = 1
}

variable "node_type" {
  # dc2.large
  # dc2.8xlarge
  # ra3.xplus
  # ra3.4xlarge
  # ra3.16xlarge
  default = "dc2.large"
}

variable "redshift_policy_arns" {
  default = [
      "arn:aws:iam::aws:policy/AmazonRedshiftFullAccess",
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
}

variable "redshift_subnet_ids" {}
variable "skip_final_snapshot" {
  default = false
}

variable "vpc_id" {}
variable "vpc_security_group_id" {
  default = []
}
variable "redshift_cidr" {}

variable etl_script_s3_key {
  default = "scripts/etl.py"
}

variable "local_etl_script_path" {
  default = "scripts/etl.py"
}

variable "glue_policy_arns" {
    default = [
        "arn:aws:iam::aws:policy/AmazonS3FullAccess",
        "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole",
        "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
    ]
}