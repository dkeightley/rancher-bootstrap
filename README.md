## rancher-bootstrap

An automated approach to launching the resources and instances for HA Rancher Servers. 

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
        -a   optional | i'm feeling lucky (yes to everything)
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
        -a   i'm feeling lucky (yes to everything)
        -k   create RKE cluster only, don't install rancher/server
        -o   run terraform only

    example:

      Create everything, but prompt during the functions:
        bootstrap-rke.sh create -n rancher-rke -r us-east-1 -i ~/.ssh/id_rsa.pub

      Just create/update terraform, useful if your admin IP has changed
        bootstrap-rke.sh create -n rancher-rke -o
```