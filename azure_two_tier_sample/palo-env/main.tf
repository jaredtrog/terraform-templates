### PANOS CONFIGURATION

resource "panos_general_settings" "PANOSCONFIG" {
  hostname = "pan-fw"
  dns_primary = "168.63.129.16"
}


# Interfaces
resource "panos_ethernet_interface" "UNTRUSTED" {
  depends_on = ["panos_general_settings.PANOSCONFIG"]
  name = "ethernet1/1"
  vsys = "vsys1"
  mode = "layer3"
  enable_dhcp = true
  # create_dhcp_default_route = true
  dhcp_default_route_metric = 10
  comment = "Configured for public traffic"
}

resource "panos_ethernet_interface" "TRUSTED" {
  depends_on = ["panos_general_settings.PANOSCONFIG"]
  name = "ethernet1/2"
  vsys = "vsys1"
  mode = "layer3"
  enable_dhcp = true
  create_dhcp_default_route = false
  management_profile = "${panos_management_profile.MGMTPROFILE.name}"
  comment = "Configured for trusted traffic"
}

# Zones
resource "panos_zone" "UNTRUSTED" {
  name = "Untrusted"
  mode = "layer3"
  interfaces = ["${panos_ethernet_interface.UNTRUSTED.name}"]
}

resource "panos_zone" "TRUSTED" {
  name = "Trusted"
  mode = "layer3"
  interfaces = ["${panos_ethernet_interface.TRUSTED.name}"]
}

# Router
resource "panos_virtual_router" "VROUTER" {
  depends_on = ["panos_general_settings.PANOSCONFIG"]
  name = "default"
  static_dist = 15
}

resource "panos_virtual_router_entry" "UNTRUSTED" {
    virtual_router = "${panos_virtual_router.VROUTER.name}"
    interface = "${panos_ethernet_interface.UNTRUSTED.name}"
}

resource "panos_virtual_router_entry" "TRUSTED" {
    virtual_router = "${panos_virtual_router.VROUTER.name}"
    interface = "${panos_ethernet_interface.TRUSTED.name}"
}

# Routes
resource "panos_static_route_ipv4" "OUTBOUND" {
    name = "Outbound"
    virtual_router = "${panos_virtual_router.VROUTER.name}"
    destination = "0.0.0.0/0"
    next_hop = "10.5.1.1"
    interface = "${panos_ethernet_interface.UNTRUSTED.name}"
}

resource "panos_static_route_ipv4" "TOWEB" {
    name = "To-Web"
    virtual_router = "${panos_virtual_router.VROUTER.name}"
    destination = "10.5.3.0/24"
    next_hop = "10.5.2.1"
    interface = "${panos_ethernet_interface.TRUSTED.name}"
}

# Security Policy
resource "panos_security_policy" "TOINTERNET" {
  rule {
    name = "allow local network to internet"
    source_zones = ["${panos_zone.TRUSTED.name}"]
    source_addresses = ["any"]
    source_users = ["any"]
    hip_profiles = ["any"]
    destination_zones = ["${panos_zone.UNTRUSTED.name}"]
    destination_addresses = ["any"]
    applications = ["any"]
    services = ["any"]
    categories = ["any"]
    action = "allow"
    log_start = true
  }
  # Explicit deny all
  rule {
    name = "deny all"
    source_zones = ["any"]
    source_addresses = ["any"]
    source_users = ["any"]
    hip_profiles = ["any"]
    destination_zones = ["any"]
    destination_addresses = ["any"]
    applications = ["any"]
    services = ["any"]
    categories = ["any"]
    action = "allow"
    log_start = true
  }
}
resource "panos_address_object" "WEBSUBNET" {
    name = "localnet"
    value = "10.5.3.0/24"
    description = "The 10.5.3.0/24 network"
}

resource "panos_address_object" "TRUSTEDIP" {
    name = "trusted_ip"
    value = "10.5.2.4"
    description = "Inbound Internet"
}

resource "panos_address_object" "UNTRUSTEDIP" {
    name = "untrusted_ip"
    value = "10.5.1.4"
    description = "Outbound Internet"
}

resource "panos_nat_rule" "INTERNET_ACCESS" {
  name = "InternetAccess"
  source_zones = ["Trusted"]
  destination_zone = "Untrusted"
  source_addresses = ["any"]
  destination_addresses = ["any"]
  sat_type = "dynamic-ip-and-port"
  sat_address_type = "interface-address"
  sat_interface = "${panos_ethernet_interface.UNTRUSTED.name}"
}



# Management Profile
resource "panos_management_profile" "MGMTPROFILE" {
  depends_on = ["panos_general_settings.PANOSCONFIG"]
  name = "allow ping"
  ping = true
}