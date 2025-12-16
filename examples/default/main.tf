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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
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

## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.9.0"

  geography_filter = "United States"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

# Resource group for the example
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

# Network resources required for the Private Endpoint
resource "azurerm_virtual_network" "vnet" {
  location            = azurerm_resource_group.this.location
  name                = "vnet-eventgrid-example"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "pe" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "snet-eventgrid-pe"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

# User Assigned Identity used by the Topic to access the Key Vault
resource "azurerm_user_assigned_identity" "uai" {
  location            = azurerm_resource_group.this.location
  name                = "uai-eventgrid-example"
  resource_group_name = azurerm_resource_group.this.name
}

# Log Analytics workspace for diagnostics (example)
resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

# Storage Account and Queue for event subscription destination (using AzAPI provider)
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
      # Required for Event Grid to access the queue
      allowSharedKeyAccess = true
    }
  }

  # Ignore changes to allowSharedKeyAccess if Azure Policy resets it
  lifecycle {
    ignore_changes = [
      body.properties.allowSharedKeyAccess
    ]
  }
}

# Queue Service is automatically created, we just need to create the queues
resource "azapi_resource" "storage_queue" {
  name      = "eventgrid-events"
  parent_id = "${azapi_resource.storage_account.id}/queueServices/default"
  type      = "Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01"
  body = {
    properties = {}
  }
}

# Second queue for demonstrating event subscription inside the module (direct delivery)
resource "azapi_resource" "storage_queue_direct" {
  name      = "eventgrid-events-direct"
  parent_id = "${azapi_resource.storage_account.id}/queueServices/default"
  type      = "Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01"
  body = {
    properties = {}
  }
}

# Grant the Event Grid Topic's system-assigned identity permission to send to the storage queue
resource "azurerm_role_assignment" "eventgrid_storage_queue_sender" {
  principal_id         = module.eventgrid_topic.system_assigned_mi_principal_id
  scope                = azapi_resource.storage_account.id
  role_definition_name = "Storage Queue Data Message Sender"
}

# Wait for RBAC propagation before the event subscription can deliver events
resource "time_sleep" "wait_for_rbac" {
  create_duration = "60s"

  depends_on = [azurerm_role_assignment.eventgrid_storage_queue_sender]
}

# Event subscription created OUTSIDE the module using delivery_with_resource_identity
# This pattern is required when:
# 1. You want to use the Topic's managed identity for secure RBAC-based delivery
# 2. The role assignment depends on the module's system-assigned identity output
# This avoids the chicken-and-egg problem where the module needs RBAC before creating subscriptions.
resource "azapi_resource" "event_subscription" {
  name      = "es-storagequeue-${module.naming.eventgrid_topic.name_unique}"
  parent_id = module.eventgrid_topic.resource_id
  type      = "Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15"
  body = {
    properties = {
      deliveryWithResourceIdentity = {
        identity = {
          type = "SystemAssigned"
        }
        destination = {
          endpointType = "StorageQueue"
          properties = {
            resourceId                      = azapi_resource.storage_account.id
            queueName                       = azapi_resource.storage_queue.name
            queueMessageTimeToLiveInSeconds = 300
          }
        }
      }
      eventDeliverySchema = "EventGridSchema"
      filter = {
        isSubjectCaseSensitive = false
      }
      retryPolicy = {
        maxDeliveryAttempts      = 30
        eventTimeToLiveInMinutes = 1440
      }
    }
  }
  ignore_casing             = true
  ignore_missing_property   = true
  ignore_null_property      = true
  response_export_values    = ["*"]
  schema_validation_enabled = false

  depends_on = [time_sleep.wait_for_rbac]
}

# Module call demonstrating Private Endpoints, Managed Identities, and Diagnostics
module "eventgrid_topic" {
  source = "../../"

  location  = azurerm_resource_group.this.location
  name      = module.naming.eventgrid_topic.name_unique
  parent_id = azurerm_resource_group.this.id
  # Example: set data residency boundary to 'WithinRegion' to keep data within the selected region.
  # Valid values: "WithinGeopair" (default) or "WithinRegion".
  data_residency_boundary = "WithinRegion"
  # Diagnostics: send topic "Publish" logs and metrics to the Log Analytics workspace.
  # Note: diagnostic log categories are resource-type specific. Topics commonly support the "Publish" log category.
  diagnostic_settings = {
    la = {
      name = "diagevgns-${module.naming.eventgrid_topic.name_unique}"
      # Use valid Event Grid Topic diagnostic categories: PublishFailures and DataPlaneRequests
      log_categories                 = toset(["PublishFailures", "DataPlaneRequests"])
      metric_categories              = toset(["AllMetrics"])
      log_analytics_destination_type = "Dedicated"
      workspace_resource_id          = azurerm_log_analytics_workspace.this.id
    }
  }
  # Explicitly show the disable_local_auth input (module default is true)
  disable_local_auth = true
  enable_telemetry   = true
  # Event subscriptions are created OUTSIDE the module when using delivery_with_resource_identity
  # This is because the role assignment depends on the module's system-assigned identity output,
  # creating a circular dependency if the event subscription is inside the module.
  # See azapi_resource.event_subscription above for the event subscription configuration.
  #
  # HOWEVER, for direct delivery (without managed identity), you can create event subscriptions
  # inside the module. The example below demonstrates this pattern:
  event_subscriptions = {
    # Direct delivery to Storage Queue (no managed identity required)
    # This pattern works well when the storage account allows shared key access
    # or when using connection strings for authentication.
    direct_to_queue = {
      name = "es-direct-${module.naming.eventgrid_topic.name_unique}"
      destination = {
        storage_queue = {
          resource_id                           = azapi_resource.storage_account.id
          queue_name                            = azapi_resource.storage_queue_direct.name
          queue_message_time_to_live_in_seconds = 600
        }
      }
      event_delivery_schema = "EventGridSchema"
      filter = {
        is_subject_case_sensitive = false
        subject_begins_with       = "/blobServices/"
      }
      retry_policy = {
        max_delivery_attempts         = 30
        event_time_to_live_in_minutes = 1440
      }
    }
  }
  # Keep the input_schema at the API default to avoid immutable updates. See README for details.
  input_schema = "EventGridSchema"
  # Ensure the Topic has a managed identity so it can access the Key Vault
  managed_identities = {
    user_assigned_resource_ids = [azurerm_user_assigned_identity.uai.id]
    system_assigned            = true
  }
  # Minimal Private Endpoint configuration: let the platform allocate IP address
  private_endpoints = {
    pe1 = {
      name                            = "pe-${module.naming.eventgrid_topic.name_unique}"
      subnet_resource_id              = azurerm_subnet.pe.id
      private_service_connection_name = "psc-eventgrid-topic"
    }
  }
  # Let the module manage the private DNS zone group in this example
  private_endpoints_manage_dns_zone_group = true
  tags = {
    environment = "example"
  }
}
