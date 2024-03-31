locals {
  num_of_subnets = min(length(data.aws_availability_zones.available.names), 2)
  azs            = slice(data.aws_availability_zones.available.names, 0, local.num_of_subnets)

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}