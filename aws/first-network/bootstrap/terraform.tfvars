region = "ap-northeast-2"

docker_network = "hyperledger"

vpc_name = "host_vpc"

vpc_cidr = "10.0.0.0/16"

# ap-northeast-2b에서는 t2.micro instance type 이 지원되지 않음
availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

admin_subnets = "10.0.1.0/24"

private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

public_subnets = ["10.0.201.0/24", "10.0.202.0/24"]

ec2_key_pair_name="KP101"

ecs_ami = {
  ap-northeast-2 = "ami-000fbda700ba8fe9d"
}

