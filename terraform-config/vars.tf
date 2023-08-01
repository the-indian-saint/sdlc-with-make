variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "cluster-name" {
  type    = string
  default = "coding-challenge-cluster"
}

variable "vpc-name" {
  type    = string
  default = "coding-challenge-vpc"
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    min_size       = number
    max_size       = number
    desired_size   = number
  }))

  default = {
    one = {
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }

    two = {
      instance_types = ["t3.small"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
    }
  }
}
