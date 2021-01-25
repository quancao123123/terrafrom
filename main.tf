# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=2.40.0"
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "my-resources-quan"
  location = "Southeast Asia"
}

resource "azurerm_virtual_network" "example" {
  name                = "quan-linux"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "acctsub"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                         = "myPublicIP-linux"
    location                     = azurerm_resource_group.example.location
    resource_group_name          = azurerm_resource_group.example.name
    allocation_method            = "Static"

    tags = {
        environment = "Terraform Demo"
    }
}
# Create public IPs
resource "azurerm_public_ip" "myterraformpublicip2" {
    name                         = "myPublicIP-windows"
    location                     =    azurerm_resource_group.example.location
    resource_group_name          = azurerm_resource_group.example.name
    allocation_method            = "Static"

    tags = {
        environment = "Terraform Demo Windows"
    }
}

resource "azurerm_network_interface" "example" {
  name                = "acctni"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.example.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.example.name
    location                   = azurerm_resource_group.example.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location             = azurerm_resource_group.example.location
    resource_group_name = azurerm_resource_group.example.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
    security_rule {
        name                       = "RDP"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }


    tags = {
        environment = "Terraform Demo"
    }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.example.id
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

#create linux
resource "azurerm_linux_virtual_machine" "example" {
  name                = "quan-linux"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_Ds1_v2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

    computer_name  = "myvm"
    disable_password_authentication = true
  admin_ssh_key {
    username       = "adminuser"
    public_key     = tls_private_key.example_ssh.public_key_openssh
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  tags = {
        environment = "Terraform Demo"
    }
}

#create network interface
resource "azurerm_network_interface" "windowsif" {
  name                = "acctni-windows"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration2"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.myterraformpublicip2.id
  }
}

#create windows
resource "azurerm_windows_virtual_machine" "windows" {
  name                = "quan-windows"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [  azurerm_network_interface.windowsif.id, ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  tags = {
        environment = "Terraform Demo Windows"
    }
}

# #################
resource "azurerm_virtual_machine_extension" "extension" {
  name                 = "Test2"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  auto_upgrade_minor_version = true


  settings = <<SETTINGS
    {
        
        "fileUris": ["https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"],
        "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1"
        
    }
    SETTINGS


}

resource "null_resource" "cluster" {
  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  
  connection {
    type     = "ssh"
    user     = "adminuser"
    host     = azurerm_linux_virtual_machine.example.*.myterraformpublicip
  }


  provisioner "local-exec" {
    # Bootstrap script called with private_ip of each node in the clutser
     command = " ansible-playbook -i inventory main.yml -vvv "
  }
  }

  