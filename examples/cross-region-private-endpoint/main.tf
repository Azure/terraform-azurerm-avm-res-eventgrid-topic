terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
}

# Resource group for the Event Grid Topic (in East US)
resource "azurerm_resource_group" "topic_rg" {
  location = "eastus"
  name     = "${module.naming.resource_group.name_unique}-topic"
}

# Resource group for the VNet (in West US 2) - different region than the topic
resource "azurerm_resource_group" "network_rg" {
  location = "westus2"
  name     = "${module.naming.resource_group.name_unique}-network"
}

# Network resources in West US 2 (different region from the Event Grid Topic)
resource "azurerm_virtual_network" "vnet" {
  location            = azurerm_resource_group.network_rg.location
  name                = "vnet-eventgrid-crossregion"
  resource_group_name = azurerm_resource_group.network_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "pe" {
  address_prefixes     = ["10.0.1.0/24"]
  name                 = "snet-eventgrid-pe"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
}

# -----------------------------------------------------------------------------
# Cross-Region Private Endpoint Example
# -----------------------------------------------------------------------------
# This example demonstrates creating an Event Grid Topic in one region (East US)
# with a Private Endpoint in a different region (West US 2).
#
# Prior to the fix in PR #19, this would fail with an "InvalidResourceReference"
# error because the private endpoint was always created in the topic's region,
# ignoring the user-provided `location` parameter.
#
# The fix ensures that when `location` is specified in the private_endpoints
# configuration, it is respected and the private endpoint is created in the
# specified region where the VNet exists.
# -----------------------------------------------------------------------------

module "eventgrid_topic" {
  source = "../../"

  location         = azurerm_resource_group.topic_rg.location # East US
  name             = module.naming.eventgrid_topic.name_unique
  parent_id        = azurerm_resource_group.topic_rg.id
  enable_telemetry = true
  # Private endpoint in a DIFFERENT region than the Event Grid Topic
  # The `location` parameter tells the module where to create the private endpoint
  private_endpoints = {
    pe_crossregion = {
      name                            = "pe-${module.naming.eventgrid_topic.name_unique}-crossregion"
      subnet_resource_id              = azurerm_subnet.pe.id
      private_service_connection_name = "psc-eventgrid-topic-crossregion"

      # This is the key parameter being tested:
      # The private endpoint must be created in the same region as the VNet (West US 2),
      # not in the Event Grid Topic's region (East US).
      location = azurerm_resource_group.network_rg.location # West US 2

      # Optionally, you can also specify a different resource group for the private endpoint
      resource_group_name = azurerm_resource_group.network_rg.name
    }
  }
  private_endpoints_manage_dns_zone_group = true
  tags = {
    environment = "example"
    scenario    = "cross-region-private-endpoint"
  }
}
