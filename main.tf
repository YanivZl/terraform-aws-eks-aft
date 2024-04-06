module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 6, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 6, k + 10)]

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster_name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"                    = var.cluster_name # Enables Karpenter - Don't remove
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = "${var.cluster_name}" # Enables Karpenter - Don't remove
  })
}


################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.20.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  #we uses only 1 security group to allow connection with Fargate, MNG, and Karpenter nodes
  create_node_security_group = false
  eks_managed_node_groups = {
    managed-node-group = {
      node_group_name = var.node_group_name
      instance_types  = ["t3.medium"]

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size
      subnet_ids   = module.vpc.private_subnets

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = "${var.cluster_name}"
  })
}



################################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.14"

  depends_on = [module.eks]

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # Set up necessary IRSA for AWS Load Balancer Controller 
  enable_aws_load_balancer_controller = true
  # Deploy AWS Load Balancer Controller 
  aws_load_balancer_controller = {}
}

# Set up necessary IRSA for Karpenter
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "19.20.0"

  cluster_name                    = module.eks.cluster_name
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  create_iam_role      = false
  iam_role_arn         = module.eks.eks_managed_node_groups["managed-node-group"].iam_role_arn
  irsa_use_name_prefix = false

  tags = local.tags
}

################################################################################
# Karpenter
################################################################################

# 1. Deploys Karpenter controller
resource "helm_release" "karpenter" {
  depends_on       = [module.karpenter]
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "v0.31.3"

  set {
    name  = "settings.aws.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.aws.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.irsa_arn
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.karpenter.instance_profile_name
  }

  set {
    name  = "settings.aws.interruptionQueueName"
    value = module.karpenter.queue_name
  }
}

# 2. Deploys Karpenter Provisioner/NodePool
resource "kubectl_manifest" "karpenter_provisioner" {
  depends_on = [
    helm_release.karpenter
  ]

  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["c5.large","c5a.large", "c5ad.large", "c5d.large", "c6i.large", "t2.medium", "t3.medium", "t3a.medium"]
      limits:
        resources:
          cpu: 1000
      providerRef:
        name: default
      ttlSecondsAfterEmpty: 30
  YAML
}

# 3. Deploys Karpenter AWSNodeTemplate/EC2NodeClass
resource "kubectl_manifest" "karpenter_node_template" {
  depends_on = [
    helm_release.karpenter
  ]

  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML
}


################################################################################
# jenkins
################################################################################

resource "aws_iam_policy" "jenkins_secrets_policy" {
  name        = "JenkinsSecretsPolicy"
  description = "Policy for allowing Jenkins to access AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowJenkinsToGetSecretValues"
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        Resource = "*"
      },
      {
        Sid    = "AllowJenkinsToListSecrets"
        Effect = "Allow"
        Action = "secretsmanager:ListSecrets"
        Resource = "*"
      },
    ]
  })
}

module "irsa_jenkins_ssm" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_policy_arns = {
    policy = aws_iam_policy.jenkins_secrets_policy.arn
  }
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["jenkins:jenkins"]
    }
  }
}