# Cross-Region Private Endpoint Example

This example demonstrates creating an Event Grid Topic in one Azure region with a Private Endpoint in a different region.

## Scenario

This is a common enterprise scenario where:
- The Event Grid Topic is deployed in a specific region (e.g., East US) for data residency or latency requirements
- The consuming application's VNet exists in a different region (e.g., West US 2)
- A private endpoint is needed to securely access the Event Grid Topic from the remote VNet

## Key Configuration

The `location` parameter in the `private_endpoints` configuration must be set to the region where the VNet exists:

```hcl
private_endpoints = {
  pe_crossregion = {
    subnet_resource_id = azurerm_subnet.pe.id  # Subnet in West US 2
    location           = "westus2"              # Must match the VNet region
  }
}
```

Without the correct `location` parameter, the private endpoint would be created in the Event Grid Topic's region, causing an `InvalidResourceReference` error because the subnet cannot be found in that region.
