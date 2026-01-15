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

  geography_filter       = "United States"
  has_availability_zones = true
}

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

# Log Analytics workspace for diagnostics
resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 30
  sku                 = "PerGB2018"
}

# ==============================================================================
# EXAMPLE 1: Using log_groups (allLogs category group)
# This demonstrates the fix for Issue #18 - log_groups is now properly respected
# ==============================================================================
module "eventgrid_topic_with_log_groups" {
  source = "../../"

  location                = azurerm_resource_group.this.location
  name                    = "eg-loggroups-${module.naming.eventgrid_topic.name_unique}"
  parent_id               = azurerm_resource_group.this.id
  data_residency_boundary = "WithinGeopair"
  # Diagnostic settings using log_groups (Issue #18 fix validation)
  # When log_groups is specified, it takes precedence over log_categories
  # and creates enabled_log blocks with category_group attribute
  diagnostic_settings = {
    audit_logs = {
      name                           = "diag-log-groups"
      workspace_resource_id          = azurerm_log_analytics_workspace.this.id
      log_analytics_destination_type = "Dedicated"
      # Using log_groups - this should now work correctly with the fix
      log_groups        = ["allLogs"]
      metric_categories = ["AllMetrics"]
    }
  }
  disable_local_auth    = true
  enable_telemetry      = true
  public_network_access = "Enabled"
  tags = {
    environment = "example"
    scenario    = "log_groups_validation"
  }
}

# ==============================================================================
# EXAMPLE 2: Using log_categories (original behavior, still works)
# This confirms backward compatibility is maintained
# ==============================================================================
module "eventgrid_topic_with_log_categories" {
  source = "../../"

  location                = azurerm_resource_group.this.location
  name                    = "eg-logcats-${module.naming.eventgrid_topic.name_unique}"
  parent_id               = azurerm_resource_group.this.id
  data_residency_boundary = "WithinGeopair"
  # Diagnostic settings using log_categories (existing functionality)
  # This should continue to work as before
  diagnostic_settings = {
    detailed_logs = {
      name                           = "diag-log-categories"
      workspace_resource_id          = azurerm_log_analytics_workspace.this.id
      log_analytics_destination_type = "Dedicated"
      # Using specific log categories
      log_categories    = ["PublishFailures", "DataPlaneRequests"]
      metric_categories = ["AllMetrics"]
    }
  }
  disable_local_auth    = true
  enable_telemetry      = true
  public_network_access = "Enabled"
  tags = {
    environment = "example"
    scenario    = "log_categories_validation"
  }
}

# ==============================================================================
# EXAMPLE 3: Multiple diagnostic settings - one with log_groups, one with log_categories
# This validates that both approaches can be used in different diagnostic settings
# ==============================================================================
module "eventgrid_topic_mixed" {
  source = "../../"

  location                = azurerm_resource_group.this.location
  name                    = "eg-mixed-${module.naming.eventgrid_topic.name_unique}"
  parent_id               = azurerm_resource_group.this.id
  data_residency_boundary = "WithinGeopair"
  # Multiple diagnostic settings to different destinations with different configurations
  diagnostic_settings = {
    # First setting: uses log_groups for comprehensive logging
    all_logs = {
      name                           = "diag-all-logs"
      workspace_resource_id          = azurerm_log_analytics_workspace.this.id
      log_analytics_destination_type = "Dedicated"
      log_groups                     = ["allLogs"]
      metric_categories              = ["AllMetrics"]
    }
  }
  disable_local_auth    = true
  enable_telemetry      = true
  public_network_access = "Enabled"
  tags = {
    environment = "example"
    scenario    = "mixed_diagnostic_settings"
  }
}
