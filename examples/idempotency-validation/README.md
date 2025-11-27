# Idempotency Validation Example

This example is specifically designed to validate that the module's idempotency fixes work correctly and prevent perpetual drift.

## Purpose

This example tests the following known Azure Event Grid API idempotency issues and validates their fixes:

1. **Event Subscription Numeric Property Type Conversion**
   - Azure API may return numeric values as strings even when submitted as numbers
   - Module includes lifecycle block to ignore destination property changes

2. **Diagnostic Settings log_analytics_destination_type**
   - Azure Monitor API doesn't return this property in GET responses
   - Module includes lifecycle block to ignore this property

## Testing Procedure

### Step 1: Initial Deployment

Deploy the example configuration:

```bash
terraform init
terraform apply
```

### Step 2: Immediate Idempotency Check

Immediately after deployment completes, run a plan:

```bash
terraform plan
```

**Expected Result**: 
```
No changes. Your infrastructure matches the configuration.
```

If you see any changes at this point, there is an idempotency issue that needs investigation.

### Step 3: Delayed Idempotency Check

Wait 5 minutes to allow for any eventual consistency in Azure APIs, then run plan again:

```bash
terraform plan
```

**Expected Result**: 
```
No changes. Your infrastructure matches the configuration.
```

### Step 4: Apply with No Changes

Run apply to ensure it completes successfully with no changes:

```bash
terraform apply
```

**Expected Result**:
```
No changes. Your infrastructure matches the configuration.
```

### Step 5: Refresh State and Validate

Refresh the state and validate:

```bash
terraform refresh
terraform plan
```

**Expected Result**: Still no changes.

## What This Example Tests

### Test 1: String vs Number Type Conversion

The example includes an event subscription with numeric properties specified as strings:

```hcl
properties = {
  queueMessageTimeToLiveInSeconds = "300"  # String, not number
}
```

**Why**: Azure API returns these as strings. If you specify them as numbers, Terraform detects drift because the state shows strings while config shows numbers.

**Validation**: After deployment, terraform plan should show no changes to these properties.

### Test 2: Diagnostic Settings Destination Type

The example sets `log_analytics_destination_type = "Dedicated"`:

```hcl
diagnostic_settings = {
  test_destination_type = {
    log_analytics_destination_type = "Dedicated"
    # ...
  }
}
```

**Why**: Azure doesn't return this property, so Terraform would normally detect it as a change on every plan.

**Validation**: The module's lifecycle block prevents this drift. Plans should show no changes.

### Test 3: Combined Properties

The example sets multiple properties together to ensure they don't cause cross-property drift:

- Managed identities (system-assigned)
- Network access rules (public access disabled, IP rules)
- TLS version
- Tags

**Validation**: None of these should cause drift or unexpected updates.

## Common Drift Scenarios to Check For

### ❌ Incorrect Configuration (Will Cause Drift)

```hcl
# DON'T DO THIS
event_subscriptions = {
  example = {
    destination = {
      properties = {
        queueMessageTimeToLiveInSeconds = 300  # Number - WRONG
      }
    }
  }
}
```

Running plan after apply will show:
```
~ queueMessageTimeToLiveInSeconds = "300" -> 300
```

### ✅ Correct Configuration (No Drift)

```hcl
# DO THIS
event_subscriptions = {
  example = {
    destination = {
      properties = {
        queueMessageTimeToLiveInSeconds = "300"  # String - CORRECT
      }
    }
  }
}
```

## Troubleshooting

### If You See Drift in Event Subscription Properties

**Symptom**: Terraform plan shows changes to destination properties even though you haven't modified the configuration.

**Check**:
1. Verify numeric properties are specified as strings
2. Check that the lifecycle block exists in `main.event_subscriptions.tf`:
   ```hcl
   lifecycle {
     ignore_changes = [
       body.properties.destination.properties
     ]
   }
   ```

### If You See Drift in Diagnostic Settings

**Symptom**: Terraform plan shows changes to `log_analytics_destination_type`.

**Check**:
1. Verify the lifecycle block exists in `main.tf`:
   ```hcl
   lifecycle {
     ignore_changes = [
       log_analytics_destination_type
     ]
   }
   ```

### If You See Drift in Input Schema

**Symptom**: Terraform wants to change `input_schema` even though not specified in config.

**Fix**: Always explicitly set `input_schema` in your configuration:
```hcl
input_schema = "EventGridSchema"  # Make it explicit
```

## Automated Testing

This example can be used in automated testing pipelines:

```bash
#!/bin/bash
set -e

# Deploy
terraform apply -auto-approve

# Check idempotency immediately
if ! terraform plan -detailed-exitcode; then
  echo "❌ FAILED: Drift detected immediately after apply"
  exit 1
fi

# Wait for eventual consistency
sleep 300

# Check idempotency after delay
if ! terraform plan -detailed-exitcode; then
  echo "❌ FAILED: Drift detected after waiting for eventual consistency"
  exit 1
fi

echo "✅ PASSED: No drift detected"
```

## Expected Behavior Summary

| Action | Expected Result |
|--------|----------------|
| `terraform apply` | Creates all resources successfully |
| `terraform plan` (immediate) | No changes |
| `terraform plan` (after 5 min) | No changes |
| `terraform apply` (no config changes) | No changes |
| `terraform refresh && terraform plan` | No changes |

## Clean Up

```bash
terraform destroy -auto-approve
```

## References

- [Azure Event Grid REST API](https://learn.microsoft.com/en-us/rest/api/eventgrid/)
- [Terraform Lifecycle Meta-Arguments](https://www.terraform.io/language/meta-arguments/lifecycle)
- [AzAPI Provider Documentation](https://registry.terraform.io/providers/Azure/azapi/latest/docs)
