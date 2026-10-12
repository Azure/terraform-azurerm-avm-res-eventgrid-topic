mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.EventGrid/topics/test-topic"
    }
  }

  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            role_name = "Reader"
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          }
        ]
      }
    }
  }
}

mock_provider "azurerm" {}
mock_provider "modtm" {}
mock_provider "random" {
  mock_resource "random_uuid" {
    defaults = {
      result = "00000000-0000-0000-0000-000000000001"
    }
  }
}

override_resource {
  target = azapi_resource.private_endpoints["test"]
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateEndpoints/test-pe"
  }
}

variables {
  location         = "eastus2"
  name             = "test-topic"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg"
  enable_telemetry = false
}

run "omitted_subresource_preserves_existing_body" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].name == "test-pe" &&
      azapi_resource.private_endpoints["test"].body.properties.customNetworkInterfaceName == "nic-test-pe" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "pcon-test-pe" &&
      tolist(azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].properties.groupIds) == tolist(["topic"])
    )
    error_message = "Omitting subresource_name must preserve the existing endpoint, NIC, connection name and topic group."
  }
}

run "null_subresource_preserves_topic_group" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        subresource_name   = null
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "pcon-test-pe" &&
      tolist(azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].properties.groupIds) == tolist(["topic"])
    )
    error_message = "An explicit null subresource_name must preserve the existing topic group and connection name."
  }
}

run "explicit_subresource_reaches_resource" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name                            = "test-pe"
        subnet_resource_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        subresource_name                = "explicit-test-group"
        private_service_connection_name = "explicit-connection"
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "explicit-connection" &&
      tolist(azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].properties.groupIds) == tolist(["explicit-test-group"])
    )
    error_message = "The configured subresource_name must reach the actual private endpoint request body."
  }
}

run "no_endpoints_creates_no_optional_resources" {
  command = apply

  assert {
    condition = (
      length(azapi_resource.private_endpoints) == 0 &&
      length(azapi_resource.private_dns_zone_groups) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0 &&
      length(random_uuid.private_endpoint_role_assignments) == 0
    )
    error_message = "The default configuration must not create private endpoints or their optional resources."
  }
}

run "generated_names_preserve_existing_defaults" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].name == "pe-test-topic-test" &&
      azapi_resource.private_endpoints["test"].parent_id == var.parent_id &&
      azapi_resource.private_endpoints["test"].location == var.location &&
      azapi_resource.private_endpoints["test"].body.properties.customNetworkInterfaceName == "nic-pe-test-topic-test" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "pcon-pep-${uuidv5("url", azapi_resource.this.id)}" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].properties.privateLinkServiceId == azapi_resource.this.id &&
      tolist(azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].properties.groupIds) == tolist(["topic"]) &&
      length(azapi_resource.private_dns_zone_groups) == 0 &&
      length(azapi_resource.private_endpoint_locks) == 0 &&
      length(azapi_resource.private_endpoint_role_assignments) == 0
    )
    error_message = "Generated endpoint, NIC and connection names must remain compatible, without empty DNS groups or unsolicited optional resources."
  }
}

