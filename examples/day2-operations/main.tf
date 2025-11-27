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

## Section to provide a random Azure region for the resource group
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.9.0"

  geography_filter = "United States"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

# Resource group for the example
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

# Network resources for Private Endpoints
resource "azurerm_virtual_network" "vnet" {
  location            = azurerm_resource_group.this.location
  name                = "vnet-day2-example"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "pe1" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "snet-pe1"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

resource "azurerm_subnet" "pe2" {
  address_prefixes     = ["10.0.2.0/24"]
  name                 = "snet-pe2"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

# Managed Identities - demonstrating multiple identities
resource "azurerm_user_assigned_identity" "uai1" {
  location            = azurerm_resource_group.this.location
  name                = "uai-day2-1"
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_user_assigned_identity" "uai2" {
  location            = azurerm_resource_group.this.location
  name                = "uai-day2-2"
  resource_group_name = azurerm_resource_group.this.name
}

# Log Analytics workspace for diagnostics
resource "azurerm_log_analytics_workspace" "primary" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.log_analytics_workspace.name_unique}-primary"
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_workspace" "secondary" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.log_analytics_workspace.name_unique}-secondary"
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

# Storage Account for event subscription destination
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

# Storage Queues for different event subscriptions
resource "azapi_resource" "storage_queue_1" {
  name      = "events-queue-1"
  parent_id = "${azapi_resource.storage_account.id}/queueServices/default"
  type      = "Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01"
  body = {
    properties = {}
  }
}

resource "azapi_resource" "storage_queue_2" {
  name      = "events-queue-2"
  parent_id = "${azapi_resource.storage_account.id}/queueServices/default"
  type      = "Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01"
  body = {
    properties = {}
  }
}

# Event Hub for event subscription destination
resource "azurerm_eventhub_namespace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.eventhub_namespace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
}

resource "azurerm_eventhub" "this" {
  message_retention   = 1
  name                = "eventgrid-events"
  namespace_name      = azurerm_eventhub_namespace.this.name
  partition_count     = 2
  resource_group_name = azurerm_resource_group.this.name
}

# =============================================================================
# DAY 2 OPERATIONS EXAMPLE - Event Grid Topic
# =============================================================================
# This example demonstrates various Day 2 operations scenarios:
# 1. Adding/Removing Event Subscriptions
# 2. Modifying Event Subscription Filters
# 3. Adding/Removing Private Endpoints
# 4. Changing Managed Identities
# 5. Updating Network Access Rules
# 6. Modifying Diagnostic Settings
#
# TESTING SCENARIOS:
# - Initial deployment: Deploy with initial configuration
# - Add subscription: Uncomment "es_queue_2" and apply
# - Update filter: Change filter on "es_queue_1" and apply
# - Add private endpoint: Uncomment "pe2" and apply
# - Add user identity: Add uai2 to user_assigned_resource_ids and apply
# - Remove resources: Comment out added resources and apply
# - Verify idempotency: Run terraform plan after each apply to ensure no drift
# =============================================================================

module "eventgrid_topic" {
  source = "../../"

  location  = azurerm_resource_group.this.location
  name      = module.naming.eventgrid_topic.name_unique
  parent_id = azurerm_resource_group.this.id

  # Explicitly set input schema to avoid drift
  input_schema = "EventGridSchema"

  # Data residency configuration
  data_residency_boundary = "WithinRegion"

  # Security: disable local auth (key-based authentication)
  disable_local_auth = true

  enable_telemetry = true

  # =============================================================================
  # EVENT SUBSCRIPTIONS - Day 2 Operations
  # =============================================================================
  # Initial deployment: Start with es_queue_1
  # Day 2 Test 1: Uncomment es_queue_2 and apply (add subscription)
  # Day 2 Test 2: Modify filter on es_queue_1 and apply (update subscription filter)
  # Day 2 Test 3: Comment out es_queue_2 and apply (remove subscription)
  # Day 2 Test 4: Add es_eventhub and apply (add different destination type)
  event_subscriptions = {
    # Initial subscription - always present
    es_queue_1 = {
      name = "es-queue-1-${module.naming.eventgrid_topic.name_unique}"
      destination = {
        endpointType = "StorageQueue"
        properties = {
          resourceId = azapi_resource.storage_account.id
          queueName  = "events-queue-1"
          # IMPORTANT: Specify as string to avoid drift due to type conversion
          queueMessageTimeToLiveInSeconds = "300"
        }
      }
      filter = {
        isSubjectCaseSensitive = false
        # Day 2 Test: Change this to filter different event types
        subjectBeginsWith = "/blobServices/"
        includedEventTypes = null
      }
      retry_policy = {
        maxDeliveryAttempts      = 30
        eventTimeToLiveInMinutes = 1440
      }
    }

    # Day 2 Test 1: Uncomment this block to test adding a new subscription
    # es_queue_2 = {
    #   name = "es-queue-2-${module.naming.eventgrid_topic.name_unique}"
    #   destination = {
    #     endpointType = "StorageQueue"
    #     properties = {
    #       resourceId = azapi_resource.storage_account.id
    #       queueName  = "events-queue-2"
    #       queueMessageTimeToLiveInSeconds = "600"
    #     }
    #   }
    #   filter = {
    #     isSubjectCaseSensitive = false
    #     subjectBeginsWith      = "/containers/"
    #     includedEventTypes     = null
    #   }
    #   retry_policy = {
    #     maxDeliveryAttempts      = 20
    #     eventTimeToLiveInMinutes = 720
    #   }
    # }

    # Day 2 Test 4: Uncomment to test EventHub destination
    # es_eventhub = {
    #   name = "es-eventhub-${module.naming.eventgrid_topic.name_unique}"
    #   destination = {
    #     endpointType = "EventHub"
    #     properties = {
    #       resourceId = azurerm_eventhub.this.id
    #     }
    #   }
    #   filter = {
    #     advancedFilters = [
    #       {
    #         key          = "data.operationType"
    #         operatorType = "StringContains"
    #         values       = ["create", "update"]
    #       }
    #     ]
    #     enableAdvancedFilteringOnArrays = false
    #   }
    #   retry_policy = {
    #     maxDeliveryAttempts      = 30
    #     eventTimeToLiveInMinutes = 1440
    #   }
    # }
  }

