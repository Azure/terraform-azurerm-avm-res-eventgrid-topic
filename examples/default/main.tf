terraform {
  required_version = "~> 1.5"

  required_providers {
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
  features {}
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

# Module call demonstrating CMK and a Private Endpoint
module "eventgrid_topic" {
  source = "../../"

  location            = azurerm_resource_group.this.location
  name                = module.naming.eventgrid_topic.name_unique
  resource_group_name = azurerm_resource_group.this.name
  # Example: set data residency boundary to 'WithinRegion' to keep data within the selected region.
  # Valid values: "WithinGeopair" (default) or "WithinRegion".
  data_residency_boundary = "WithinRegion"
  # Diagnostics: send topic "Publish" logs and metrics to the Log Analytics workspace.
  # Note: diagnostic log categories are resource-type specific. Topics commonly support the "Publish" log category.
  diagnostic_settings = {
    la = {
      name = null
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
