variable "region" {
  default     = "us-east-2"
  description = "AWS Region"
}

variable "cluster_name" {
  type = string
  default = "cluster"
}