# Deployment options for test the CPE with WebLogic

## Deploy Using Oracle Resource Manager

> ___NOTE:___ If you aren't already signed in, when prompted, enter the tenancy and user credentials. Review and accept the terms and conditions.

1. Click to deploy the stack

    [![Deploy to Oracle Cloud][magic_button]][magic_cpe_stack]

1. Select the region and compartment where you want to deploy the stack.

1. Follow the on-screen prompts and instructions to create the stack.

1. After creating the stack, click Terraform Actions, and select Plan.

1. Wait for the job to be completed, and review the plan.

1. To make any changes, return to the Stack Details page, click Edit Stack, and make the required changes. Then, run the Plan action again.

1. If no further changes are necessary, return to the Stack Details page, click Terraform Actions, and select Apply.

## Deploy Using the Terraform CLI

### Prerequisites

Create a terraform.tfvars file and populate with the required variables or override existing variables.

Note: An example [tfvars file](examples/terraform.tfvars.example) is included for reference. Using this file is the
preferred way to run the stack from the CLI, because of the large number of variables to manage.

To use this file just copy the example [tfvars file](examples/terraform.tfvars.example) and save it in the outermost directory.
Next, rename the file to __terraform.tfvars__. You can override the example values set in this file.

### Clone the Module

Clone the source code from suing the following command:

```bash
git clone github.com/oracle-quickstart/terraform-oci-cpe
```

```bash
cd terraform-oci-cpe
```

### Running Terraform

After specifying the required variables you can run the stack using the following commands:

```bash
terraform init
```

```bash
terraform plan
```

```bash
terraform apply
```

```bash
terraform destroy -refresh=false
```

## Deploy Manually with Libreswan

### Prerequisites for Libreswan

1. A VCN with at least one subnet for the CPE.

1. A VCN with at least one subnet for the and instance with WebLogic server.

1. A DRG attached to the VCN.

### Create or reuse a Compute Instance to install Libreswan

1. Install Libreswan on the Compute instance.

## Deploy Manually with wireguard

```bash
sudo yum install libreswan -y
```

[magic_button]: https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg
[magic_cpe_stack]: https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/oracle-quickstart/oci-cpe/releases/latest/download/oci-cpe-stack.zip
