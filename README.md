# rancher-bootstrap

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

# Examples

## Create a VPC

- Create a VPC for use with the Rancher server and/or downstream clusters, this VPC will automatically be used for further resources.

```bash
./bootstrap-vpc.sh create -a -n test-vpc
```

*Note: override the default region with `-r <region>`*

  - This VPC will now be used for any further resources in that region
  - Create some further resources below...

## Create a 3 node cluster and run an HA Rancher server

```bash
./bootstrap-ha.sh create -a -n ha-rancher -d <domain name> -e <email for letsencrypt>
```
  *Note: provide an SSH key in a custom location with `-i </path/to/key.pub>`, provide a specific Rancher version with `-t <v2.3.0>`, override the region with `-r <region>`*

  - Add a CNAME or alias for your domain name to the NLB that is created.
  - Access the Rancher server via the NLB.

## Create a single node cluster and run Rancher server via Helm (testing environment)

```bash
./bootstrap-ha.sh create -a -n test-rancher -d <domain name> -e <email for letsencrypt> -c 1 -l
```

  - No NLB is created (`-l`)
  - Add an A record for your domain name to the IP Address of the node (needed for SSL).

## Create a 3 node RKE cluster only

```bash
./bootstrap-rke.sh create -a -n rke-cluster 
```

## Create a single instance and run Rancher as a container (testing environment)

```bash
./bootstrap-rke.sh create -a -n single-rancher -o -c 1
```

- Login and run the Rancher container (example):

```bash
docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  -v /opt/rancher:/var/lib/rancher \
  rancher/rancher:latest
```

  - Access the Rancher server via the Public IP of the node or add an A record to your domain.

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
        bootstrap-vpc.sh -n testing123
```

### `bootstrap-ha.sh`

Creates the resources needed for an HA Rancher Server

```
bootstrap-ha.sh [create | delete] <args>
    args:
        -n   name to use for all resources and cluster                      default: rancher-lab
        -d   domain for rancher/server (uses letsencrypt certificate)       default: none
        -e   email for letsencrypt certificate                              default: postmaster@<domain from -d>
        -i   pathname to your public SSH key                                default: ~/.ssh/id_rsa.pub
        -p   optional | provider (aws only so far)                          default: aws
        -r   optional | region to run the resources                         default: us-east-1
        -c   optional | number of nodes to launch                           default: 3
        -a   optional | i'm feeling lucky (yes to everything)               default: prompt me
        -z   optional | instance type                                       default: t3a.medium
        -k   optional | RKE cluster only, don't install rancher/server      default: run everything
        -o   optional | terraform only                                      default: run everything
        -s   optional | rancher server only                                 default: run everything
        -t   optional | rancher/server tag, eg: v2.3.0                      default: stable
        -l   optional | don't create a load balancer                        default: create an NLB

    example:

      Create everything, but prompt during the functions:
        bootstrap-ha.sh create -n rancher-lab -r us-east-1 -i ~/.ssh/id_rsa.pub -d r.domain.com

      Just create/update terraform, useful for updating admin security group
        bootstrap-ha.sh create -n rancher-lab -d r.domain.com -o
```

### `bootstrap-rke.sh`

Creates the instances and security groups needed for further provisioning with RKE or the Rancher Server

```
bootstrap-rke.sh [create | delete] <args>
    args:
        -n   name to use for all resources and cluster            default: rancher-lab
        -i   pathname to your public SSH key                      default: ~/.ssh/id_rsa.pub
        -p   optional | provider (aws only so far)                default: aws
        -r   optional | region to run the resources               default: us-east-1
        -c   optional | number of nodes to launch                 default: 3
        -z   optional | instance type                             default: t3a.medium
        -a   optional | i'm feeling lucky (yes to everything)     default: prompt me
        -o   optional | run terraform only                        default: run everything

    example:

      Create everything, but prompt during the functions:
        bootstrap-rke.sh create -n rancher-rke -r us-east-1 -i ~/.ssh/id_rsa.pub

      Just update terraform - useful if your admin IP has changed
        bootstrap-rke.sh -n rancher-rke -o
```