run "all_endpoint_inputs_reach_resources" {
  command = apply

  override_resource {
    target = azapi_resource.private_endpoints["test"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/network-rg/providers/Microsoft.Network/privateEndpoints/test-pe"
    }
  }

  variables {
    tags = {
      topic_only = "topic"
    }
    private_endpoints = {
      test = {
        name = "test-pe"
        role_assignments = {
          reader = {
            name                                   = "11111111-1111-1111-1111-111111111111"
            role_definition_id_or_name             = "Reader"
            principal_id                           = "22222222-2222-2222-2222-222222222222"
            description                            = "Private endpoint reader"
            skip_service_principal_aad_check       = true
            condition                              = "@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals 'example'"
            condition_version                      = "2.0"
            delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test-identity"
            principal_type                         = "ServicePrincipal"
          }
        }
        lock = {
          kind  = "CanNotDelete"
          name  = "endpoint-lock"
          notes = "Protect the private endpoint"
        }
        tags = {
          purpose = "private-endpoint"
        }
        subnet_resource_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        subresource_name            = "explicit-test-group"
        private_dns_zone_group_name = "endpoint-dns"
        private_dns_zone_resource_ids = [
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.eventgrid.azure.net",
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/additional.example",
        ]
        application_security_group_associations = {
          first  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/applicationSecurityGroups/first"
          second = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/applicationSecurityGroups/second"
        }
        private_service_connection_name = "endpoint-connection"
        network_interface_name          = "endpoint-nic"
        location                        = "westus2"
        resource_group_name             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/network-rg"
        ip_configurations = {
          primary = {
            name               = "endpoint-ip"
            private_ip_address = "10.0.1.4"
            member_name        = "explicit-member"
          }
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].name == "test-pe" &&
      azapi_resource.private_endpoints["test"].location == "westus2" &&
      azapi_resource.private_endpoints["test"].parent_id == var.private_endpoints["test"].resource_group_name &&
      azapi_resource.private_endpoints["test"].tags == tomap({ purpose = "private-endpoint" }) &&
      azapi_resource.private_endpoints["test"].body.properties.subnet.id == var.private_endpoints["test"].subnet_resource_id &&
      azapi_resource.private_endpoints["test"].body.properties.customNetworkInterfaceName == "endpoint-nic" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "endpoint-connection" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].properties.privateLinkServiceId == azapi_resource.this.id &&
      tolist(azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].properties.groupIds) == tolist(["explicit-test-group"]) &&
      toset([for group in azapi_resource.private_endpoints["test"].body.properties.applicationSecurityGroups : group.id]) == toset(values(var.private_endpoints["test"].application_security_group_associations))
    )
    error_message = "Endpoint placement, subnet, tags, names, target, group and application security groups must reach the actual resource."
  }

  assert {
    condition = (
      length(azapi_resource.private_endpoints["test"].body.properties.ipConfigurations) == 1 &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].name == "endpoint-ip" &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.privateIPAddress == "10.0.1.4" &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.groupId == "explicit-test-group" &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.memberName == "explicit-member"
    )
    error_message = "Every static IP field must reach the private endpoint request body."
  }

  assert {
    condition = (
      azapi_resource.private_dns_zone_groups["test"].name == "endpoint-dns" &&
      azapi_resource.private_dns_zone_groups["test"].parent_id == azapi_resource.private_endpoints["test"].id &&
      azapi_resource.private_dns_zone_groups["test"].parent_id != azapi_resource.this.id &&
      toset([for zone in azapi_resource.private_dns_zone_groups["test"].body.properties.privateDnsZoneConfigs : zone.properties.privateDnsZoneId]) == var.private_endpoints["test"].private_dns_zone_resource_ids &&
      length(toset([for zone in azapi_resource.private_dns_zone_groups["test"].body.properties.privateDnsZoneConfigs : zone.name])) == 2
    )
    error_message = "DNS groups must target the private endpoint and include every supplied zone under a unique configuration name."
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_locks["test"].name == "endpoint-lock" &&
      azapi_resource.private_endpoint_locks["test"].parent_id == azapi_resource.private_endpoints["test"].id &&
      azapi_resource.private_endpoint_locks["test"].body.properties.level == "CanNotDelete" &&
      azapi_resource.private_endpoint_locks["test"].body.properties.notes == "Protect the private endpoint"
    )
    error_message = "The endpoint lock name, scope, kind and notes must reach the actual lock resource."
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_role_assignments["test-reader"].name == "11111111-1111-1111-1111-111111111111" &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].parent_id == azapi_resource.private_endpoints["test"].id &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.principalId == "22222222-2222-2222-2222-222222222222" &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.description == "Private endpoint reader" &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.condition == var.private_endpoints["test"].role_assignments["reader"].condition &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.conditionVersion == "2.0" &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.delegatedManagedIdentityResourceId == var.private_endpoints["test"].role_assignments["reader"].delegated_managed_identity_resource_id &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.principalType == "ServicePrincipal"
    )
    error_message = "The endpoint role assignment name, scope and every supported RBAC property must reach the actual resource."
  }
}

run "omitted_static_ip_group_and_member_default_to_topic" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        ip_configurations = {
          primary = {
            name               = "static-ip"
            private_ip_address = "10.0.1.4"
          }
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.groupId == "topic" &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.memberName == "topic" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "pcon-test-pe"
    )
    error_message = "Static IPs must use Event Grid's topic group and member without changing the default connection name."
  }
}

run "null_static_ip_group_and_member_default_to_topic" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        subresource_name   = null
        ip_configurations = {
          primary = {
            name               = "static-ip"
            private_ip_address = "10.0.1.4"
            member_name        = null
          }
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.groupId == "topic" &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.memberName == "topic" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "pcon-test-pe"
    )
    error_message = "Explicit null group/member values must retain the topic defaults and connection name."
  }
}

run "legacy_resource_group_name_is_resolved_in_topic_subscription" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name                = "test-pe"
        subnet_resource_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        resource_group_name = "network-rg"
      }
    }
  }

  assert {
    condition     = azapi_resource.private_endpoints["test"].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/network-rg"
    error_message = "A legacy short resource group name must resolve within the topic's subscription."
  }
}

