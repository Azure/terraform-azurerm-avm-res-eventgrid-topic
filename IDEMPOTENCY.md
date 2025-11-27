# Idempotency Issues and Solutions

This document catalogs known idempotency issues with Azure Event Grid Topic resources and the solutions implemented in this module.

## Summary

Azure Event Grid API has several behaviors that can cause Terraform drift (perpetual changes in plan output even when no actual changes were made). This module implements workarounds for these issues using Terraform lifecycle blocks.

## Issue 1: Event Subscription Destination Properties Type Conversion

### Problem Description

**Affected Properties**:
- `queueMessageTimeToLiveInSeconds`
- `maxEventsPerBatch`
- `preferredBatchSizeInKilobytes`
- Any numeric properties in destination configurations

**Behavior**: Azure Event Grid API returns these numeric properties as strings in GET responses, even when they are submitted as numbers in PUT/POST requests.

**Example**:
```hcl
# Configuration sent to Azure
destination = {
  properties = {
    queueMessageTimeToLiveInSeconds = 300  # Number
  }
}

# What Azure API returns
destination = {
  properties = {
    queueMessageTimeToLiveInSeconds = "300"  # String
  }
}
```

**Impact**: Without a fix, Terraform detects this as a drift and shows changes on every `terraform plan`, even though no actual changes were made:
```
~ body.properties.destination.properties.queueMessageTimeToLiveInSeconds = "300" -> 300
```

### Solution Implemented

**Location**: `main.event_subscriptions.tf`

**Code**:
```hcl
resource "azapi_resource" "event_subscriptions" {
  # ... other configuration ...

  lifecycle {
    ignore_changes = [
      # Ignore type conversion differences in destination properties
      # Azure API may return numeric values as strings or vice versa
      body.properties.destination.properties
    ]
  }
}
```

**How it works**: The lifecycle block tells Terraform to ignore any changes to destination properties after initial creation. This prevents spurious drift detection.

### User Guidance

**Best Practice**: Always specify numeric properties as strings in your configuration to match what Azure returns:

```hcl
# ✅ Correct - Use strings
event_subscriptions = {
  example = {
    destination = {
      properties = {
        queueMessageTimeToLiveInSeconds = "300"
        maxEventsPerBatch             = "10"
        preferredBatchSizeInKilobytes = "64"
      }
    }
  }
}

# ❌ Incorrect - Using numbers will cause state mismatches
event_subscriptions = {
  example = {
    destination = {
      properties = {
        queueMessageTimeToLiveInSeconds = 300
        maxEventsPerBatch             = 10
        preferredBatchSizeInKilobytes = 64
      }
    }
  }
}
```

### Tradeoffs

**Limitation**: Because we ignore changes to destination properties, Terraform will not detect if these properties are changed outside of Terraform (e.g., via Azure Portal or CLI).

**Workaround**: To update destination properties:
1. Remove the event subscription from your Terraform configuration
2. Run `terraform apply` to destroy it
3. Add it back with the new property values
4. Run `terraform apply` to recreate it

## Issue 2: Diagnostic Settings log_analytics_destination_type

### Problem Description

**Affected Property**: `log_analytics_destination_type`

**Behavior**: Azure Monitor Diagnostic Settings API does not return the `log_analytics_destination_type` property in GET responses. It only accepts this property during creation/update.

**Impact**: Without a fix, Terraform always detects this as a drift:
```
~ log_analytics_destination_type = "Dedicated" -> (known after apply)
```

### Solution Implemented

**Location**: `main.tf`

**Code**:
```hcl
resource "azurerm_monitor_diagnostic_setting" "this" {
  # ... other configuration ...

  lifecycle {
    ignore_changes = [
      # Azure API doesn't return log_analytics_destination_type in response
      # causing perpetual drift - ignore changes to prevent this
      log_analytics_destination_type
    ]
  }
}
```

