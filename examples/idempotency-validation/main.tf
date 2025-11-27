terraform {
  required_version = "~> 1.5"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.9.0"

  geography_filter = "United States"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

# Storage Account and Queues for testing event subscription properties
resource "azapi_resource" "storage_account" {
  location  = azurerm_resource_group.this.location
  name      = module.naming.storage_account.name_unique
  parent_id = azurerm_resource_group.this.id
  type      = "Microsoft.Storage/storageAccounts@2025-01-01"
  body = {
    sku = {
      name = "Standard_ZRS"
    }
    kind = "StorageV2"
    properties = {
      allowSharedKeyAccess = true
    }
  }

  lifecycle {
    ignore_changes = [
      body.properties.allowSharedKeyAccess
    ]
  }
}

resource "azapi_resource" "storage_queue_correct" {
  name      = "queue-correct"
  parent_id = "${azapi_resource.storage_account.id}/queueServices/default"
  type      = "Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01"
  body = {
    properties = {}
  }
}

# =============================================================================
# IDEMPOTENCY VALIDATION - Event Grid Topic
# =============================================================================
# This example specifically tests the idempotency fixes in the module:
#
# 1. Event Subscription Destination Properties Type Conversion
#    - Azure API returns numeric values as strings
#    - Module has lifecycle block to ignore these changes
#    - This example uses correct string format to demonstrate no drift
#
# 2. Diagnostic Settings log_analytics_destination_type
#    - Azure API doesn't return this property in responses
#    - Module has lifecycle block to ignore these changes
#
# TESTING PROCEDURE:
# 1. Deploy this configuration: terraform apply
# 2. Immediately run: terraform plan
# 3. Expected: "No changes. Your infrastructure matches the configuration."
# 4. Wait 5 minutes and run terraform plan again
# 5. Expected: Still no changes (validates persistent idempotency)
# =============================================================================

module "eventgrid_topic" {
  source = "../../"

  location  = azurerm_resource_group.this.location
  name      = module.naming.eventgrid_topic.name_unique
  parent_id = azurerm_resource_group.this.id

  # Explicitly set to avoid drift (immutable property)
  input_schema = "EventGridSchema"

  data_residency_boundary = "WithinRegion"
  disable_local_auth      = true
  enable_telemetry        = true

  # =============================================================================
  # TEST 1: String vs Number Type Conversion in Event Subscriptions
  # =============================================================================
  # The Azure API may return numeric properties as strings even if submitted
  # as numbers. To avoid drift, always specify numeric values as strings.
  #
  # Properties affected:
  # - queueMessageTimeToLiveInSeconds
  # - maxEventsPerBatch
  # - preferredBatchSizeInKilobytes
  # - maxDeliveryAttempts
  # - eventTimeToLiveInMinutes
  event_subscriptions = {
    # CORRECT FORMAT - Using strings for all numeric properties
    correct_format = {
      name = "sub-correct-${module.naming.eventgrid_topic.name_unique}"
      destination = {
        endpointType = "StorageQueue"
        properties = {
          resourceId = azapi_resource.storage_account.id
          queueName  = "queue-correct"
          # ✅ CORRECT: Numeric value as string - no drift
          queueMessageTimeToLiveInSeconds = "300"
        }
      }
      filter = {
        isSubjectCaseSensitive = false
        subjectBeginsWith      = "/blobServices/"
        includedEventTypes     = null
      }
      retry_policy = {
        # These are also subject to type conversion but handled by AzAPI
        maxDeliveryAttempts      = 30
        eventTimeToLiveInMinutes = 1440
      }
    }
  }

  # =============================================================================
  # TEST 2: Diagnostic Settings log_analytics_destination_type Drift
  # =============================================================================
  # Azure Monitor API doesn't return log_analytics_destination_type in GET
  # responses. The module has a lifecycle block to ignore this, preventing
  # perpetual drift.
  #
  # This tests that setting this property doesn't cause drift on subsequent plans.
  diagnostic_settings = {
    test_destination_type = {
      name                  = "diag-${module.naming.eventgrid_topic.name_unique}"
      workspace_resource_id = azurerm_log_analytics_workspace.this.id
      # This property is not returned by Azure API
      # Module ignores it to prevent drift
      log_analytics_destination_type = "Dedicated"
      log_categories                 = toset(["PublishFailures", "DataPlaneRequests"])
      metric_categories              = toset(["AllMetrics"])
    }
  }

  # =============================================================================
  # TEST 3: Multiple Properties Set to Validate No Cross-Property Drift
  # =============================================================================
  # This configuration sets multiple properties that have had idempotency issues
  # in the past to ensure they don't cause drift when combined.

  managed_identities = {
    system_assigned = true
  }

  public_network_access = "Disabled"

  inbound_ip_rules = [
    {
      ip_mask = "10.0.0.0/16"
      action  = "Allow"
    },
  ]

  minimum_tls_version_allowed = "1.2"

  tags = {
    environment = "idempotency-test"
    purpose     = "validate-no-drift"
    test_case   = "string-number-conversion"
  }
}

# =============================================================================
# OUTPUTS FOR VALIDATION
# =============================================================================
# These outputs help validate that the resources were created correctly
# and can be used in automated tests.

output "topic_id" {
  description = "The ID of the Event Grid Topic"
  value       = module.eventgrid_topic.topic_id
}

output "event_subscription_ids" {
  description = "Map of event subscription IDs"
  value       = module.eventgrid_topic.event_subscription_ids
}

output "validation_message" {
  description = "Message to display after deployment"
  value       = <<-EOT
    ✅ Deployment complete!
    
    To validate idempotency:
    1. Run 'terraform plan' immediately - should show no changes
    2. Wait 5 minutes and run 'terraform plan' again - should still show no changes
    3. Run 'terraform apply' - should complete with no changes
    
    If you see any changes, the idempotency fix may need review.
  EOT
}
