.PHONY: prepare format test lint deploy

# Prepare the Terraform environment for development. This target verifies that AWS
# credentials are valid and properly configured, authenticates with Terraform Cloud
# or HCP Terraform, downloads all required provider plugins and modules, and sets up
# the backend configuration for state management.
prepare:
	@echo "Verifying AWS credentials..."
	aws sts get-caller-identity
	@echo "Authenticating with Terraform Cloud..."
	terraform login
	@echo "Initializing Terraform workspace..."
	terraform init

# Format all Terraform configuration files according to canonical style. This applies
# consistent formatting to all .tf files and recursively processes all subdirectories
# to ensure code consistency across the entire project.
format:
	@echo "Formatting Terraform files..."
	terraform fmt -recursive

# Test and validate the Terraform configuration. This checks the syntax and structure
# of all configuration files, validates provider configurations and resource definitions,
# and generates an execution plan showing what changes would be made without actually
# applying those changes to your infrastructure.
test:
	@echo "Validating Terraform configuration..."
	terraform validate
	@echo "Generating execution plan..."
	terraform plan

# Run static analysis and linting checks on the Terraform code. This executes TFLint
# to identify potential errors and verify best practices, then checks that all files
# are properly formatted to ensure code quality and consistency standards are met.
lint:
	@echo "Running TFLint..."
	tflint
	@echo "Checking Terraform formatting..."
	terraform fmt -check -recursive

# Deploy infrastructure changes to your cloud environment. This applies the Terraform
# configuration to create or update resources as needed. You will be prompted to review
# and confirm changes before they are applied, and the state file will be updated to
# reflect the current status of your infrastructure.
deploy:
	@echo "Applying Terraform changes..."
	terraform apply