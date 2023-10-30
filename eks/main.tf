# terraform {
#   required_version = ">=1.3.7"
#   required_providers {
#     aws = {
#       source = "registry.terraform.io/hashicorp/aws"
#     }
#   }
# }

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

# data "aws_availability_zones" "available" {
# }

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "ivan-vpc"
  cidr = "10.0.0.0/16"

  azs                  = ["us-east-2a", "us-east-2b"]
  private_subnets      = ["10.0.1.0/24","10.0.2.0/24"]
  public_subnets      = ["10.0.3.0/24","10.0.4.0/24"]
  enable_dns_hostnames = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpn_gateway   = true
  create_igw           = true

  tags = {
    Terraform   = "true"
    Environment = "kubernetes"
  }
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [
      "10.0.0.0/16"
    ]

  }

}
 

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.27"

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

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

  }
  cluster_additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
  vpc_id                                = module.vpc.vpc_id
  subnet_ids                            = module.vpc.private_subnets

  eks_managed_node_groups = {
    one = {
      name          = "worker-group"
      max_size      = 2
      min_size      = 1
      desired_size  = 1
      instance_type = ["t2.micro"]

    }
  }


  # aws-auth configmap
  # create = true
  create_aws_auth_configmap = false
  manage_aws_auth_configmap = true

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::072204673534:user/ivan-iam"
      username = "ivan-iam"
      groups   = ["system:masters"]
    }
  ]

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}


resource "kubernetes_deployment" "example" {
  metadata {
    name = "terraform-example"
    labels = {
      test = "MyExampleApp"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        test = "MyExampleApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "MyExampleApp"
        }
      }

      spec {
        container {
          image = "nginx:1.7.8"
          name  = "example"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "example" {
  metadata {
    name = "terraform-example"
  }
  spec {
    selector = {
      test = "MyExampleApp"
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}