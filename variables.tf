variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "namespace" {
  description = "Namespace, which could be your organization name or abbreviation, e.g. 'co' or 'company'"
}

variable "stage" {
  description = "Stage, e.g. 'prod', 'staging', 'dev'"
}

variable "region" { }

variable "vpc" {
  description = "VPC ID where to deploy the instances"
}

variable "subnet" {
  description = "Subnet ID where to deploy the instances."
}

variable "core_instance_type" {
  description = "Core nodes instance type"
}

variable "replica_instance_type" {
  description = "Replica nodes instance type"
}

variable "core_count" {
  description = "How many core nodes to deploy. At least 3"
  default = "3"
}

variable "replica_count" {
  description = "How many replica nodes to deploy. At least 3 is recommended"
  default = "3"
}

variable "ssh_key_pair" {
  description = "EC2 SSH key name to manage the instances"
}

variable "version" {
  description = "Neo4j version (3.5.x)."
  default = "3.5.2"
}

variable "storage_size" {
  description = "Neo4j nodes storage size (GB)"
  default     = 10
}

variable "initial_password" {
  description = "Define initial Neo4j password"
  default = "Neo4jPassword"
}

