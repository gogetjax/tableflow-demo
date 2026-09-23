# Isolated consumer network: one private subnet, no IGW, no NAT.
# S3 via gateway endpoint, Glue via interface endpoint. If a consumer works here,
# it provably never reached Confluent.

resource "aws_vpc" "consumers" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "tableflow-demo-consumers" }
}

resource "aws_subnet" "consumers_private" {
  vpc_id            = aws_vpc.consumers.id
  cidr_block        = "10.42.1.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "tableflow-demo-consumers-private" }
}

resource "aws_route_table" "consumers_private" {
  vpc_id = aws_vpc.consumers.id
  tags   = { Name = "tableflow-demo-consumers-private" }
  # No default route on purpose.
}

resource "aws_route_table_association" "consumers_private" {
  subnet_id      = aws_subnet.consumers_private.id
  route_table_id = aws_route_table.consumers_private.id
}

resource "aws_security_group" "consumers" {
  name        = "tableflow-demo-consumers"
  description = "Consumer runs. HTTPS egress inside the VPC only (to interface endpoints and the S3 prefix list)."
  vpc_id      = aws_vpc.consumers.id
  tags        = { Name = "tableflow-demo-consumers" }
}

resource "aws_vpc_security_group_egress_rule" "consumers_https_vpc" {
  security_group_id = aws_security_group.consumers.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = aws_vpc.consumers.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "consumers_https_s3" {
  security_group_id = aws_security_group.consumers.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = aws_vpc_endpoint.s3.prefix_list_id
}

resource "aws_security_group" "endpoints" {
  name        = "tableflow-demo-endpoints"
  description = "Interface endpoints. HTTPS ingress from the consumer SG."
  vpc_id      = aws_vpc.consumers.id
  tags        = { Name = "tableflow-demo-endpoints" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id            = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.consumers.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.consumers.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.consumers_private.id]
  tags              = { Name = "tableflow-demo-s3" }
}

resource "aws_vpc_endpoint" "glue" {
  count               = var.idle ? 0 : 1
  vpc_id              = aws_vpc.consumers.id
  service_name        = "com.amazonaws.${var.region}.glue"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.consumers_private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "tableflow-demo-glue" }
}
