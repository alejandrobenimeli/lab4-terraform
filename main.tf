provider "aws" {
  region = "eu-west-1"
}

resource "aws_instance" "name" {
  ami = ""
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-ec2"
    env = "prod"
  }
}