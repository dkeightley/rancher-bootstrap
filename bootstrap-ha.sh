#!/bin/bash

usage () {
    echo "bootstrap-ha.sh [create | delete] <args>
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
        bootstrap-ha.sh create -n rancher-lab -d r.domain.com -o"
}

testcredentials () {
    case ${_provider} in
    aws)
        if aws --version > /dev/null 2>&1
          then
              _iam=`aws sts get-caller-identity | jq -r '.Arn'`
              if [ $? -eq 0 ]
                then
                  echo "[Info] ${_scope} | Using the following IAM entity: ${_iam}"
                else
                  echo "[Error] ${_scope} | We'll need the AWS CLI configured with credentials, please configure and run me again"
                  exit 1
              fi
        fi
        ;;
    *)
        echo "Sorry, on the to do list"
        exit 1
        ;;
    esac
}

testprereqs () {
    for _command in aws terraform rke curl jq
      do
        if ! ${_command} --version > /dev/null 2>&1
          then
            echo "[Error] ${_scope} | Can't find the ${_command}, please check or install it"
            exit 1
        fi
    done
}

adminip () {
    _pubip="$(curl -s ifconfig.io)"
    if echo $_pubip | grep "." > /dev/null 2>&1
      then
        _adminip="$_pubip/32"
    elif echo $_pubip | grep ":" > /dev/null 2>&1
      then
        _adminip="$_pubip/64"
    fi
}

importkey () {
    if [ ! -f ${_pubsshkey} ]
      then
        echo "[Info] ${_scope} | Ooops, it looks like that public SSH key doesn't exist"
        echo "Shall I create a key for you?"
        echo -n "     y/n: "
        read _reply
        if [[ ! ${_reply} =~ ^[Yy]$ ]]
          then
            echo -e "\n Ok, lets revist this later..."
            exit 1
          else
            ssh-keygen -t rsa -b 2048 -f ~/.ssh/${_name}
            _pubsshkey="~/.ssh/${_name}"
            ssh-add ~/.ssh/${_name}
        fi
    fi
    case ${_provider} in
      aws)
        aws ec2 describe-key-pairs --key-name ${_name}-keypair --region ${_region} > /dev/null 2>&1
        if [ $? -ne 0 ]
          then 
            aws ec2 import-key-pair --region ${_region} --key-name ${_name}-keypair --public-key-material file://${_pubsshkey}
          else
            echo "[Info] ${_scope} | Skipping key pair, it already exists"
        fi
        ;;
      *)
        echo "Sorry, on the to do list"
        exit 1
        ;;
    esac
    if ! ps -a | grep ssh-agent > /dev/null 2>&1
      then
          echo "[Error] ${_scope} | Looks like the ssh-agent isn't running, please make sure it's running and ssh-add your private SSH key"
          exit 1
    fi
}

terraformvars () {
    ## Collect VPC details from VPC terraform state
    _publicsubnet="$(terraform output --state=./terraform.vpc.${_region}.tfstate public-subnet)"
    _vpc="$(terraform output --state=./terraform.vpc.${_region}.tfstate vpc)"
    if [[ -n ${_name} && -n ${_region} ]]
      then
cat <<- EOF > .${_region}.${_name}.ha.terraform.tfvars
    name = "${_name}"
    region = "${_region}"
    admin-ip = "${_adminip}"
    key-name = "${_name}-keypair"
    nodes = ${_nodes}
    load-balancer = ${_nlb}
    vpc = "${_vpc}"
    public-subnet = ${_publicsubnet}
    instance-type = "${_instancetype}"
EOF
    fi
}

terraformapply () {
    if [ ! -d .terraform ]
      then
        if ! terraform init terraform/${_provider}/rancher-ha > /dev/null 2>&1
          then
            echo "[Error] ${_scope} | Something went wrong with initialising terraform"
            exit 1
        fi
    fi
    terraform apply -var-file=./.${_region}.${_name}.ha.terraform.tfvars -state=./terraform.ha.${_region}.${_name}.tfstate ${_imfeelinglucky} terraform/${_provider}/rancher-ha
    if [ $? -ne 0 ]
      then
        echo "[Error] ${_scope} | Something went wrong with applying terraform"
        exit 1
    fi
}

