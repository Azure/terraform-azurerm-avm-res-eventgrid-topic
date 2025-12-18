module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.5.0"

  enable_telemetry                        = var.enable_telemetry
  lock                                    = var.lock
  private_endpoints                       = local.private_endpoints
  private_endpoints_manage_dns_zone_group = var.private_endpoints_manage_dns_zone_group
  private_endpoints_scope                 = azapi_resource.this.id
  role_assignments                        = var.role_assignments
}

resource "azapi_resource" "private_endpoints" {
  for_each = module.avm_interfaces.private_endpoints_azapi

  location  = azapi_resource.this.location
  name      = coalesce(local.private_endpoints[each.key].name, "pe-${var.name}-${each.key}")
  parent_id = var.parent_id
  type      = each.value.type
  body = merge(
    each.value.body,
    {
      properties = merge(
        each.value.body.properties,
        {
          privateLinkServiceConnections = [
            for conn in try(each.value.body.properties.privateLinkServiceConnections, []) : merge(
              conn,
              {
                properties = merge(
                  try(conn.properties, {}),
                  {
                    groupIds = ["topic"]
                  }
                )
              }
            )
          ]
        }
      )
    }
  )
  create_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  read_headers           = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = ["properties.networkInterfaces"]
  tags                   = each.value.tags
  update_headers         = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
}
