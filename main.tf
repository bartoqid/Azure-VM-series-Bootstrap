provider "azurerm" {
   features {}
}

locals {
  virtual_machine_name = "${var.prefix}vm-series"
}

#Create a Resource Group for the new Virtual Machine
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}RG"
  location = var.location
}

#Create a Virtual Network within the Resource Group
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}network"
  address_space       = [var.address_space]
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

#Create the first Subnet within the Virtual Network
resource "azurerm_subnet" "management" {
  name                 = "management"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes       = [var.subnet_prefixes_MGT]
}

#Create the second Subnet within the Virtual Network
resource "azurerm_subnet" "Untrust" {
  count                = "${length(var.subnet_prefixes_Untrust)}"
  name                 = "${lookup(element(var.subnet_prefixes_Untrust, count.index), "name")}"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes     = "${lookup(element(var.subnet_prefixes_Untrust, count.index), "ip")}"
}

#Create the third Subnet within the Virtual Network
resource "azurerm_subnet" "Trust" {
  name                 = "Trust"
  virtual_network_name = azurerm_virtual_network.main.name
  resource_group_name  = azurerm_resource_group.main.name
  address_prefixes       = [var.subnet_prefixes_Trust]
}

#subnet association Untrust
resource "azurerm_subnet_route_table_association" "Untrustassc" {
  for_each = {
    for k, v in azurerm_subnet.Untrust : k => v
  }
  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.PAN_FW_RT_Untrust.id
}

#create UDR from  Untrust back to trust
resource "azurerm_route_table" "PAN_FW_RT_Untrust" {
  name                = "Untrust"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "Untrust-to-Trust"
    address_prefix         = var.subnet_prefixes_Trust
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall-ip-untrust
  }
}

#subnet association management
resource "azurerm_subnet_route_table_association" "mgtassc" {
  subnet_id      = azurerm_subnet.management.id
  route_table_id = azurerm_route_table.managementroute.id
}

#subnet association Trust
resource "azurerm_subnet_route_table_association" "Trustassc" {
  subnet_id      = azurerm_subnet.Trust.id
  route_table_id = azurerm_route_table.PAN_FW_RT_Trust.id
}

#create UDR from managemtn to outside
resource "azurerm_route_table" "managementroute" {
  name                = "managementroute"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "default"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "Internet"
  }
}

#create UDR from Trust to outside
resource "azurerm_route_table" "PAN_FW_RT_Trust" {
  name                = "Trust"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "Trust-to-outside"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall-ip-private
  }
}

#Create a Network Security Group to allow any traffic inbound and outbound
resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow_all_inbound"
    description                = "Allow all"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_all_outboundP"
    description                = "Allow All access"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

#create vmseries Public IPAddresses management and untrust interface
resource "azurerm_public_ip" "PublicIP_0" {
  name                         = "${var.prefix}fwpublicIP0"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.main.name
  allocation_method = "Dynamic"
}

resource "azurerm_public_ip" "PublicIP_1" {
  name                         = "${var.prefix}fwpublicIP1"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.main.name
  allocation_method = "Dynamic"
}

resource "azurerm_public_ip" "PublicIP_2" {
  name                         = "${var.prefix}fwpublicIP2"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.main.name
  allocation_method = "Dynamic"
}

#create vmseries Network Interfaces
resource "azurerm_network_interface" "VNIC0" {
  name                      = "${var.prefix}eth0"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.main.name
  depends_on = [
    azurerm_virtual_network.main,
    azurerm_public_ip.PublicIP_0,
  ]

  ip_configuration {
    name                          = "ipmgmt"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP_0.id
  }
}

