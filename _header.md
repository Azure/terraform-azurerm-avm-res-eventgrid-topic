# terraform-azurerm-avm-res-eventgrid-topic

Terraform Azure Verified Resource Module for managing an Event Grid Topic.

## Private endpoints

Omitting `subresource_name` keeps the existing endpoint, connection and NIC names and connects to `topic`. Static IP configurations default their group and member names to `topic`. `resource_group_name` accepts a resource group ID or a name in the topic's subscription.

Previously ignored inputs are now honored. An existing endpoint will be replaced if its supplied `resource_group_name` differs from the group where it was created; remove that override to keep its current group. An explicit `subresource_name` now affects the connection name unless `private_service_connection_name` is set; leave the subresource unset or null to retain the existing default name. Review these changes before upgrading.

Private endpoint role assignments, locks and DNS zone groups are created when configured. DNS zone groups require at least one zone ID and `private_endpoints_manage_dns_zone_group = true`. A private endpoint inherits the topic's lock unless it has its own lock configuration; `lock = { kind = "None" }` opts out.

Private endpoint role assignments use AzAPI, which does not perform a client-side Microsoft Entra service-principal check. The existing `skip_service_principal_aad_check` field is retained for compatibility but does not change this behavior; use `principal_type` to specify the principal type sent to Azure.
