output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}

output "opensearch_security_group_id" {
  value = aws_security_group.opensearch.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