resource "azurerm_network_interface" "VNIC1" {
  name                      = "${var.prefix}eth1"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.main.name
  depends_on = [
    azurerm_virtual_network.main,
    azurerm_public_ip.PublicIP_1,
  ]

  enable_ip_forwarding = true
  ip_configuration {
    name                          = "ipeth1"
    subnet_id                     = azurerm_subnet.Untrust[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP_1.id
  }
}

resource "azurerm_network_interface" "VNIC2" {
  name                      = "${var.prefix}eth2"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.main.name
  depends_on                = [azurerm_virtual_network.main]

  enable_ip_forwarding = true
  ip_configuration {
    name                          = "ipeth2"
    subnet_id                     = azurerm_subnet.Trust.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "VNIC3" {
  name                      = "${var.prefix}eth3"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.main.name
  depends_on = [
    azurerm_virtual_network.main,
    azurerm_public_ip.PublicIP_1,
  ]

  enable_ip_forwarding = true
  ip_configuration {
    name                          = "ipeth3"
    subnet_id                     = azurerm_subnet.Untrust[1].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP_2.id
  }
}

resource "azurerm_network_interface_security_group_association" "mgt-int" {
  network_interface_id      = azurerm_network_interface.VNIC0.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface_security_group_association" "untrust-int" {
  network_interface_id      = azurerm_network_interface.VNIC1.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface_security_group_association" "untrust-int1" {
  network_interface_id      = azurerm_network_interface.VNIC3.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_interface_security_group_association" "trust-int" {
  network_interface_id      = azurerm_network_interface.VNIC2.id
  network_security_group_id = azurerm_network_security_group.main.id
}

#create storage for vm-series
resource "azurerm_storage_account" "storagepan4" {
  name                     = "${var.prefix}storage"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  #account_tier             = "Standard"
}

#create vm-series
resource "azurerm_virtual_machine" "main" {
  name                         = "${var.prefix}-vm"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  primary_network_interface_id = azurerm_network_interface.VNIC0.id
  network_interface_ids        = [azurerm_network_interface.VNIC0.id, azurerm_network_interface.VNIC1.id, azurerm_network_interface.VNIC2.id, azurerm_network_interface.VNIC3.id]
  vm_size                      = "Standard_D3"
  depends_on                   = [azurerm_network_interface_security_group_association.mgt-int, azurerm_network_interface_security_group_association.untrust-int, azurerm_network_interface_security_group_association.trust-int, azurerm_network_interface_security_group_association.untrust-int1]

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  plan {
    name      = "byol"
    publisher = "paloaltonetworks"
    product   = "vmseries-flex"
  }

  storage_image_reference {
    publisher = "paloaltonetworks"
    offer     = "vmseries-flex"
    sku       = "byol"
    version   = "10.1.0"
  }

  boot_diagnostics {
    enabled = "true"
    storage_uri = azurerm_storage_account.storagepan4.primary_blob_endpoint
  }

  storage_os_disk {
    name          = "${local.virtual_machine_name}-osdisk"
    vhd_uri       = "${azurerm_storage_account.storagepan4.primary_blob_endpoint}vhds/${var.prefix}-vmseries1-bundle2.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = local.virtual_machine_name
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data = join(
      ",",
      [
        "storage-account=${var.bootstrap_storage_account}",
        "access-key=${var.bootstrap_storage_account_primary_access_key}",
        "file-share=${var.file_share_name}",
        "share-directory=None"
      ],
    )
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

#create network interface for host
resource "azurerm_network_interface" "host-nic" {
  name                = "${var.prefix}-host-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.Trust.id
    private_ip_address_allocation = "dynamic"
  }
}

#create ubuntu host
resource "azurerm_virtual_machine" "ubuntu" {
  name                         = "${var.prefix}-vmubuntu"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  primary_network_interface_id = azurerm_network_interface.host-nic.id
  network_interface_ids        = [azurerm_network_interface.host-nic.id]
  vm_size                      = "Standard_D1"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  #delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  #delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.prefix}linuxosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.prefix}-vmubuntu"
    admin_username = var.admin_endpoint
    admin_password = var.endpoint_password
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}