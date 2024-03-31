# Terraform AWS EKS AFT

This repository contains a Terraform module for provisioning an Amazon Elastic Kubernetes Service (EKS) cluster along with necessary addons using Karpenter as the provisioner. The addons included are:
- CoreDNS
- kube-proxy
- vpc-cni
- aws-ebs-csi-driver

## Prerequisites
- [Terraform](https://www.terraform.io/) installed.
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed.
- [Helm](https://helm.sh/docs/intro/install/) installed.

## Usage
1. Clone this repository:
    ```bash
    git clone https://github.com/yanivzl/terraform-aws-eks-aft.git
    ```

2. Create a Terraform configuration file (e.g., `main.tf`) in your project and use the module:
    ```terraform
    module "terraform-aws-eks-aft" {
      source = "./terraform-aws-eks-aft"
      
      # Specify variables as needed
      cluster_name          = var.cluster_name
      region                = var.region
      vpc_cidr              = var.vpc_cidr
      cluster_version       = var.cluster_version
      node_group_name       = var.node_group_name
      node_group_min_size   = var.node_group_min_size
      node_group_max_size   = var.node_group_max_size
      node_group_desired_size = var.node_group_desired_size
      environment           = var.environment
    }
    ```

3. Initialize Terraform and apply the configuration:
    ```bash
    terraform init
    terraform apply
    ```

## Configuration Options
- You can customize the EKS cluster configuration by providing values for variables defined in `variables.tf`.

## Inputs

| Input Name                 | Description                                   | Default Value    |
|-----------------------------|-----------------------------------------------|------------------|
| cluster_name            | The name of environment Infrastructure, this name is used for vpc and eks cluster.                           | eks-aft-yanivzl                     |
| region            | AWS Region                           | us-east-1                     |
| vpc_cidr           | CIDR block for VPC                            | 10.0.0.0/16                     |
| cluster_version           | The Version of Kubernetes to deploy                            | 1.29                     |
| node_group_name           | node groups name                            | managed-node-group                     |
| node_group_min_size           | Min size of the initial node group                            | 1                     |
| node_group_max_size           | Max size of the initial node group                            | 5                     |
| node_group_desired_size           | Desired size of the initial node group                            | 2                     |
| environment           | Environment of the deployment - just for tags                            | Development                     |

## Outputs

| Output Name                 | Description                                   |
|-----------------------------|-----------------------------------------------|
| configure_kubectl           | Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
| eks_cluster_name            | Name of the cluster                           |
| eks_cluster_public_subnet_ids | List of public subnets IDs                   |
| eks_cluster_private_subnet_ids | List of private subnets IDs                 |
| eks_cluster_sg_id           | Security Group ID                             |
| eks_iam_role_arn           | EKS IAM Role                                  |

