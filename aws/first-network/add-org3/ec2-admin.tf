locals {
    docker_network="hyperledger"
}

##################################################
# EC2 for admin
##################################################
resource "null_resource" "add-org3-provisioner" {

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = "${file(lookup(var.ec2_key_path, "private"))}"
		host = "${var.admin_ec2_public_ip}"
	}

	provisioner "file" {
		source = "./channel-artifact.json"
		destination = "/tmp/channel-artifact.json"
	}

	provisioner "file" {
		source = "./add-org3.sh"
		destination = "/tmp/add-org3.sh"
	}

	provisioner "remote-exec" {
		inline = [
        "chmod +x /tmp/add-org3.sh; docker exec cli ./add-org3.sh",
    	] 
	}
}
