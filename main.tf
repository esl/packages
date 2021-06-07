# -*-hcl-*-
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-central-1"
}

resource "aws_key_pair" "esl_ec2_key_pair" {
  key_name   = "esl_ec2_key_pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCkCEk39P9uPEOjZuYLWYt86Affo8ucEdfwQHoI/HdcSsvLnmFeaOst0K9+9VuKph3ub9ystFk+UPVwIuCdOGY+zVZ7+PsG31Tp1lwyCZjX5cbUFTFtBhVJFwmJwFx8nW9i3ijm/X/l7hcuJhoZlcr6bp0Su0lBhoAvDPeAZUJWHPY5XkOkqEtWEbgW9FMqarHwG+nhF4n+M7dL1KdgopAn3ZIF/KxLrZrGtG7FrwdEEhvMewzanoqUzAVP0PpHJU/qyiqHDdWvRkkYecKq8ee59atKw1zWFS1pdinB4nzs5No5mMkkxr1pio+v4b6lPSIxb29VOuvhfU1lrxSdhyov"
}

data "template_file" "user_data" {
  template = file("cloud-init.yaml")
}

resource "aws_instance" "esl_package_builder" {
  ami           = "ami-0245697ee3e07e755"
  instance_type = "c5.xlarge"
  key_name      = "esl_ec2_key_pair"
  user_data     = data.template_file.user_data.rendered

  root_block_device {
    volume_size = "100"
  }

  tags = {
    Name = "ESLPackageBuilder"
  }
}

output "builder_hostname" {
  value = aws_instance.esl_package_builder.public_dns
}

# resource "aws_s3_bucket" "esl_packages" {
#   bucket = "esl-packages"
#   acl    = "private"

#   tags = {
#     Name = "ESLPackages"
#   }
# }
