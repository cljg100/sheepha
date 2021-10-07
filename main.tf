// Copyright (c) 2017, 2021, Oracle and/or its affiliates. All rights reserved.
// Licensed under the Mozilla Public License v2.0


variable "compartment_ocid" {}
variable "region" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key" {}
variable "ssh_public_key" {}
variable "private_key_openssh" {}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid = var.user_ocid
  fingerprint = var.fingerprint
  private_key = var.private_key
  region = var.region
}

variable "ad_region_mapping" {
  type = map(string)

  default = {
    us-phoenix-1 = 3
    us-ashburn-1 = 2
    sa-saopaulo-1 = 1
  }
}

variable "images" {
  type = map(string)

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.9-2020.10.26-0"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaacirjuulpw2vbdiogz3jtcw3cdd3u5iuangemxq5f5ajfox3aplxa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaabbg2rypwy5pwnzinrutzjbrs3r35vqzwhfjui7yibmydzl7qgn6a"
    sa-saopaulo-1   = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaaudio63gdicxwujhfok7jdyewf6iwl6sgcaqlyk4fvttg3bw6gbpq"
  }
}

data "oci_identity_availability_domain" "tcb_ad1" {
  compartment_id = var.tenancy_ocid
  ad_number      = 1
}

data "oci_identity_availability_domain" "tcb_ad2" {
  compartment_id = var.tenancy_ocid
  ad_number      = 2
}

resource "oci_core_virtual_network" "tcb_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "tcbVCN"
  dns_label      = "tcbvcn"
}

resource "oci_core_subnet" "tcb_subnet1" {
  availability_domain = data.oci.identity_availability_domain.tcb_ad1.name
  cidr_block        = "10.1.20.0/24"
  display_name      = "tcbSubnet1"
  dns_label         = "tcbsubnet1"
  security_list_ids = [oci_core_security_list.tcb_security_list.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.tcb_vcn.id
  route_table_id    = oci_core_route_table.tcb_route_table.id
  dhcp_options_id   = oci_core_virtual_network.tcb_vcn.default_dhcp_options_id
  provisioner "local-exec" {
   command = "sleep 5"
  }
}

resource "oci_core_subnet" "tcb_subnet2" {
  availability_domain = data.oci.identity_availability_domain.tcb_ad2.name
  cidr_block        = "10.1.21.0/24"
  display_name      = "tcbSubnet2"
  dns_label         = "tcbsubnet2"
  security_list_ids = [oci_core_security_list.tcb_security_list.id]
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_virtual_network.tcb_vcn.id
  route_table_id    = oci_core_route_table.tcb_route_table.id
  dhcp_options_id   = oci_core_virtual_network.tcb_vcn.default_dhcp_options_id
  provisioner "local-exec" {
   command = "sleep 5"
  }
}

resource "oci_core_internet_gateway" "tcb_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "tcbIG"
  vcn_id         = oci_core_virtual_network.tcb_vcn.id
}

resource "oci_core_route_table" "tcb_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.tcb_vcn.id
  display_name   = "tcbRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.tcb_internet_gateway.id
  }
}

resource "oci_core_public_ip" "test_reserved_ip" {
  compartment_id = "${var.compartment_ocid}"
  lifetime = "RESERVED"
  lifecycle {
  ignore_changes = [private_ip_id]
  }
}

resource "oci_core_security_list" "tcb_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.tcb_vcn.id
  display_name   = "tcbSecurityList"

  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      max = "80"
      min = "80"
    }
  }
}

resource "oci_core_instance" "webserverha1" {
  availability_domain = data.oci_identity_availability_domain.tcb_ad1.name
  compartment_id      = var.compartment_ocid
  display_name        = "webserverha1"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.tcb_subnet1.id
    display_name     = "primaryvnic_subnet1'"
    assign_public_ip = true
    hostname_label   = "webserverha1"
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  provisioner "file" {
    source      = "deploy_niture.sh"
    destination = "/tmp/deploy_niture.sh"
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "opc"
      private_key = var.private_key_openssh
    }

  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/deploy_niture.sh",
      "/tmp/deploy_niture.sh",
    ]
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "opc"
      private_key = var.private_key_openssh
    }
  }

