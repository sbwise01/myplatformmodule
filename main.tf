locals {
  platform_name = "${var.platform_name}-eks-${random_string.suffix.result}"
  tags = {
    Name        = var.platform_name
    Terraform   = "true"
    Environment = "poc"
  }
  eks_map_accounts = list(data.aws_caller_identity.current.account_id)
}

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 4
  special = false
}

module "vpc" {
  source = "git@github.com:terraform-aws-modules/terraform-aws-vpc.git?ref=v3.6.0"

  name = var.platform_name
  cidr = "10.11.0.0/16"
  azs  = var.zones

  private_subnets = ["10.11.0.0/24", "10.11.1.0/24", "10.11.2.0/24"]
  public_subnets  = ["10.11.3.0/24", "10.11.4.0/24", "10.11.5.0/24"]

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.platform_name}" = "shared"
    "kubernetes.io/role/elb"                       = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.platform_name}" = "shared"
    "kubernetes.io/role/internal-elb"              = "1"
  }

  enable_nat_gateway = true

  tags = local.tags
}

data "aws_eks_cluster" "eks" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  alias                  = "eks"
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.eks.token
  load_config_file       = false
  version                = "1.11.1"
}

module "eks" {
  source = "git@github.com:terraform-aws-modules/terraform-aws-eks.git?ref=v9.0.0"

  providers = {
    kubernetes = kubernetes.eks
  }

  manage_aws_auth             = true
  cluster_name                = local.platform_name
  subnets                     = module.vpc.private_subnets
  vpc_id                      = module.vpc.vpc_id
  cluster_version             = "1.18"
  map_roles                   = var.map_roles
  workers_additional_policies = var.workers_additional_policies

  worker_groups = [
    {
      instance_type         = "c5.large"
      disk_size             = "5Gi"
      asg_desired_capacity  = 3
      asg_min_size          = 3
      asg_max_size          = 3
      autoscaling_enabled   = false
      protect_from_scale_in = false
    },
  ]

  workers_group_defaults = {
    tags = [
      {
        key                 = "k8s.io/cluster-autoscaler/enabled"
        value               = "true"
        propagate_at_launch = true
      },
      {
        key                 = "k8s.io/cluster-autoscaler/${local.platform_name}"
        value               = "true"
        propagate_at_launch = true
      }
    ]
  }

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  map_accounts = local.eks_map_accounts
  create_eks   = true
  enable_irsa  = true

  tags = merge(local.tags, map("kubernetes.io/cluster/${local.platform_name}", "shared"))
}