**How it works**: The lifecycle block tells Terraform to ignore any changes to this property after initial creation.

### User Guidance

**Best Practice**: Always set `log_analytics_destination_type` to the desired value. The module will apply it correctly during creation:

```hcl
diagnostic_settings = {
  example = {
    workspace_resource_id          = azurerm_log_analytics_workspace.example.id
    log_analytics_destination_type = "Dedicated"  # or "AzureDiagnostics"
    # ... other properties ...
  }
}
```

### Tradeoffs

**Limitation**: Terraform cannot detect if this property is changed outside of Terraform.

**Impact**: This is generally acceptable because:
1. The property is set correctly during initial creation
2. It rarely needs to be changed
3. Azure doesn't allow modifying it via API anyway (would require recreation)

## Issue 3: Storage Account allowSharedKeyAccess (Related Resource)

### Problem Description

**Context**: When using Storage Queue destinations for event subscriptions, a storage account is needed.

**Behavior**: Azure Policy may automatically set `allowSharedKeyAccess = false` for compliance, even if created with `true`.

**Impact**: Terraform detects drift on the storage account.

### Solution

**Location**: Examples (e.g., `examples/default/main.tf`)

**Code**:
```hcl
resource "azapi_resource" "storage_account" {
  # ... configuration ...
  
  lifecycle {
    ignore_changes = [
      body.properties.allowSharedKeyAccess
    ]
  }
}
```

**Note**: This is implemented in examples as guidance. Users should include this in their own storage account resources if using Azure Policy that modifies this property.

## Validation Procedures

### Test for Issue 1: Event Subscription Type Conversion

```bash
# Deploy with string properties
terraform apply

# Immediately check for drift
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."
```

If drift is detected:
1. Check that all numeric properties are strings
2. Verify lifecycle block exists in main.event_subscriptions.tf

### Test for Issue 2: Diagnostic Settings Destination Type

```bash
# Deploy with log_analytics_destination_type set
terraform apply

# Immediately check for drift
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."
```

If drift is detected:
1. Verify lifecycle block exists in main.tf for diagnostic settings
2. Check AzureRM provider version compatibility

## Historical Context

### Why These Issues Exist

1. **Type Conversion**: Azure's ARM/REST APIs use JSON, which doesn't distinguish between numeric types and string representations of numbers. Different API endpoints may serialize numbers differently.

2. **Missing Properties**: Some Azure API GET responses don't include all properties that were set in PUT requests. This is a known Azure API pattern for "write-only" properties.

### Related Issues

- Azure SDK: https://github.com/Azure/azure-sdk-for-go/issues
- AzureRM Provider: https://github.com/hashicorp/terraform-provider-azurerm/issues
- AzAPI Provider: https://github.com/Azure/terraform-provider-azapi/issues

## Future Improvements

### Potential Solutions

1. **AzAPI Provider Enhancement**: The provider could handle type conversions automatically.
2. **Azure API Improvement**: Azure could normalize numeric property handling across all APIs.
3. **Terraform Core**: Enhanced drift detection that understands type equivalence.

### Monitoring

Watch these resources for updates:
- AzAPI Provider releases
- Azure Event Grid API version updates
- Terraform provider releases

## Contributing

If you discover additional idempotency issues:

1. Document the issue with:
   - Affected properties
   - Terraform configuration
   - Azure API behavior
   - Plan output showing drift

2. Propose solution:
   - Lifecycle block location
   - User guidance
   - Tradeoffs

3. Add test case to examples/idempotency-validation/

## References

- [Terraform Lifecycle Meta-Arguments](https://www.terraform.io/language/meta-arguments/lifecycle)
- [AzAPI Provider Documentation](https://registry.terraform.io/providers/Azure/azapi/latest/docs)
- [Azure Event Grid API Reference](https://learn.microsoft.com/en-us/rest/api/eventgrid/)
- [Azure Monitor Diagnostic Settings](https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/diagnostic-settings)
