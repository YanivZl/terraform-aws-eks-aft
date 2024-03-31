variable "cluster_name" {
  description = "The name of environment Infrastructure, this name is used for vpc and eks cluster."
  type        = string
  default     = "eks-aft-yanivzl"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "The Version of Kubernetes to deploy"
  type        = string
  default     = "1.29"
}

# Intial node group configuration

variable "node_group_name" {
  description = "node groups name"
  type        = string
  default     = "managed-node-group"
}

variable "node_group_min_size" {
  description = "Min size of the initial node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Max size of the initial node group"
  type        = number
  default     = 5
}

variable "node_group_desired_size" {
  description = "Desired size of the initial node group"
  type        = number
  default     = 2
}

variable "environment" {
  description = "Environment of the deployment - just for tags"
  type        = string
  default     = "Development"
}

