## rancher-bootstrap

An automated approach to launching the resources for Rancher servers and RKE clusters in HA or single node configurations. 

Uses Terraform and bash to automate the creation of:

 - VPC and Security Groups
 - Auto Scaling Groups for instances
 - An NLB for the Rancher Server

**Currently only AWS is supported.**

### Requirements

 - AWS CLI and credentials
 - terraform
 - rke
 - curl
 - jq
 - ssh-agent running, with your SSH key added

## Example

- Create a VPC for use with the Rancher server and/or downstream clusters, this VPC will automatically be used for further resources.

```bash
./bootstrap-vpc.sh create -a -n test-vpc
```

- Create a 3 node cluster and run an **HA** Rancher server.

```bash
./bootstrap-ha.sh create -a -n ha-rancher -d <domain name for SSL certificate>
```
*Note: provide an SSH key in a custom location with `-i </path/to/key.pub>`*

  - Add a CNAME or alias for your domain name to the NLB that is created.
  - Access the Rancher server via the NLB.

**Optional** 

- Create a **single** instance to run a single node Rancher server.

```bash
./bootstrap-ha.sh create -a -n single-rancher -o -c 1
```

  - Login and run the Rancher container:

```bash
docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  -v /opt/rancher:/var/lib/rancher \
  rancher/rancher:latest
```

  - Access the Rancher server via the Public IP of the node.

---

## Usage

### `bootstrap-vpc.sh`

Creates the underlying VPC resources

```
bootstrap-vpc.sh [create | delete] <args>
    args:
        -n   name to use for all resources and cluster          default: rancher-lab
        -p   provider (aws only so far)                         default: aws
        -r   region to run the resources                        default: us-east-1
        -c   VPC CIDR block /16 to use (ex: 172.31)             default: 10.99
        -a   optional | i'm feeling lucky (yes to everything)   default: prompt me

    example:

      Create everything, but prompt during the functions:
        bootstrap-vpc.sh create -n rancher-vpc -p aws -r us-east-1 -c 10.20

      Assume all defaults, but set a name:
        bootstrap-vpc.sh create -n testing123
```

### `bootstrap-ha.sh`

Creates the resources needed for an HA Rancher Server

```
bootstrap-ha.sh [create | delete] <args>
    args:
        -n   name to use for all resources and cluster                      default: rancher-lab
        -p   provider (aws only so far)                                     default: aws
        -r   region to run the resources                                    default: us-east-1
        -d   domain for rancher/server (uses letsencrypt certificate)       default: none
        -i   pathname to your public SSH key                                default: ~/.ssh/id_rsa.pub
        -c   optional | number of nodes to launch                           default: 3
        -a   optional | i'm feeling lucky (yes to everything)               default: prompt me
        -k   optional | RKE cluster only, don't install rancher/server
        -o   optional | terraform only
        -s   optional | rancher server only
        -t   optional | rancher/server tag, eg: v2.3.0 (default: stable)
        -l   optional | don't create a load balancer

    example:

      Create everything, but prompt during the functions:
        bootstrap-ha.sh create -n rancher-lab -r us-east-1 -i ~/.ssh/id_rsa.pub -d r.domain.com

      Just create/update terraform, useful if your admin IP has changed
        bootstrap-ha.sh create -n rancher-lab -o
```

### `bootstrap-rke.sh`

Creates the instances and security groups needed for further provisioning with RKE or the Rancher Server

```
bootstrap-rke.sh [create | delete] <args>
    args:
        -n   name to use for all resources and cluster                      default: rancher-lab
        -p   provider (aws only so far)                                     default: aws
        -r   region to run the resources                                    default: us-east-1
        -i   pathname to your public SSH key                                default: ~/.ssh/id_rsa.pub
        -c   number of nodes to launch                                      default: 3
        -a   i'm feeling lucky (yes to everything)                          default: prompt me
        -o   run terraform only

    example:

      Create everything, but prompt during the functions:
        bootstrap-rke.sh create -n rancher-rke -r us-east-1 -i ~/.ssh/id_rsa.pub

      Just create/update terraform, useful if your admin IP has changed
        bootstrap-rke.sh create -n rancher-rke -o
```