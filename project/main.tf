provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}



resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

}


resource "aws_route_table_association" "rsa1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rsa2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt.id
}



resource "aws_security_group" "seqg" {
  name   = "seq"
  vpc_id = aws_vpc.myvpc.id



  # Ingress rule allowing HTTP (port 80) traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule allowing SSH (port 22) traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule allowing all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_s3_bucket" "example" {
  bucket = "mytftestbucket2042"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_instance" "ints1" {
  ami                    = "ami-0b8b44ec9a8f90422"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.seqg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data              = base64encode(file("userdata.sh"))

}

resource "aws_instance" "ints2" {
  ami                    = "ami-0b8b44ec9a8f90422"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.seqg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data              = base64encode(file("userdata1.sh"))

}

resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.seqg.id]
  subnets            = [aws_subnet.sub1.id ,aws_subnet.sub2.id]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "mytg" {
  name     = "myaalb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.ints1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.ints2.id
  port             = 80
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mytg.arn
  }
}

output "name" {
  value = aws_lb.myalb.dns_name
}