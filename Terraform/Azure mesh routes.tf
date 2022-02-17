/*
A lot of my customers deploy Network Virtual Appliances [NVAs] aka virtual firewalls. They want to use the firewalls to not just control north / south but also east/west.

I spent forever trying to figure out how to programatically add all the routes for the other subnets, but not itself, subnet local traffic should be able to go direct on the VNET. The example is

RouteTable1 associated to subnet1 should have subnet2 and subnet3 routes
RouteTable2 associated to subnet2 should have subnet1 and subnet3 routes
RouteTable3 associated to subnet3 should have subnet1 and subnet2 routes

This would all be easy if Microsoft allowed not propogating any routes on the VNET, not just from the Virtual Network Gateway, but I digress
*/

locals {
    lan01_subnets = {
        "LAN01" = "10.30.1.0/24"
        "LAN02" = "10.30.1.0/24"
        "LAN03" = "10.30.1.0/24"
    }
    lan01_mesh_routes = [for a in setproduct(azurerm_route_table.lan01.*.name, keys(local.lan01_subnets)) : {
                    route_table = a[0]
                    subnet = a[1]
                } if a[1] != split("-", a[0])[1]
                ]
}

resource "azurerm_route_table" "lan01" {
  name                          = "VNET01-${keys(local.lan01_subnets)[count.index]}"
  location                      = "eastus"
  resource_group_name           = "NETWORKING"
  count                         = length(local.lan01_subnets)
  disable_bgp_route_propagation = true

}

resource "azurerm_route" "lan01_mesh" {
  name                    = local.lan01_mesh_routes[count.index].subnet
  count                   = length(local.lan01_mesh_routes)
  resource_group_name     = "NETWORKING"
  route_table_name        = local.lan01_mesh_routes[count.index].route_table
  address_prefix          = lookup(local.lan01_subnets, local.lan01_mesh_routes[count.index].subnet)
  next_hop_type           = "VirtualAppliance"
  next_hop_in_ip_address  = "10.20.1.10"
}