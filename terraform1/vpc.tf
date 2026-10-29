resource "aws_vpc" "main" {
	cidr_block           = "10.0.0.0/16"
	enable_dns_support   = true
	enable_dns_hostnames = true
	tags = {
		Name = "petclinic-vpc"
	}
}

resource "aws_subnet" "public" {
	for_each = {
		"ap-southeast-1a" = "10.0.0.0/24"
		"ap-southeast-1b" = "10.0.1.0/24"
	}
	vpc_id                  = aws_vpc.main.id
	availability_zone       = each.key
	cidr_block              = each.value
	map_public_ip_on_launch = true
	tags = {
		Name                                       = "petclinic-public-subnet-${each.key}"
		"kubernetes.io/role/elb"                   = "1"
		"kubernetes.io/cluster/petclinic-cluster"  = "shared"
	}
}

resource "aws_subnet" "private" {
	for_each = {
		"ap-southeast-1a" = "10.0.10.0/24"
		"ap-southeast-1b" = "10.0.11.0/24"
	}
	vpc_id            = aws_vpc.main.id
	availability_zone = each.key
	cidr_block        = each.value
	tags = {
		Name = "petclinic-private-subnet-${each.key}"
	}
}

resource "aws_internet_gateway" "main" {
	vpc_id = aws_vpc.main.id
	tags = {
		Name = "petclinic-igw"
	}
}

resource "aws_eip" "nat" {
	domain = "vpc"
	tags = {
		Name = "petclinic-nat-eip"
	}
}

resource "aws_nat_gateway" "main" {
	allocation_id = aws_eip.nat.id
	subnet_id     = aws_subnet.public["ap-southeast-1a"].id
	tags = {
		Name = "petclinic-nat"
	}
	depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
	vpc_id = aws_vpc.main.id
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.main.id
	}
	tags = {
		Name = "petclinic-public-rt"
	}
}

resource "aws_route_table_association" "public" {
	for_each       = aws_subnet.public
	subnet_id      = each.value.id
	route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
	vpc_id = aws_vpc.main.id
	route {
		cidr_block     = "0.0.0.0/0"
		nat_gateway_id = aws_nat_gateway.main.id
	}
	tags = {
		Name = "petclinic-private-rt"
	}
}

resource "aws_route_table_association" "private" {
	for_each       = aws_subnet.private
	subnet_id      = each.value.id
	route_table_id = aws_route_table.private.id
}