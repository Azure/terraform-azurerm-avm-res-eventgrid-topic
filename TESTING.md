# Testing Guide for Idempotency and Day 2 Operations

This document provides comprehensive testing procedures for validating idempotency fixes and Day 2 operations scenarios in the Event Grid Topic module.

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.9
- Azure CLI configured
- Docker (for AVM validation tools)

## AVM Validation

The module must pass AVM validation checks before any PR can be merged:

```bash
# Run pre-commit checks
export PORCH_NO_TUI=1
./avm pre-commit
git add .
git commit -m "chore: avm pre-commit"

# Run PR checks
export PORCH_NO_TUI=1
./avm pr-check
```

**Note**: If you encounter issues with Terraform version detection in the AVM tooling, ensure you're using the latest version of the AVM container image.

## Testing Structure

The module includes three example configurations for testing:

### 1. Default Example (`examples/default/`)

**Purpose**: Basic functionality and integration test

**What it tests**:
- Basic Event Grid Topic creation
- Private endpoint configuration
- Managed identity (system and user-assigned)
- Event subscription to Storage Queue
- Diagnostic settings

**How to test**:
```bash
cd examples/default
terraform init
terraform plan
terraform apply -auto-approve

# Validate idempotency
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."

# Cleanup
terraform destroy -auto-approve
```

### 2. Day 2 Operations Example (`examples/day2-operations/`)

**Purpose**: Comprehensive Day 2 operations testing

**What it tests**: See [examples/day2-operations/README.md](examples/day2-operations/README.md) for detailed test scenarios:
- Adding/removing event subscriptions (Tests 1-4)
- Managing managed identities (Tests 5-7)
- Adding/removing private endpoints (Tests 8-9)
- Network access configuration (Tests 10-11)
- Diagnostic settings management (Tests 12-14)
- Resource locks (Tests 15-16)

**How to test**: Follow the step-by-step procedures in the README for each test scenario.

### 3. Idempotency Validation Example (`examples/idempotency-validation/`)

**Purpose**: Validate known idempotency fixes

**What it tests**:
- Event subscription numeric property type conversion
- Diagnostic settings log_analytics_destination_type handling
- Combined property configurations

**How to test**:
```bash
cd examples/idempotency-validation
terraform init
terraform apply -auto-approve

# Immediate idempotency check
terraform plan
# Expected: No changes

# Delayed check (after 5 minutes for eventual consistency)
sleep 300
terraform plan
# Expected: No changes

# Cleanup
terraform destroy -auto-approve
```

## Known Idempotency Issues and Validations

### Issue 1: Event Subscription Numeric Properties

**Problem**: Azure API returns numeric properties as strings, causing drift.

**Fix**: Module includes lifecycle block ignoring destination property changes.

**Validation**:
```hcl
# Correct configuration (no drift)
event_subscriptions = {
  example = {
    destination = {
      properties = {
        queueMessageTimeToLiveInSeconds = "300"  # String
      }
    }
  }
}
```

**Test procedure**:
1. Deploy with numeric properties as strings
2. Run `terraform plan` immediately
3. Expected: No changes to destination properties

**Failure symptom**: If properties are specified as numbers instead of strings, plan will show constant drift.

### Issue 2: Diagnostic Settings Destination Type

**Problem**: Azure API doesn't return `log_analytics_destination_type` in GET responses.

**Fix**: Module includes lifecycle block ignoring this property.

**Validation**:
```hcl
diagnostic_settings = {
  example = {
    log_analytics_destination_type = "Dedicated"
    # Other properties...
  }
}
```

**Test procedure**:
1. Deploy with log_analytics_destination_type set
2. Run `terraform plan` immediately
3. Expected: No changes to diagnostic settings

**Failure symptom**: Plan would show constant drift on log_analytics_destination_type.

## Automated Testing Script

Use this script for automated validation:

