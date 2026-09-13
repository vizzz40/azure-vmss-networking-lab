# Architecture

This project models a small Azure web tier designed to explore networking and systems architecture. Terraform connects a public Load Balancer to private VM Scale Set instances, adds health-aware routing and autoscaling, and gives the subnet a dedicated outbound path.

## Diagram

```mermaid
flowchart TB
    client["Internet client"]
    admin["Administrator<br/>Trusted IP / CIDR"]

    subgraph azure["Azure · Italy North — default region"]
        lb["Standard Load Balancer + public IP<br/>Frontend TCP 80 · public IP zones 1–3"]

        subgraph network["Virtual network · 10.0.0.0/16"]
            subgraph subnet["Subnet · 10.0.0.0/20 · NSG"]
                pool["Backend pool"]
                vmss["VM Scale Set · Zone 1<br/>3 initial instances · autoscale 1–10"]
                app["Ubuntu 22.04 · FastAPI<br/>systemd service · TCP 8000"]
                pool --> vmss --> app
            end
            nat["NAT Gateway + public IP"]
        end

        monitor["Azure Monitor<br/>CPU-based autoscaling"]
        bootstrap["Cloud-init<br/>user_Data.sh"]
    end

    packages["Internet / package repositories"]

    client -->|"HTTP · TCP 80"| lb
    lb -->|"Forward to TCP 8000"| pool
    lb -.->|"HTTP health probe · /"| app
    admin -.->|"SSH · ports 50000–50010 → 22"| lb
    lb -.->|"SSH forwarding"| vmss
    monitor -.->|"Adjust capacity"| vmss
    bootstrap -.->|"Provision instances"| vmss
    app -->|"Outbound connections"| nat
    nat --> packages
```

The diagram shows logical paths using the default region and network ranges. Solid arrows show application and outbound traffic. Dotted arrows show health probes, SSH, provisioning and scaling.

## Request and control flows

| Flow | Behavior |
| --- | --- |
| Public HTTP | The Standard public IP receives TCP 80 traffic. The Load Balancer forwards it to backend port 8000 on healthy VMSS instances. |
| Health probe | The Load Balancer requests `/` over HTTP on port 8000. An unhealthy probe status stops new flows to that instance. |
| Provisioning | Terraform supplies `user_Data.sh` as base64-encoded custom data. Cloud-init installs the application and enables its `systemd` service. |
| Autoscaling | Azure Monitor adds one instance above 80% average CPU and removes one below 10%, using five-minute evaluation windows and a one-minute cooldown after each action. |
| Outbound access | VMSS instances use the subnet-associated NAT Gateway for package installation and other internet egress. |
| SSH | The Load Balancer maps frontend ports 50000-50010 to backend port 22. The NSG restricts the source to `admin_source_cidr`. |

## Security boundaries

- The subnet NSG applies to every VMSS network interface.
- Public application traffic reaches TCP 8000 through the Load Balancer; a separate inbound NAT rule provides SSH access.
- Azure Load Balancer probe traffic has a separate NSG rule.
- SSH password authentication is disabled, and the network path is restricted to a caller-supplied administrator CIDR.
- VMSS instances have no individual public IP addresses.
- Outbound traffic uses the NAT Gateway rather than Load Balancer SNAT.
- Default NSG rules still allow virtual-network traffic and outbound internet access; NAT Gateway provides an outbound address, not destination filtering.
- The bootstrap data contains no credentials or secrets.

## Availability model

- The Load Balancer frontend public IP declares Zones 1, 2, and 3.
- The VMSS begins with three instances and uses max fault-domain spreading within Zone 1.
- The health probe prevents an unhealthy application instance from receiving new requests.
- CPU autoscaling adjusts capacity between 1 and 10 instances.
- All compute remains in Zone 1, and the minimum capacity is one. This design demonstrates instance-level availability and elastic capacity but does not provide availability-zone resilience.

## Production considerations

A production evolution could spread compute across multiple availability zones, keep at least two instances, terminate TLS through an appropriate ingress service, store Terraform state remotely, and add centralized telemetry. The current CI workflow performs static validation; it does not plan or deploy Azure resources.
