#Setting terraform providers

provider "aws" {
  region     = var.region
  access_key = "AKIARBT534H7DVGPCJO6"
  secret_key = "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"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}