buildclusteryml () {
    if [ ! -f ${_configdir}/.example.cluster.yml ]
      then
        echo "[Error] ${_scope} | Appears my .example.rancher-cluster.yml file is missing, i'll need that, a little help please..."
        exit 1
    fi
    _clusteryaml="${_configdir}/${_name}-ha.cluster.yml"
    if [ ! -f ${_clusteryaml} ]
      then
        cp ${_configdir}/.example.cluster.yml ${_clusteryaml}
      else
        echo "[Info] ${_scope} | Looks like a cluster.yml exists, taking a backup"
        mv ${_clusteryaml} ${_configdir}/.bkp.`date "+%F-%T"`.${_name}.cluster.yml
        cp ${_configdir}/.example.cluster.yml ${_clusteryaml}
    fi
    if [ ${_provider} = "aws" ]
      then
        aws ec2 describe-instances --filters "Name=tag:Name,Values=${_name}-ha-asg" "Name=instance-state-name,Values=running" --region ${_region} | jq -r '.Reservations[].Instances[] | .PublicIpAddress + " " + .PrivateIpAddress' > ${_configdir}/.tmp.nodes.txt
        _running=`cat ${_configdir}/.tmp.nodes.txt | wc -l`
        if [ ${_running} -eq ${_nodes} ]
        then
          for _num in `seq 1 ${_nodes}`
            do
              pub_ip=`awk '{ if (NR=='$_num') print $1 }' ${_configdir}/.tmp.nodes.txt`
              priv_ip=`awk '{ if (NR=='$_num') print $2 }' ${_configdir}/.tmp.nodes.txt`
              sed -i '' "s|n${_num}_public_ip|${pub_ip}|; s|n${_num}_private_ip|${priv_ip}|" ${_clusteryaml} 
            done
          sed -i '' "s|^cluster_name.*|cluster_name: ${_name}|" ${_clusteryaml}  
        else
            echo "[Error] ${_scope} | Number of nodes is not what we expected, ${_running} when we should have ${_nodes}"
            exit 1
        fi
        rm ${_configdir}/.tmp.nodes.txt
    fi  
}

waitfornodes () {
    _node_ips=`grep ' address:' ${_clusteryaml} | awk '{print $3}'`
    for _ip in ${_node_ips}
      do 
        echo -n "Waiting on $_ip: "
        while ! ping -c1 $_ip >/dev/null 2>&1
          do
            sleep 2
            echo -n "."
          done
        echo
      done
    sleep 2 # docker is being installed on bootstrap
}

rkeup () {
    echo "[Info] ${_scope} | Running RKE to build the rancher server cluster"
    rke up --ssh-agent-auth --config ${_clusteryaml}
    if [ $? -ne 0 ]
      then
        echo "[Error] ${_scope} | Something went wrong with 'rke up'"
        exit 1
    fi
}

checknodes () {
    export KUBECONFIG="`pwd`/${_configdir}/kube_config_${_name}-ha.cluster.yml"
    kubectl get nodes -o wide
}

installtiller () {
    kubectl apply -f kubernetes/tiller
    helm init --service-account tiller
    echo "[Info] ${_scope} | Testing tiller install"
    kubectl -n kube-system rollout status deploy/tiller-deploy
    helm version
}

installcertmanager () {
    echo "[Info] ${_scope} | Starting cert-manager install"
    kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml
    kubectl apply -f kubernetes/cert-manager
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install \
      --name cert-manager \
      --namespace cert-manager \
      --version v0.9.1 \
      jetstack/cert-manager
    # wait for the webhook to be ready
    kubectl wait -n cert-manager pod --selector app=webhook --for condition=ready --timeout=60s
    sleep 5
}

installrancher () {
    echo "[Info] ${_scope} | Starting Rancher Server install"
    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
    helm repo update
    helm install rancher-stable/rancher \
      --name rancher \
      --namespace cattle-system \
      --set hostname=${_serverdomain} \
      --set ingress.tls.source=letsEncrypt \
      --set letsEncrypt.email=${_email} \
      --set rancherImageTag=${_ranchertag}
    kubectl -n cattle-system rollout status deploy/rancher -w
    helm ls
}

rkeremove () {
    echo "[Info] ${_scope} | Running RKE to remove the rancher server cluster"
    _clusteryaml="${_configdir}/${_name}-ha.cluster.yml"
    _rkestate="${_configdir}/${_name}-ha.cluster.rkestate"
    _kubeconfig="${_configdir}/kube_config_${_name}-ha.cluster.yml"
    cp ${_clusteryaml} ${_configdir}/.bkp.`date "+%F-%T"`.${_name}.cluster.yml
    cp ${_rkestate} ${_configdir}/.bkp.`date "+%F-%T"`.${_name}.cluster.rkestate
    cp ${_kubeconfig} ${_configdir}/.bkp.`date "+%F-%T"`.kube_config_${_name}.cluster.yml
    rke remove --ssh-agent-auth --config ${_clusteryaml} 
    if [ $? -ne 0 ]
      then
        echo "[Error] ${_scope} | Something went wrong with 'rke remove'"
        exit 1
    fi
    rm ${_clusteryaml}
}

terraformdestroy () {
    if [ -z ${_imfeelinglucky} ]
      then
        echo "Careful there, are you sure you want to destory everything?"
        echo -n "    y/n: "
        read _reply
        if [[ ! ${_reply} =~ ^[Yy]$ ]]
          then
            echo -e "\n Ok, lets revist this later..."
            exit 1
        fi
    fi
    terraform destroy -var-file=./.${_region}.${_name}.ha.terraform.tfvars -state=./terraform.ha.${_region}.${_name}.tfstate ${_imfeelinglucky} terraform/${_provider}/rancher-ha
    if [ $? -ne 0 ]
      then
        echo "[Error] ${_scope} | Something went wrong with terraform"
        exit 1
    fi
    rm .${_region}.${_name}.ha.terraform.tfvars
    rm terraform.ha.${_region}.${_name}.tfstate*
}

