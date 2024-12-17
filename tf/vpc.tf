provider "aws" {
  region = "ap-northeast-2"
}

# https://stackoverflow.com/questions/57099036/terraform-how-to-get-the-vpc-cidr-from-vpc-id

data "aws_vpc" "main" {
  id = module.vpc.vpc_id
}

output "vpc_id" {
  value = data.aws_vpc.main.id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}


resource "aws_eip" "nat" {
  count = 1
  domain = "vpc"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.cluster_name}"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2b", "ap-northeast-2c"]
  private_subnets = ["10.0.0.0/22", "10.0.4.0/22"]
  public_subnets  = ["10.0.100.0/22", "10.0.104.0/22"]

  enable_nat_gateway  = true
  single_nat_gateway  = true
  reuse_nat_ips       = true                    # <= Skip creation of EIPs for the NAT Gateways
  external_nat_ip_ids = "${aws_eip.nat.*.id}"   # <= IPs specified here as input to the module

  enable_dns_hostnames = true
  map_public_ip_on_launch = true
  

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
