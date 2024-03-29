# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

output "dev" {
  value = "Made with \u2764 by Oracle Developers"
}

output "deploy_id" {
  value = local.deploy_id
}

output "stack_version" {
  value = file("${path.module}/VERSION")
}

output "cpe_address" {
  value = oci_core_instance.cpe_instance[*].public_ip
}

output "ldap_address" {
  value = "${oci_core_instance.ldap_instance.0.private_ip}:389"
}

output "ldap_admin_password" {
  value = random_password.ldap_admin_password.result
  sensitive = true
}

### Important Security Notice ###
# The private key generated by this resource will be stored unencrypted in your Terraform state file.
# Use of this resource for production deployments is not recommended.
# Instead, generate a private key file outside of Terraform and distribute it securely to the system where Terraform will be run.
output "generated_private_key_pem" {
  value     = var.generate_public_ssh_key ? tls_private_key.compute_ssh_key.private_key_pem : "No Keys Auto Generated"
  sensitive = true
}