resource "oci_core_instance" "webserverha2" {
  availability_domain = data.oci_identity_availability_domain.tcb_ad2.name
  compartment_id      = var.compartment_ocid
  display_name        = "webserverha2"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.tcb_subnet2.id
    display_name     = "primaryvnic_subnet2"
    assign_public_ip = true
    hostname_label   = "webserverha2"
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  provisioner "file" {
    source      = "deploy_niture.sh"
    destination = "/tmp/deploy_niture.sh"
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "opc"
      private_key = var.private_key_openssh
    }

  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/deploy_niture.sh",
      "/tmp/deploy_niture.sh",
    ]
    connection {
      type = "ssh"
      host = "${self.public_ip}"
      user = "opc"
      private_key = var.private_key_openssh
    }
  }
/* Load Balancer */

resource "oci_load_balancer" "tcb_lb1" {
  shape          = "100Mbps"
  compartment_id = var.compartment_ocid

  subnet_ids = [
    oci_core_subnet.tcb_subnet1.id,
    oci_core_subnet.tcb_subnet2.id,
  ]

  display_name = "tcb_lb1"
  reserved_ips {
    id = "${oci_core_public_ip.test_reserved_ip.id}"
  }
}

resource "oci_load_balancer" "tcb_lb2" {
  shape          = "100Mbps"
  compartment_id = var.compartment_ocid

  subnet_ids = [
    oci_core_subnet.tcb_subnet1.id,
    oci_core_subnet.tcb_subnet2.id,
  ]

  display_name = "tcb_lb2"
}


variable "load_balancer_shape_details_maximum_bandwidth_in_mbps" {
  default = 100
}

variable "load_balancer_shape_details_minimum_bandwidth_in_mbps" {
  default = 10
}

resource "oci_load_balancer_backend_set" "tcb-lb-bes1" {
  name             = "tcb-lb-bes1"
  load_balancer_id = oci_load_balancer.tcb_lb1.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "HTTP"
    response_body_regex = ".*"
    url_path            = "/"
  }
}

resource "oci_load_balancer_backend_set" "tcb-lb-bes2" {
  name             = "tcb-lb-bes2"
  load_balancer_id = oci_load_balancer.tcb_lb2.id
  policy           = "ROUND_ROBIN"

  health_checker {
    port                = "80"
    protocol            = "TCP"
    response_body_regex = ".*"
    url_path            = "/"
  }

}


resource "oci_load_balancer_listener" "lb-listener1" {
  load_balancer_id         = oci_load_balancer.tcb_lb1.id
  name                     = "http"
  default_backend_set_name = oci_load_balancer_backend_set.tcb-lb-bes1.name
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = "2"
  }
}


resource "oci_load_balancer_listener" "lb-listener2" {
  load_balancer_id         = oci_load_balancer.tcb_lb2.id
  name                     = "tcp"
  default_backend_set_name = oci_load_balancer_backend_set.tcb-lb-bes2.name
  port                     = 80
  protocol                 = "TCP"

  connection_configuration {
    idle_timeout_in_seconds            = "2"
    backend_tcp_proxy_protocol_version = "1"
  }
}

resource "oci_load_balancer_backend" "tcb-lb-be1" {
  load_balancer_id = oci_load_balancer.tcb_lb1.id
  backendset_name  = oci_load_balancer_backend_set.tcb-lb-bes1.name
  ip_address       = oci_core_instance.webserverha1.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_backend" "tcb-lb-be2" {
  load_balancer_id = oci_load_balancer.tcb_lb2.id
  backendset_name  = oci_load_balancer_backend_set.tcb-lb-bes2.name
  ip_address       = oci_core_instance.webserverha2.private_ip
  port             = 80
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}