```bash
#!/bin/bash
set -e

EXAMPLE_DIR=${1:-"examples/idempotency-validation"}

echo "Testing: $EXAMPLE_DIR"
cd "$EXAMPLE_DIR"

# Initialize
terraform init

# Deploy
echo "Deploying..."
terraform apply -auto-approve

# Immediate idempotency check
echo "Checking idempotency (immediate)..."
if ! terraform plan -detailed-exitcode; then
  echo "❌ FAILED: Drift detected immediately after apply"
  terraform show
  exit 1
fi

# Wait for eventual consistency
echo "Waiting 5 minutes for eventual consistency..."
sleep 300

# Delayed idempotency check
echo "Checking idempotency (after delay)..."
if ! terraform plan -detailed-exitcode; then
  echo "❌ FAILED: Drift detected after eventual consistency period"
  terraform show
  exit 1
fi

# Apply with no changes
echo "Running apply with no changes..."
if ! terraform apply -auto-approve; then
  echo "❌ FAILED: Apply failed with no configuration changes"
  exit 1
fi

# Final idempotency check
echo "Final idempotency check..."
if ! terraform plan -detailed-exitcode; then
  echo "❌ FAILED: Drift detected after no-change apply"
  terraform show
  exit 1
fi

echo "✅ PASSED: All idempotency checks passed"

# Cleanup
terraform destroy -auto-approve
```

## Manual Testing Checklist

For each PR, validate:

### Idempotency Checks
- [ ] Deploy example configuration
- [ ] Run `terraform plan` immediately after apply
- [ ] Result shows "No changes"
- [ ] Wait 5 minutes
- [ ] Run `terraform plan` again
- [ ] Result still shows "No changes"

### Day 2 Operations Checks
- [ ] Add event subscription - only new subscription created
- [ ] Update event subscription filter - updated in place
- [ ] Remove event subscription - only that subscription destroyed
- [ ] Add private endpoint - only new endpoint created
- [ ] Add user-assigned identity - topic updated, not recreated
- [ ] Modify network access - topic updated, not recreated
- [ ] Add diagnostic setting - only new setting created

### Regression Checks
- [ ] No unintended resource recreations
- [ ] No drift in unmodified resources
- [ ] All lifecycle blocks still present
- [ ] Documentation matches code behavior

## Troubleshooting Test Failures

### Drift in Event Subscription Properties

**Symptom**: Plan shows changes to `maxEventsPerBatch`, `queueMessageTimeToLiveInSeconds`, or similar properties.

**Check**:
1. Verify numeric properties are strings in configuration
2. Verify lifecycle block exists in `main.event_subscriptions.tf`
3. Check Azure API response matches expected format

**Resolution**: Update configuration to use string values for numeric properties.

### Drift in Diagnostic Settings

**Symptom**: Plan shows changes to `log_analytics_destination_type`.

**Check**:
1. Verify lifecycle block exists in `main.tf`
2. Check if property is actually returned by Azure API

**Resolution**: Ensure lifecycle ignore_changes block is present.

### Resource Recreation on Property Change

**Symptom**: Changing a property causes resource replacement instead of in-place update.

**Check**:
1. Review Azure ARM schema for that property
2. Check if property is immutable
3. Verify Terraform resource supports in-place updates

**Resolution**: Document immutable properties in README and examples.

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: Test Idempotency

on:
  pull_request:
    paths:
      - '**.tf'
      - 'examples/**'

jobs:
  test-idempotency:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.9"
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Test Idempotency
        run: |
          cd examples/idempotency-validation
          terraform init
          terraform apply -auto-approve
          
          # Check idempotency
          if ! terraform plan -detailed-exitcode; then
            echo "Idempotency test failed"
            exit 1
          fi
          
          terraform destroy -auto-approve
```

## Reporting Issues

When reporting idempotency issues, include:

1. **Configuration**: Exact Terraform configuration causing drift
2. **Plan Output**: Full output of `terraform plan` showing drift
3. **State**: Relevant portions of `terraform show`
4. **Azure API Response**: If possible, the actual API response from Azure
5. **Steps to Reproduce**: Exact steps to reproduce the issue

## References

- [Azure Event Grid REST API](https://learn.microsoft.com/en-us/rest/api/eventgrid/)
- [Terraform Lifecycle Meta-Arguments](https://www.terraform.io/language/meta-arguments/lifecycle)
- [AzAPI Provider Documentation](https://registry.terraform.io/providers/Azure/azapi/latest/docs)
- [AVM Testing Guidelines](https://azure.github.io/Azure-Verified-Modules/contributing/terraform/testing/)