run "null_placement_and_names_keep_defaults" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name                            = "test-pe"
        subnet_resource_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        resource_group_name             = null
        location                        = null
        network_interface_name          = null
        private_service_connection_name = null
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].parent_id == var.parent_id &&
      azapi_resource.private_endpoints["test"].location == var.location &&
      azapi_resource.private_endpoints["test"].body.properties.customNetworkInterfaceName == "nic-test-pe" &&
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "pcon-test-pe"
    )
    error_message = "Null placement and name overrides must not change the existing defaults."
  }
}

run "dns_management_can_be_disabled" {
  command = apply

  variables {
    private_endpoints_manage_dns_zone_group = false
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        private_dns_zone_resource_ids = [
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.eventgrid.azure.net",
        ]
      }
    }
  }

  assert {
    condition     = length(azapi_resource.private_endpoints) == 1 && length(azapi_resource.private_dns_zone_groups) == 0
    error_message = "Disabling DNS management must leave the private endpoint but create no DNS zone group."
  }
}

run "dns_group_defaults_to_default_name" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        private_dns_zone_resource_ids = [
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.eventgrid.azure.net",
        ]
      }
    }
  }

  assert {
    condition     = azapi_resource.private_dns_zone_groups["test"].name == "default"
    error_message = "An omitted DNS zone group name must use the canonical default."
  }
}

run "omitted_role_assignment_name_uses_random_uuid" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        role_assignments = {
          reader = {
            role_definition_id_or_name = "Reader"
            principal_id               = "22222222-2222-2222-2222-222222222222"
          }
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_role_assignments["test-reader"].name == random_uuid.private_endpoint_role_assignments["test-reader"].result &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].name == "00000000-0000-0000-0000-000000000001" &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.principalType == null
    )
    error_message = "An omitted role assignment name must use the random UUID without inventing a principal type."
  }
}

run "null_role_assignment_name_and_legacy_aad_flag_preserve_semantics" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        role_assignments = {
          reader = {
            name                             = null
            role_definition_id_or_name       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            principal_id                     = "22222222-2222-2222-2222-222222222222"
            skip_service_principal_aad_check = true
          }
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_role_assignments["test-reader"].name == random_uuid.private_endpoint_role_assignments["test-reader"].result &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.roleDefinitionId == var.private_endpoints["test"].role_assignments["reader"].role_definition_id_or_name &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].body.properties.principalType == null
    )
    error_message = "Null names must use the random UUID; role IDs must pass through, and the compatibility AAD flag must not be mapped to principalType."
  }
}

run "endpoint_lock_defaults_its_name_and_omits_null_notes" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        lock = {
          kind  = "ReadOnly"
          name  = null
          notes = null
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_locks["test"].name == "lock-ReadOnly" &&
      azapi_resource.private_endpoint_locks["test"].body.properties.level == "ReadOnly" &&
      !contains(keys(azapi_resource.private_endpoint_locks["test"].body.properties), "notes")
    )
    error_message = "An unnamed lock must get a usable name, and null notes must not be sent."
  }
}

run "endpoint_inherits_supplied_topic_lock" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
      name = "inherited-lock"
    }
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_locks["test"].name == "inherited-lock" &&
      azapi_resource.private_endpoint_locks["test"].body.properties.level == "CanNotDelete" &&
      azapi_resource.private_endpoint_locks["test"].parent_id == azapi_resource.private_endpoints["test"].id
    )
    error_message = "A supplied topic lock must protect its private endpoint unless the endpoint opts out."
  }
}

run "endpoint_can_opt_out_of_inherited_lock" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
    }
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        lock = {
          kind = "None"
        }
      }
    }
  }

  assert {
    condition     = length(azapi_resource.private_endpoint_locks) == 0 && length(azurerm_management_lock.this) == 1
    error_message = "The endpoint's None lock must opt out without removing the topic lock."
  }
}

