# Quick Reference: Idempotency and Day 2 Operations

This is a quick reference guide for common tasks and avoiding drift. For detailed information, see:
- **IDEMPOTENCY.md** - Complete idempotency issue catalog
- **TESTING.md** - Comprehensive testing procedures
- **README.md** - Full module documentation

## ✅ DO: Correct Patterns to Avoid Drift

### Event Subscriptions: Use Strings for Numeric Properties

```hcl
event_subscriptions = {
  example = {
    name = "my-subscription"
    destination = {
      endpointType = "StorageQueue"
      properties = {
        resourceId = azapi_resource.storage.id
        queueName  = "my-queue"
        # ✅ Correct: Use strings for numeric values
        queueMessageTimeToLiveInSeconds = "300"
        maxEventsPerBatch             = "10"
        preferredBatchSizeInKilobytes = "64"
      }
    }
    retry_policy = {
      maxDeliveryAttempts      = 30      # Numbers OK here
      eventTimeToLiveInMinutes = 1440
    }
  }
}
```

### Always Specify Input Schema Explicitly

```hcl
module "eventgrid_topic" {
  source = "Azure/avm-res-eventgrid-topic/azurerm"
  
  # ✅ Correct: Always specify explicitly
  input_schema = "EventGridSchema"
  
  # Other configuration...
}
```

### Diagnostic Settings: Set Destination Type

```hcl
diagnostic_settings = {
  example = {
    workspace_resource_id = azurerm_log_analytics_workspace.example.id
    # ✅ Correct: Set this even though Azure doesn't return it
    log_analytics_destination_type = "Dedicated"
    log_categories    = toset(["PublishFailures"])
    metric_categories = toset(["AllMetrics"])
  }
}
```

## ❌ DON'T: Patterns That Cause Drift

### Event Subscriptions: Numeric Values as Numbers

```hcl
event_subscriptions = {
  example = {
    destination = {
      properties = {
        # ❌ Wrong: Numbers will cause drift
        queueMessageTimeToLiveInSeconds = 300
        maxEventsPerBatch             = 10
      }
    }
  }
}
# Result: Terraform will always show these as changed
```

### Omitting Input Schema

```hcl
module "eventgrid_topic" {
  source = "Azure/avm-res-eventgrid-topic/azurerm"
  
  # ❌ Wrong: Omitting input_schema
  # Azure will set it to default, then Terraform detects drift
  
  # Other configuration...
}
```

## 🔄 Day 2 Operations Quick Guide

### Add Event Subscription

1. Add new subscription to `event_subscriptions` map
2. Run `terraform plan` - only new subscription should be created
3. Run `terraform apply`
4. Validate: `terraform plan` should show no changes

### Update Event Subscription Filter

1. Modify the `filter` block in existing subscription
2. Run `terraform plan` - only that subscription should update
3. Run `terraform apply`
4. Validate: `terraform plan` should show no changes

**Note**: Cannot update destination properties (they're ignored by lifecycle block). To change, remove and recreate the subscription.

### Add Private Endpoint

1. Add new endpoint to `private_endpoints` map
2. Run `terraform plan` - only new endpoint should be created
3. Run `terraform apply`
4. Validate: `terraform plan` should show no changes

### Add User-Assigned Identity

1. Add identity ID to `managed_identities.user_assigned_resource_ids`
2. Run `terraform plan` - topic should update in place
3. Run `terraform apply`
4. Validate: `terraform plan` should show no changes

### Change Public Network Access

1. Change `public_network_access` value
2. Run `terraform plan` - topic should update in place
3. Run `terraform apply`
4. Validate: `terraform plan` should show no changes

### Add Diagnostic Setting

1. Add new setting to `diagnostic_settings` map
2. Run `terraform plan` - only new setting should be created
3. Run `terraform apply`
4. Validate: `terraform plan` should show no changes

## 🧪 Quick Validation Test

After any change, validate idempotency:

```bash
# Apply your changes
terraform apply -auto-approve

# Immediately check for drift
terraform plan

# Expected output:
# "No changes. Your infrastructure matches the configuration."

# If you see changes, review the patterns above
```

## 🚫 Immutable Properties (Force Replacement)

These properties cannot be changed without recreating the topic:

- `name` - Topic name
- `location` - Azure region  
- `parent_id` - Resource group
- `input_schema` - Input schema type (after creation)

**Warning**: Changing these will destroy and recreate the topic and all subscriptions!

## 📚 Example Configurations

### Minimal Configuration

```hcl
module "eventgrid_topic" {
  source  = "Azure/avm-res-eventgrid-topic/azurerm"
  version = "~> 1.0"

  name      = "my-topic"
  location  = "eastus"
  parent_id = azurerm_resource_group.example.id

  input_schema            = "EventGridSchema"
  enable_telemetry        = true
  disable_local_auth      = true
  public_network_access   = "Disabled"
}
```

### With Event Subscription

```hcl
module "eventgrid_topic" {
  source  = "Azure/avm-res-eventgrid-topic/azurerm"
  version = "~> 1.0"

  name      = "my-topic"
  location  = "eastus"
  parent_id = azurerm_resource_group.example.id

  input_schema = "EventGridSchema"

  event_subscriptions = {
    storage = {
      name = "storage-subscription"
      destination = {
        endpointType = "StorageQueue"
        properties = {
          resourceId = azapi_resource.storage.id
          queueName  = "events"
          queueMessageTimeToLiveInSeconds = "300"  # String!
        }
      }
      filter = {
        subjectBeginsWith = "/blobServices/"
      }
    }
  }
}
```

### With Private Endpoint and Identity

```hcl
module "eventgrid_topic" {
  source  = "Azure/avm-res-eventgrid-topic/azurerm"
  version = "~> 1.0"

  name      = "my-topic"
  location  = "eastus"
  parent_id = azurerm_resource_group.example.id

  input_schema = "EventGridSchema"
  
  managed_identities = {
    system_assigned = true
    user_assigned_resource_ids = [
      azurerm_user_assigned_identity.example.id
    ]
  }

  private_endpoints = {
    pe1 = {
      subnet_resource_id = azurerm_subnet.example.id
    }
  }
  
  public_network_access = "Disabled"
}
```

## 🐛 Troubleshooting

### Problem: Plan always shows destination property changes

**Cause**: Numeric properties specified as numbers instead of strings

**Fix**: Change to strings:
```hcl
queueMessageTimeToLiveInSeconds = "300"  # Not 300
```

### Problem: Plan shows log_analytics_destination_type changed

**Cause**: Lifecycle block missing or incorrect

**Fix**: Verify module version includes the fix (should be in main.tf)

### Problem: Input schema shows as changed

**Cause**: Not explicitly specified in configuration

**Fix**: Add `input_schema = "EventGridSchema"` to configuration

## 📖 More Information

- **Full Documentation**: See README.md
- **Detailed Issue Catalog**: See IDEMPOTENCY.md  
- **Testing Procedures**: See TESTING.md
- **Example Configurations**: See examples/ directory
  - `examples/default` - Basic usage
  - `examples/day2-operations` - Day 2 testing
  - `examples/idempotency-validation` - Idempotency testing

## 🆘 Getting Help

1. Check this quick reference
2. Review IDEMPOTENCY.md for your specific issue
3. Look at examples/ for working configurations
4. Check module issues on GitHub
5. Review Azure Event Grid API documentation