deletekey () {
    case ${_provider} in
    aws)
        aws ec2 delete-key-pair --region ${_region} --key-name ${_name}-keypair
        ;;
    *)
        echo "Sorry, on the to do list"
        exit 1
        ;;
    esac
}

case "$1" in
  create)
      _create=1
      shift 1
      ;;
  delete)
      _delete=1
      shift 1
      ;;
esac

while getopts "khlsahot:n:i:r:p:d:c:e:z:" opt
  do
    case ${opt} in
      a)
          _imfeelinglucky="-auto-approve"
          ;;
      n)
          _opt_name=${OPTARG}
          ;;
      i)
          _opt_pubsshkey=${OPTARG}
          ;;
      r)
          _opt_region=${OPTARG}
          ;;
      p)
          _opt_provider=${OPTARG}
          ;;
      c)
          _opt_nodes=${OPTARG}
          ;;
      k)
          _dontinstallrancher=1
          ;;
      o)
          _terraformonly=1
          ;;
      s)
          _rancheronly=1
          ;;
      t)
          _opt_ranchertag=${OPTARG}
          ;;
      d)
          _serverdomain=${OPTARG}
          ;;
      e)
          _opt_email=${OPTARG}
          ;;
      z)
          _opt_instancetype=${OPTARG}
          ;;
      l)
          _opt_nlb=0
          ;;
      h)
          usage
          exit 1
          ;;
      *)
          usage
          exit 1
          ;;
    esac
done

# Defaults
_nlb=${_opt_nlb:-1}
_region=${_opt_region:-us-east-1}
_name=${_opt_name:-rancher-lab}
_pubsshkey=${_opt_pubsshkey:-~/.ssh/id_rsa.pub}
_provider=${_opt_provider:-aws}
_nodes=${_opt_nodes:-3}
_ranchertag=${_opt_ranchertag:-stable}
_email=${_opt_email:-postmaster@$_serverdomain}
_instancetype=${_opt_instancetype:-t3a.medium}
_configdir=config
_scope=HA

if ! [[ -n "${_create}" || -n "${_delete}" ]]
  then
    echo "[Error] ${_scope} | Sorry, I need a create or delete operation, check out the -h usage."
    exit 1
fi
if [ -n "${_create}" ]
  then
    if [ -z "${_serverdomain}" ]
      then
        echo "[Error] ${_scope} | Hey, looks like we didn't get a server domain, to create valid certs I'll need a valid domain, please rerun with the '-d' flag"
        exit 1
    fi
    if [ -n "${_rancheronly}" ]
      then
        checknodes
        installtiller
        installcertmanager
        installrancher
        exit 0
    fi
    testcredentials
    testprereqs
    adminip
    importkey
    if [ -z "${_nodes}" ]
      then
        _nodes=3 # default
    fi
    terraformvars
    if [ -n "${_terraformonly}" ]
      then
        terraformapply
        exit 0
    fi
    if [ -z "${_imfeelinglucky}" ]
      then
        for _function in terraformapply buildclusteryml rkeup checknodes
          do
            echo "[Info] ${_scope} | We're ready to start the ${_function} function, are we good to go?"
            echo -n "    y/n: "
            read _reply
            if [[ ! ${_reply} =~ ^[Yy]$ ]]
              then
                echo -e "\nOk, lets revist this later..."
                exit 1
              else
                echo -e "\n[Info] ${_scope} | Starting ${_function} now"
                ${_function}
                if [ ${_function} = "buildclusteryml" ]
                  then
                    waitfornodes
                fi
            fi
          done
      else
        terraformapply
        buildclusteryml
        waitfornodes
        rkeup
        checknodes
        if [ -z "${_dontinstallrancher}" ]
          then
            installtiller
            installcertmanager
            installrancher
        fi
    fi
  echo; terraform output -state=./terraform.ha.${_region}.${_name}.tfstate
  echo; echo  "--- Use the following command to interact with the new cluster:"
  echo; echo "export KUBECONFIG="`pwd`/${_configdir}/kube_config_${_name}-ha.cluster.yml""
fi
if [ -n "${_delete}" ]
  then
    if [ -n "${_terraformonly}" ]
      then
        terraformdestroy
        exit 0
    fi
    if [ -z "${_imfeelinglucky}" ]
      then
        for _function in rkeremove terraformdestroy deletekey
          do
            echo "[Info] ${_scope} | We're ready to start the ${_function} function, are we good to go?"
            echo -n "    y/n: "
            read _reply
            if [[ ! ${_reply} =~ ^[Yy]$ ]]
              then
                echo -e "\nOk, lets revist this later..."
                exit 1
              else
                echo -e "\n[Info] ${_scope} | Starting ${_function} now"
                ${_function}
            fi
          done
      else
        rkeremove
        terraformdestroy
        deletekey
    fi
fi