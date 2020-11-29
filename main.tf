terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  region  = "us-west-1"
}

resource "aws_vpc" "vpc_terraform_jcas" {
  cidr_block           = "172.31.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terraform_jcas"
  }
}
# Public subnet
resource "aws_subnet" "public_subnet_terraform_jcas_us_west_1a" {
  vpc_id            = aws_vpc.vpc_terraform_jcas.id
  cidr_block        = "172.31.1.0/24"
  availability_zone = "us-west-1a"
map_public_ip_on_launch = true
  tags = {
    "Name" = "public_subnet-terraform-jcas-us-west-1a"
  }
  depends_on = [aws_vpc.vpc_terraform_jcas]
}
# Private subnet
resource "aws_subnet" "subnet_terraform_jcas_us_west_1b" {
  vpc_id            = aws_vpc.vpc_terraform_jcas.id
  cidr_block        = "172.31.2.0/24"
  availability_zone = "us-west-1b"
  tags = {
    "Name" = "subnet-terraform-jcas-us-west-1b"
  }
  depends_on = [aws_vpc.vpc_terraform_jcas]
}
# Internet gateway
resource "aws_internet_gateway" "internet-gateway-terraform-jcas" {
  vpc_id = aws_vpc.vpc_terraform_jcas.id
  tags = {
    Name = "internet-gateway-terraform-jcas"
  }
  depends_on = [aws_vpc.vpc_terraform_jcas]
}

# Route table
resource "aws_route_table" "terraform-public-rt" {
    vpc_id = aws_vpc.vpc_terraform_jcas.id
    
    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0" 
        //CRT uses this IGW to reach internet
        gateway_id = aws_internet_gateway.internet-gateway-terraform-jcas.id 
    }
    
    tags = {
        Name = "terraform-public-rt"
    }
}

resource "aws_route_table_association" "terraform-crta-public-subnet-1"{
    subnet_id = aws_subnet.public_subnet_terraform_jcas_us_west_1a.id
    route_table_id = aws_route_table.terraform-public-rt.id
}

# Security Group
resource "aws_security_group" "sg-terraform-ssh-allowed" {
    vpc_id = aws_vpc.vpc_terraform_jcas.id
    
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        // This means, all ip address are allowed to ssh ! 
        // Do not do it in the production. 
        // Put your office or home address in it!
        cidr_blocks = ["0.0.0.0/0"]
    }
    //If you do not add this rule, you can not reach the NGIX  
    ingress {
        from_port = 3000
        to_port = 3000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "sg-terraform-ssh-allowed"
    }
}

resource "aws_key_pair" "auth" {
#   key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "web" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    type = "ssh"
    # The default username for our AMI
    user = "ubuntu"
    host = self.public_ip
    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = var.ec2_amis.us-west-1

  # The name of our SSH keypair we created above.
  key_name = aws_key_pair.auth.id

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = [aws_security_group.sg-terraform-ssh-allowed.id]

  subnet_id = aws_subnet.public_subnet_terraform_jcas_us_west_1a.id

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo snap install docker",
      "sudo docker run -d -p 3000:3000 --name metabase metabase/metabase",
    ]
  }
}