
provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}
//define any environment variables here
locals {
  cluster_name = {
    edge       = "edge-xyz-eks"
    stable     = "stable-xyz-eks"
    production = "prod-xyz-eks"
  }
  vpc_name = {
    edge       = "edge-xyz-vpc"
    stable     = "stable-xyz-vpc"
    production = "prod-xyz-vpc"
  }
  env_name = {
    edge       = "edge"
    stable     = "stable"
    production = "prod"
  }
}

terraform {
  backend "s3" {
    region = "us-east-1"
    bucket = "terraform-xyz"
  }
}
//VPC set up to have seperate environments for clusters in a quick set up. Ideally this would point to different AWS accounts
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = local.vpc_name[terraform.workspace]

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name[terraform.workspace]}" = "shared"
    "kubernetes.io/role/elb"                                           = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name[terraform.workspace]}" = "shared"
    "kubernetes.io/role/internal-elb"                                  = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.5.1"

  cluster_name    = local.cluster_name[terraform.workspace]
  cluster_version = "1.26"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1${local.env_name[terraform.workspace]}"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }

    two = {
      name = "node-group-2${local.env_name[terraform.workspace]}"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.18.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}

resource "aws_ecr_repository" "eks_example_app" {
  name                 = "eks-example-app-${local.env_name[terraform.workspace]}"
  image_tag_mutability = "MUTABLE"
  tags = {
    "name"    = "eks-example-app-${local.env_name[terraform.workspace]}",
    "cluster" = local.cluster_name[terraform.workspace]
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_s3_bucket" "terraform-xyz" {
}