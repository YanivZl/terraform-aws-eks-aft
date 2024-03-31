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

## Tests

### Jenkins Setup for EBS Controller Tests

#### Preparation
1. Create a namespace for Jenkins:
    ```bash
    kubectl create ns jenkins
    ```

2. Apply service account configuration:
    ```bash
    kubectl apply -f jenkins-sa.yaml -n jenkins
    ```

3. Apply cluster role:
    ```bash
    kubectl apply -f jenkins-cluster-role.yaml
    ```

4. Apply cluster role binding:
    ```bash
    kubectl apply -f jenkins-cluster-role-binding.yaml
    ```

#### Jenkins Release
1. Add Jenkins Helm repository:
    ```bash
    helm repo add jenkinsci https://charts.jenkins.io
    helm repo update
    ```

2. Install Jenkins:
    ```bash
    helm install jenkins -n jenkins -f jenkins-chart-values.yaml jenkinsci/jenkins
    ```

#### Validation
1. Verify that the jenkins-pvc is automatically bound to PV via the EBS Controller.
2. Connect to Jenkins using port forwarding:
    ```bash
    kubectl port-forward svc/jenkins -n jenkins 8080:8080
    ```

3. Access Jenkins on your browser at `http://localhost:8080`.

### Karpenter Testing

#### Preparation
1. Navigate to the test-karpenter directory:
    ```bash
    cd tests/test-karpenter
    ```

2. Apply the inflate.yaml manifest:
    ```bash
    kubectl apply -f inflate.yaml
    ```

#### Test Scenarios
1. Scale up the deployment `inflate` to 20 replicas:
    ```bash
    kubectl scale deployment inflate --replicas 20
    ```

2. Scale down the deployment `inflate` to 0 replicas:
    ```bash
    kubectl scale deployment inflate --replicas 0
    ```