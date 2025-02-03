resource "azurerm_resource_group" "public" {
  location = var.resource_group_location
  name     = "rg-private-endpoint-${var.prefix}"
  tags     = var.tags
}

#################################################################################################################
# NETWORK
#################################################################################################################

resource "azurerm_virtual_network" "public" {
  name                = "vnet-${var.prefix}"
  address_space       = ["10.10.0.0/24"]
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
}

resource "azurerm_subnet" "subnet_sql" {
  name                 = "subnet-sql-${var.prefix}"
  resource_group_name  = azurerm_resource_group.public.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = ["10.10.0.0/25"]
}

resource "azurerm_subnet" "subnet_vm" {
  name                 = "subnet-vm-${var.prefix}"
  resource_group_name  = azurerm_resource_group.public.name
  virtual_network_name = azurerm_virtual_network.public.name
  address_prefixes     = ["10.10.0.128/25"]
}

#################################################################################################################
# LINUX VM
#################################################################################################################

module "linux_vm" {
  source                            = "./modules/azure-linux-vm-key-auth"
  ip_configuration_name             = "ipc-vm-${var.prefix}"
  network_interface_name            = "nic-vm-${var.prefix}"
  os_profile_admin_public_key_path  = "${path.root}/id_rsa.pub"
  os_profile_admin_username         = var.os_profile_admin_username
  os_profile_computer_name          = "vm-${var.prefix}"
  resource_group_location           = azurerm_resource_group.public.location
  resource_group_name               = azurerm_resource_group.public.name
  storage_image_reference_offer     = var.storage_image_reference_offer
  storage_image_reference_publisher = var.storage_image_reference_publisher
  storage_image_reference_sku       = var.storage_image_reference_sku
  storage_image_reference_version   = var.storage_image_reference_version
  storage_os_disk_caching           = var.storage_os_disk_caching
  storage_os_disk_create_option     = var.storage_os_disk_create_option
  storage_os_disk_managed_disk_type = var.storage_os_disk_managed_disk_type
  storage_os_disk_name              = "osdisk-vm-${var.prefix}"
  vm_name                           = "vm-vm-${var.prefix}"
  vm_size                           = var.vm_size
  public_ip_name                    = "pip-vm-${var.prefix}"
  subnet_id                         = azurerm_subnet.subnet_vm.id
  network_security_group_id         = azurerm_network_security_group.public.id
}

#################################################################################################################
# SQL SERVER
#################################################################################################################

resource "azurerm_mssql_server" "sql_server" {
  name                          = "sql-server-${var.prefix}"
  resource_group_name           = azurerm_resource_group.public.name
  location                      = azurerm_resource_group.public.location
  version                       = "12.0"
  administrator_login           = "razumovsky_r"
  administrator_login_password  = file("${path.root}/sql_password.txt")
  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "database" {
  name        = "db-${var.prefix}"
  server_id   = azurerm_mssql_server.sql_server.id
  sku_name    = "S0"
  max_size_gb = 2
}

#################################################################################################################
# PRIVATE ENDPOINT FOR SQL SERVER
#################################################################################################################
resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "private-endpoint-${var.prefix}"
  location            = azurerm_resource_group.public.location
  resource_group_name = azurerm_resource_group.public.name
  subnet_id           = azurerm_subnet.subnet_sql.id

  private_service_connection {
    name                           = "private-connection-${var.prefix}"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }
}

#################################################################################################################
# PRIVATE DNS ZONE FOR SQL SERVER
#################################################################################################################
resource "azurerm_private_dns_zone" "sql_dns_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.public.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "sql-dns-link-${var.prefix}"
  resource_group_name   = azurerm_resource_group.public.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.public.id
}

resource "azurerm_private_dns_a_record" "sql_dns_record" {
  name                = azurerm_mssql_server.sql_server.name
  zone_name           = azurerm_private_dns_zone.sql_dns_zone.name
  resource_group_name = azurerm_resource_group.public.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.sql_private_endpoint.private_service_connection[0].private_ip_address]
}