  # =============================================================================
  # MANAGED IDENTITIES - Day 2 Operations
  # =============================================================================
  # Initial deployment: Start with system_assigned = true and uai1
  # Day 2 Test 5: Add uai2 to user_assigned_resource_ids (add user identity)
  # Day 2 Test 6: Remove uai2 from user_assigned_resource_ids (remove user identity)
  # Day 2 Test 7: Set system_assigned = false (disable system identity)
  managed_identities = {
    system_assigned = true
    user_assigned_resource_ids = [
      azurerm_user_assigned_identity.uai1.id,
      # Day 2 Test 5: Uncomment to add second user-assigned identity
      # azurerm_user_assigned_identity.uai2.id,
    ]
  }

  # =============================================================================
  # PRIVATE ENDPOINTS - Day 2 Operations
  # =============================================================================
  # Initial deployment: Start with pe1 only
  # Day 2 Test 8: Uncomment pe2 and apply (add private endpoint)
  # Day 2 Test 9: Comment out pe2 and apply (remove private endpoint)
  private_endpoints = {
    pe1 = {
      name                            = "pe1-${module.naming.eventgrid_topic.name_unique}"
      subnet_resource_id              = azurerm_subnet.pe1.id
      private_service_connection_name = "psc-eventgrid-pe1"
    }

    # Day 2 Test 8: Uncomment to add second private endpoint
    # pe2 = {
    #   name                            = "pe2-${module.naming.eventgrid_topic.name_unique}"
    #   subnet_resource_id              = azurerm_subnet.pe2.id
    #   private_service_connection_name = "psc-eventgrid-pe2"
    # }
  }

  private_endpoints_manage_dns_zone_group = true

  # =============================================================================
  # NETWORK ACCESS - Day 2 Operations
  # =============================================================================
  # Day 2 Test 10: Change to "Enabled" to allow public access
  # Day 2 Test 11: Add/modify inbound_ip_rules
  public_network_access = "Disabled"

  inbound_ip_rules = [
    # Day 2 Test 11: Uncomment to add IP rule
    # {
    #   ip_mask = "10.0.0.0/24"
    #   action  = "Allow"
    # },
  ]

  # =============================================================================
  # DIAGNOSTIC SETTINGS - Day 2 Operations
  # =============================================================================
  # Initial deployment: Start with primary workspace
  # Day 2 Test 12: Uncomment secondary diagnostic setting (add diagnostic target)
  # Day 2 Test 13: Modify log_categories on primary (update diagnostic settings)
  # Day 2 Test 14: Comment out secondary and apply (remove diagnostic target)
  diagnostic_settings = {
    primary = {
      name                           = "diag-primary-${module.naming.eventgrid_topic.name_unique}"
      workspace_resource_id          = azurerm_log_analytics_workspace.primary.id
      log_analytics_destination_type = "Dedicated"
      # Day 2 Test 13: Modify these categories to test updates
      log_categories    = toset(["PublishFailures", "DataPlaneRequests"])
      metric_categories = toset(["AllMetrics"])
    }

    # Day 2 Test 12: Uncomment to add second diagnostic setting
    # secondary = {
    #   name                           = "diag-secondary-${module.naming.eventgrid_topic.name_unique}"
    #   workspace_resource_id          = azurerm_log_analytics_workspace.secondary.id
    #   log_analytics_destination_type = "Dedicated"
    #   log_categories                 = toset(["PublishFailures"])
    #   metric_categories              = toset(["AllMetrics"])
    # }
  }

  # =============================================================================
  # RESOURCE LOCK - Day 2 Operations
  # =============================================================================
  # Day 2 Test 15: Uncomment to add management lock
  # Day 2 Test 16: Change kind to "ReadOnly" to test lock modification
  # lock = {
  #   kind = "CanNotDelete"
  #   name = "lock-eventgrid"
  # }

  tags = {
    environment = "day2-testing"
    purpose     = "idempotency-validation"
  }
}
