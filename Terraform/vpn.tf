provider "template" {}

data "template_file" "vpn_data" {
  template = "${file("vpn_aws.yaml")}"

  vars {
    vpn_elastic_ip_id      = "${aws_eip.vpn_eip.id}"
    public_route_table_id  = "${aws_route_table.public.id}"
    private_route_table_id = "${aws_route_table.private.id}"
    region                 = "${var.region}"
    environment            = "${var.environment}"
    partner                = "${var.partner}"
  }
}

resource "aws_iam_role" "vpn_role" {
  provider = "aws.partner-account"
  name     = "${var.partner}-${var.environment}-vpn-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "vpn_role_policy" {
  provider    = "aws.partner-account"
  name        = "${var.partner}-${var.environment}-vpn-policy"
  path        = "/"
  description = "partner vpn policy"

  policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Action": [
      "ec2:Describe*",
      "ec2:AssociateAddress",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:ModifyInstanceAttribute"
    ],
    "Effect": "Allow",
    "Resource": "*"
  }
]
}
EOF
}

resource "aws_iam_role_policy_attachment" "vpn" {
  provider   = "aws.partner-account"
  role       = "${aws_iam_role.vpn_role.name}"
  policy_arn = "${aws_iam_policy.vpn_role_policy.arn}"
}

resource "aws_iam_instance_profile" "vpn" {
  provider = "aws.partner-account"
  name     = "${var.partner}-${var.environment}-vpn"
  role     = "${aws_iam_role.vpn_role.name}"
}

resource "aws_eip" "vpn_eip" {
  provider = "aws.partner-account"
  vpc      = true

  tags {
    Name = "${var.partner}-${var.environment}/vpn"
  }
}

data "aws_ami" "trusty_ami" {
  provider    = "aws.partner-account"
  most_recent = true

  filter {
    name   = "owner-id"
    values = ["099720109477"]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/*/ubuntu-trusty-14.04-amd64-server-*"]
  }
}

resource "aws_launch_template" "vpn" {
  provider      = "aws.partner-account"
  image_id      = "${data.aws_ami.trusty_ami.id}"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.ssh_key.key_name}"
  user_data     = "${base64encode(data.template_file.vpn_data.rendered)}"

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = ["${aws_security_group.allow_ssh.id}", "${aws_security_group.allow_vpn.id}"]
  }

  iam_instance_profile {
    name = "${aws_iam_instance_profile.vpn.name}"
  }

  tag_specifications {
    resource_type = "instance"

    tags {
      Name = "${var.partner}-${var.environment}/vpn"
    }
  }
}

resource "aws_autoscaling_group" "vpn_asg" {
  provider            = "aws.partner-account"
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  name                = "${var.partner}-${var.environment}/vpn"
  vpc_zone_identifier = ["${aws_subnet.PublicSubnet1.id}", "${aws_subnet.PublicSubnet2.id}"]

  launch_template = {
    id      = "${aws_launch_template.vpn.id}"
    version = "$$Latest"
  }
}
