# Create a VPC
resource "aws_vpc" "var_vpc" {
  cidr_block       = "172.20.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "ee-vpc"
  }
}

## Creating public Subnet
resource "aws_subnet" "var_subnet1" {

  depends_on = [
    aws_vpc.var_vpc,
  ]

  vpc_id     = aws_vpc.var_vpc.id
  cidr_block = "172.20.10.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"

  tags = {
    Name = "ee-pub-subnet1"
  }
}

##Creating Private subnet
resource "aws_subnet" "var_subnet2" {

  depends_on = [
    aws_vpc.var_vpc,
  ]

  vpc_id     = aws_vpc.var_vpc.id
  cidr_block = "172.20.20.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "ee-pvt-subnet2"
  }
}


##Internet Gateway
resource "aws_internet_gateway" "var_gw" {

  depends_on = [
    aws_vpc.var_vpc,
  ]
  vpc_id = aws_vpc.var_vpc.id

  tags = {
    Name = "ee-igw"
  }
}


##Create route table for internet gateway so it can reach to internet and attach it to VPC.
resource "aws_route_table" "var_r" {
  vpc_id = aws_vpc.var_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.var_gw.id
  }

   tags = {
    Name = "ee-rt"
  }
}


#Route Tabel to be associated to public subnet
resource "aws_route_table_association" "var_rta1" {
  subnet_id      = aws_subnet.var_subnet1.id
  route_table_id = aws_route_table.var_r.id
}


##Creating Elastic IP for nat gateway
resource "aws_eip" "var_ip" {
  vpc      = true
}


##creating NAT Gateway
resource "aws_nat_gateway" "var_natgw" {
  allocation_id = aws_eip.var_ip.id
  subnet_id     = aws_subnet.var_subnet1.id

  tags = {
    Name = "ee-NAT-GW"
  }
}


##Creating route table for nat gateway
resource "aws_route_table" "var_rt_nat_gw" {
  vpc_id = aws_vpc.var_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.var_natgw.id
  }

  tags = {
    Name = "ee-natroute"
  }
}

##Creating connecting private subnet to nat route table.
resource "aws_route_table_association" "var_rta2" {
  subnet_id      =  aws_subnet.var_subnet2.id
  route_table_id = aws_route_table.var_rt_nat_gw.id
}


##Security group for linux machine 1, with ssh and https, http and icmp port allowed
resource "aws_security_group" "var_sglinux1" {
  depends_on = [
    aws_vpc.var_vpc
  ]

  name        = "sglinux1"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.var_vpc.id

  ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "icmp"
    from_port        = 8
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "jenikens port"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "All ports"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "sglinux1"
  }
}




##AWS Key pair
resource "aws_key_pair" "var_keypair" {
  key_name   = "linux"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCCSjKpUeIFVSTFZLcpc4UPxZ1phDDVMoJ5ISx9JKKjq5Qk6SRbXNt8lxgRm+SsZwx2U2DIa5C+eDlviJ4mNCV69Dwjitc/k3Sh8xNvUh03St5yuEwaktzGymmAUcrs1Bk099ggTJhyHMKBhn3PVH1MRD5nIF5hm4tIWTYPiEzvH7HF9/RuQteUL4S7gHg8VfjAF4Z+yHniWQhkqNw8sbRwocRBfPLW/556ZRbUn6Xslt1zW/63Apanr2g9hwVCYHLxPAFi4+yhx3+i1UWaM+w9J5FNisyVhGb0xvExrIaWvqaW0Be9r11Ps09V3FrBNyMGj9gVOZ21YTpQyN31vV8p linux"
}




##Linux machine 1, with Jenkins
resource "aws_instance" "linux1" {
  depends_on = [
    aws_vpc.var_vpc
  ]
	ami = "ami-0567e0d2b4b2169ae"
	instance_type = "t2.nano"
	key_name = aws_key_pair.var_keypair.key_name
  vpc_security_group_ids = [aws_security_group.var_sglinux1.id]
  subnet_id = aws_subnet.var_subnet1.id
	user_data = <<-EOF
		          #! /bin/bash
              mkdir jenkins
              wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
		          sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
		          sudo apt update
		          sudo apt install jenkins
		          sudo systemctl start jenkins
              sudo systemctl status jenkins
              sudo ufw allow 8080
              sudo ufw status

	          EOF
	tags = {
		Name = "linux 1 (Jenkins/ansible)"	
		#Batch = "5AM"
	}
}





##security group for private linux machine.
resource "aws_security_group" "var_sglinux2" {
  depends_on = [
    aws_vpc.var_vpc
  ]

  name        = "sglinux2"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.var_vpc.id

  ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "tomcat port"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  tags = {
    Name = "sglinux2"
  }

}


##Linux machine 2, with tomcat
resource "aws_instance" "linux2" {
  depends_on = [
    aws_vpc.var_vpc
  ]
	ami = "ami-0567e0d2b4b2169ae"
	instance_type = "t2.nano"
	key_name = aws_key_pair.var_keypair.key_name
  vpc_security_group_ids = [aws_security_group.var_sglinux2.id]
  subnet_id = aws_subnet.var_subnet2.id

  ####Create A Tomcat-Specific User and User Group along with installation
	user_data = <<-EOF
		          #! /bin/bash
              mkdir tomcat
              wget http://apache.YourFavoriteMirror.com/tomcat/tomcat-[#]/v[#]/apache-tomcat-[#].tar.gz
		          md5sum apache-tomcat-[#].tar.gz
		          tar xvzf apache-tomcat-[#].tar.gz
		          sudo mv apache-tomcat-[#] /usr/local/example/path/to/tomcat
		          vi ~/.bashrc
              export JAVA_HOME=/usr/lib/path/to/java
              export CATALINA_HOME=/path/to/tomcat
              $CATALINA_HOME/bin/startup.sh
              ps -ef | grep java | grep 8080
              curl -v http://localhost:8080/
              groupadd tomcat  
              useradd -s /sbin/nologin -g tomcat -d /path/to/tomcat tomcat
              passwd tomcat
              chown -R tomcat.tomcat /path/to/tomcat
              chmod 775 /path/to/tomcat/webapps
              iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080
              iptables -t nat -I OUTPUT -p tcp --dport 80 -j REDIRECT --to-ports 8080                                    

	          EOF
	tags = {
		Name = "linux 2 (Tomcat)"	
		#Batch = "5AM"
	}
}


  