run "resource_types_retry_and_timeouts_reach_owned_resources" {
  command = apply

  variables {
    resource_types = {
      authorization_locks                               = "Microsoft.Authorization/locks@2017-04-01"
      authorization_role_assignments                    = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
      eventgrid_topics                                  = "Microsoft.EventGrid/topics@2025-04-01-preview"
      network_private_endpoints                         = "Microsoft.Network/privateEndpoints@2023-09-01"
      network_private_endpoints_private_dns_zone_groups = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01"
    }
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 12
      max_interval_seconds = 48
    }
    timeouts = {
      create = "15m"
      read   = "2m"
      update = "16m"
      delete = "17m"
    }
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        private_dns_zone_resource_ids = [
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/privateDnsZones/privatelink.eventgrid.azure.net",
        ]
        lock = {
          kind = "CanNotDelete"
        }
        role_assignments = {
          reader = {
            role_definition_id_or_name = "Reader"
            principal_id               = "22222222-2222-2222-2222-222222222222"
          }
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.this.type == var.resource_types.eventgrid_topics &&
      azapi_resource.private_endpoints["test"].type == var.resource_types.network_private_endpoints &&
      azapi_resource.private_dns_zone_groups["test"].type == var.resource_types.network_private_endpoints_private_dns_zone_groups &&
      azapi_resource.private_endpoint_locks["test"].type == var.resource_types.authorization_locks &&
      azapi_resource.private_endpoint_role_assignments["test-reader"].type == var.resource_types.authorization_role_assignments
    )
    error_message = "Each owned AzAPI resource must honor its API type override."
  }

  assert {
    condition = alltrue([
      for resource in [
        azapi_resource.this,
        azapi_resource.private_endpoints["test"],
        azapi_resource.private_dns_zone_groups["test"],
        azapi_resource.private_endpoint_locks["test"],
        azapi_resource.private_endpoint_role_assignments["test-reader"],
        ] : (
        resource.retry.interval_seconds == 12 &&
        resource.retry.max_interval_seconds == 48 &&
        tolist(resource.retry.error_message_regex) == tolist(["ScopeLocked"]) &&
        resource.timeouts.create == "15m" &&
        resource.timeouts.read == "2m" &&
        resource.timeouts.update == "16m" &&
        resource.timeouts.delete == "17m"
      )
    ])
    error_message = "Retry and operation timeout overrides must reach each owned AzAPI resource."
  }
}

run "explicit_topic_uses_utility_connection_name_and_topic_ip_member" {
  command = apply

  variables {
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        subresource_name   = "topic"
        ip_configurations = {
          primary = {
            name               = "static-ip"
            private_ip_address = "10.0.1.4"
          }
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoints["test"].body.properties.privateLinkServiceConnections[0].name == "pcon-topic-test-pe" &&
      azapi_resource.private_endpoints["test"].body.properties.customNetworkInterfaceName == "nic-test-pe" &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.groupId == "topic" &&
      azapi_resource.private_endpoints["test"].body.properties.ipConfigurations[0].properties.memberName == "topic"
    )
    error_message = "An explicit group must retain utility connection naming and supply the default IP member without changing the NIC name."
  }
}

run "endpoint_lock_overrides_supplied_topic_lock" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
      name = "topic-lock"
    }
    private_endpoints = {
      test = {
        name               = "test-pe"
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        lock = {
          kind  = "ReadOnly"
          name  = "endpoint-lock"
          notes = "Endpoint override"
        }
      }
    }
  }

  assert {
    condition = (
      azapi_resource.private_endpoint_locks["test"].name == "endpoint-lock" &&
      azapi_resource.private_endpoint_locks["test"].body.properties.level == "ReadOnly" &&
      azapi_resource.private_endpoint_locks["test"].body.properties.notes == "Endpoint override" &&
      azurerm_management_lock.this[0].name == "topic-lock" &&
      azurerm_management_lock.this[0].lock_level == "CanNotDelete"
    )
    error_message = "An explicit endpoint lock must override inheritance without changing the topic lock."
  }
}

run "rejects_invalid_subnet_resource_id" {
  command = plan

  variables {
    private_endpoints = {
      test = {
        subnet_resource_id = "not-a-subnet"
      }
    }
  }

  expect_failures = [var.private_endpoints]
}

run "rejects_invalid_dns_zone_resource_id" {
  command = plan

  variables {
    private_endpoints = {
      test = {
        subnet_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        private_dns_zone_resource_ids = ["not-a-dns-zone"]
      }
    }
  }

  expect_failures = [var.private_endpoints]
}

run "rejects_invalid_application_security_group_resource_id" {
  command = plan

  variables {
    private_endpoints = {
      test = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        application_security_group_associations = {
          invalid = "not-an-application-security-group"
        }
      }
    }
  }

  expect_failures = [var.private_endpoints]
}

run "rejects_invalid_delegated_identity_resource_id" {
  command = plan

  variables {
    private_endpoints = {
      test = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/test-subnet"
        role_assignments = {
          reader = {
            role_definition_id_or_name             = "Reader"
            principal_id                           = "22222222-2222-2222-2222-222222222222"
            delegated_managed_identity_resource_id = "not-an-identity"
          }
        }
      }
    }
  }

  expect_failures = [var.private_endpoints]
}
