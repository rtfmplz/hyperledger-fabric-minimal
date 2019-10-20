#################################################
# VPC
# - 본 예제에서 NACL는 생성하지 않았는데, 기본으로 생성된다.
#################################################
resource "aws_vpc" "vpc" {
  cidr_block = "${var.vpc_cidr}"

  tags = {
    Name = "${var.vpc_name}"
  }
}
