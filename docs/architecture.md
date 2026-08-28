# Architecture

This project models a small Azure web tier designed to explore networking and systems architecture. Terraform connects a public Load Balancer to private VM Scale Set instances, adds health-aware routing and autoscaling, and gives the subnet a dedicated outbound path.

## Diagram

```mermaid
flowchart LR
    client[Internet client]
    admin[Administrator]
    packages[Package repositories]
    monitor[Azure Monitor autoscale]
    bootstrap[user_Data.sh]

    subgraph rg[Azure resource group]
        public_ip[Standard public IP<br/>Zones 1, 2, 3]
        load_balancer[Standard Load Balancer<br/>Frontend TCP 80]
        nat_ip[NAT public IP]
        nat_gateway[NAT Gateway]

        subgraph vnet[Virtual network 10.0.0.0/16]
            subgraph subnet[Subnet 10.0.0.0/20 and subnet NSG]
                backend_pool[Load Balancer backend pool]
                vmss[Orchestrated VM Scale Set<br/>Zone 1 · initial capacity 3<br/>autoscale range 1-10]
                app[Ubuntu VM instances<br/>FastAPI managed by systemd<br/>TCP 8000]
            end
        end
    end

    client -->|HTTP TCP 80| public_ip
    public_ip --> load_balancer
    load_balancer -->|TCP 80 to 8000| backend_pool
    load_balancer -.->|HTTP probe / on 8000| backend_pool
    backend_pool --> vmss
    vmss --> app
    admin -.->|TCP 50000-50010 to 22<br/>trusted CIDR only| load_balancer
    load_balancer -.-> vmss
    bootstrap -.->|cloud-init custom data| vmss
    monitor -->|CPU scale actions| vmss
    app -->|outbound traffic| nat_gateway
    nat_gateway --> nat_ip
    nat_ip --> packages
```

Solid arrows show application and outbound traffic. Dotted arrows show probes, provisioning, or administrative paths.

## Request and control flows

| Flow | Behavior |
| --- | --- |
| Public HTTP | The Standard public IP receives TCP 80 traffic. The Load Balancer forwards it to backend port 8000 on healthy VMSS instances. |
| Health probe | The Load Balancer requests `/` over HTTP on port 8000. Failed probes remove an instance from traffic rotation. |
| Provisioning | Terraform supplies `user_Data.sh` as base64-encoded custom data. Cloud-init installs the application and enables its `systemd` service. |
| Autoscaling | Azure Monitor adds one instance above 80% average CPU and removes one below 10%, using five-minute evaluation windows. |
| Outbound access | VMSS instances use the subnet-associated NAT Gateway for package installation and other internet egress. |
| SSH | The Load Balancer maps frontend ports 50000-50010 to backend port 22. The NSG restricts the source to `admin_source_cidr`. |

## Security boundaries

- The subnet NSG applies to every VMSS network interface.
- Public clients can reach only the FastAPI backend port used by the Load Balancer rule.
- Azure Load Balancer probe traffic has a separate NSG rule.
- SSH password authentication is disabled, and the network path is restricted to a caller-supplied administrator CIDR.
- VMSS instances have no individual public IP addresses.
- Outbound traffic uses the NAT Gateway rather than Load Balancer SNAT.
- The bootstrap data contains no credentials or secrets.

## Availability model

- The Load Balancer frontend public IP declares Zones 1, 2, and 3.
- The VMSS begins with three instances and uses max fault-domain spreading within Zone 1.
- The health probe prevents an unhealthy application instance from receiving new requests.
- CPU autoscaling adjusts capacity between 1 and 10 instances.
- All compute remains in Zone 1, and the minimum capacity is one. This design demonstrates instance-level availability and elastic capacity but does not provide availability-zone resilience.

## Production considerations

A production evolution could spread compute across multiple availability zones, keep at least two instances, terminate TLS through an appropriate ingress service, store Terraform state remotely, add centralized telemetry, and validate plans through CI.
