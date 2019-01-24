#VPC setup

provider "aws" {
  alias      = "partner-account"
  region     = "${var.region}"
  access_key = "${var.partner_cloud_access_key}"
  secret_key = "${var.partner_cloud_secret_key}"
}

resource "aws_vpc" "vpc" {
  provider   = "aws.partner-account"
  cidr_block = "0.0.0.0/0"
  enable_dns_hostnames= true
  tags {
    Name = "${var.partner}-${var.environment}"
  }
}

resource "aws_security_group" "allow_ssh" {
  provider    = "aws.partner-account"
  name        = "allow_ssh"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "allow_vpn" {
  provider    = "aws.partner-account"
  name        = "allow_vpn"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#creating the route table
resource "aws_route_table" "private" {
  provider = "aws.partner-account"
  vpc_id   = "${aws_vpc.vpc.id}"

  route{
    cidr_block="0.0.0.0/0"
    nat_gateway_id="${aws_nat_gateway.GatewayPublicSubnet1.id}"
  }
  lifecycle{
    ignore_changes=["route"]
  }
  tags {
    Name = "${var.partner}-${var.environment}/private"
  }
}

resource "aws_route_table" "public" {
  provider = "aws.partner-account"
  vpc_id   = "${aws_vpc.vpc.id}"
  lifecycle{
    ignore_changes=["route"]
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "${var.partner}-${var.environment}/public"
  }
}

resource "aws_route_table_association" "public_subnet_1" {
  provider       = "aws.partner-account"
  subnet_id      = "${aws_subnet.PublicSubnet1.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public_subnet_2" {
  provider       = "aws.partner-account"
  subnet_id      = "${aws_subnet.PublicSubnet2.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private_subnet_1" {
  provider       = "aws.partner-account"
  subnet_id      = "${aws_subnet.PrivateSubnet1.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "private_subnet_2" {
  provider       = "aws.partner-account"
  subnet_id      = "${aws_subnet.PrivateSubnet2.id}"
  route_table_id = "${aws_route_table.private.id}"
}



data "aws_availability_zones" "available" {
  provider = "aws.partner-account"
}

#create private subnets

resource "aws_subnet" "PrivateSubnet1" {
  provider          = "aws.partner-account"
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  cidr_block        = "0.0.0.0/0"

  tags {
    Name = "${var.partner}-${var.environment}/private1"
  }
}

resource "aws_subnet" "PrivateSubnet2" {
  provider          = "aws.partner-account"
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  cidr_block        = "0.0.0.0/0"

  tags {
    Name = "${var.partner}-${var.environment}/private2"
  }
}

resource "aws_subnet" "PublicSubnet1" {
  provider          = "aws.partner-account"
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  cidr_block        = "0.0.0.0/0"

  tags {
    Name = "${var.partner}-${var.environment}/public1"
  }
}

resource "aws_subnet" "PublicSubnet2" {
  provider          = "aws.partner-account"
  vpc_id            = "${aws_vpc.vpc.id}"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  cidr_block        = "0.0.0.0/0"

  tags {
    Name = "${var.partner}-${var.environment}/public2"
  }
}

resource "aws_eip" "Nat_EIP_PublicSubnet1" {
  provider = "aws.partner-account"
  vpc      = true

  tags {
    Name = "${var.partner}-${var.environment}/nat1"
  }
}

resource "aws_eip" "Nat_EIP_PublicSubnet2" {
  provider = "aws.partner-account"
  vpc      = true

  tags {
    Name = "${var.partner}-${var.environment}/nat2"
  }
}

resource "aws_nat_gateway" "GatewayPublicSubnet1" {
  provider      = "aws.partner-account"
  allocation_id = "${aws_eip.Nat_EIP_PublicSubnet1.id}"
  subnet_id     = "${aws_subnet.PublicSubnet1.id}"

  tags {
    Name = "${var.partner}-${var.environment}/natgw1"
  }
}

resource "aws_internet_gateway" "gw" {
  provider = "aws.partner-account"
  vpc_id   = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.partner}-${var.environment}/igw"
  }
}

resource "aws_nat_gateway" "GatewayPublicSubnet2" {
  provider      = "aws.partner-account"
  allocation_id = "${aws_eip.Nat_EIP_PublicSubnet2.id}"
  subnet_id     = "${aws_subnet.PublicSubnet2.id}"

  tags {
    Name = "${var.partner}-${var.environment}/natgw2"
  }
}

resource "aws_key_pair" "ssh_key" {
  provider   = "aws.partner-account"
  key_name   = "${var.partner}-${var.environment}"
  public_key = "${var.ssh_public_key}"
}
