resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                = "my-orchestrated-vmss"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  platform_fault_domain_count = 1
  sku_name                    = "Standard_B1s"
  instances                   = 3
  zones                       = ["1"]

  os_profile {
    custom_data = base64encode(file("${path.module}/user_Data.sh"))

    linux_configuration {
      disable_password_authentication = true
      admin_username                  = "azureuser"

      admin_ssh_key {
        username   = "azureuser"
        public_key = var.ssh_public_key
      }
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpool.id]
    }
  }

  lifecycle {
    ignore_changes = [instances]
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.subnet_nsg_association,
    azurerm_subnet_nat_gateway_association.subnet_nat_assoc,
    azurerm_nat_gateway_public_ip_association.nat_pip_assoc
  ]
}

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_orchestrated_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 3
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}
