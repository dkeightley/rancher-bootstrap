#!/bin/bash

usage () {
    echo "bootstrap-vpc.sh [create | delete] <args>
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
        bootstrap-vpc.sh -n testing123"
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
        echo " ${_scope} | Sorry, on the to do list"
        exit 1
        ;;
    esac
}

testprereqs () {
    for _command in aws terraform curl
      do
        if ! ${_command} --version > /dev/null 2>&1
          then
            echo "[Error] ${_scope} | Can't find the ${_command}, please check or install it"
            exit 1
        fi
    done
}

terraformvars () {
    if [[ -n ${_name} && -n ${_region} ]]
      then
cat <<- EOF > .${_name}.vpc.terraform.tfvars
    name = "${_name}"
    region = "${_region}"
    vpc-cidr = "${_cidr}"
EOF
    fi
}

terraformapply () {
    if [ ! -d .terraform ]
      then
        if ! terraform init terraform/${_provider}/rancher-vpc > /dev/null 2>&1
          then
            echo "[Error] ${_scope} | Something went wrong with initialising terraform"
            exit 1
        fi
    fi
    terraform apply -var-file=./.${_name}.vpc.terraform.tfvars -state=./terraform.vpc.tfstate ${_imfeelinglucky} terraform/${_provider}/rancher-vpc
    if [ $? -ne 0 ]
      then
        echo "[Error] ${_scope} | Something went wrong with applying terraform"
        exit 1
    fi
}

terraformdestroy () {
    if [ -z ${_imfeelinglucky} ]
      then
        echo "[Info] ${_scope} | Careful there, are you sure you want to destory everything?"
        echo -n "    y/n: "
        read _reply
        if [[ ! ${_reply} =~ ^[Yy]$ ]]
          then
            echo -e "\n Ok, lets revist this later..."
            exit 1
        fi
    fi
    terraform destroy -var-file=./.${_name}.vpc.terraform.tfvars -state=./terraform.vpc.tfstate ${_imfeelinglucky} terraform/${_provider}/rancher-vpc
    if [ $? -ne 0 ]
      then
        echo "[Error] ${_scope} | Something went wrong with terraform"
        exit 1
    fi
    rm .${_name}.vpc.terraform.tfvars
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

while getopts "han:r:p:c:" opt
  do
    case ${opt} in
      a)
          _imfeelinglucky="-auto-approve"
          ;;
      n)
          _opt_name=${OPTARG}
          ;;
      r)
          _opt_region=${OPTARG}
          ;;
      p)
          _opt_provider=${OPTARG}
          ;;
      c)
          _opt_cidr=${OPTARG}
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
_region=${_opt_region:-us-east-1}
_name=${_opt_name:-rancher-lab}
_cidr=${_opt_cidr:-10.99}
_provider=${_opt_provider:-aws}
_scope=VPC

if ! [[ -n "${_create}" || -n "${_delete}" ]]
  then
    echo "[Error] ${_scope} | Sorry, I need a create or delete operation, check out the -h usage."
    exit 1
fi
if [ -n "${_create}" ]
  then
    testcredentials
    testprereqs
    terraformvars
    if [ -z ${_imfeelinglucky} ]
      then
        echo "[Info] ${_scope} | We're ready to terraform apply, are we good to go?"
        echo -n "    y/n: "
        read _reply
        if [[ ! ${_reply} =~ ^[Yy]$ ]]
          then
            echo -e "\nOk, lets revist this later..."
            exit 1
          else
            terraformapply
        fi
      else
        terraformapply
    fi
fi
if [ -n "${_delete}" ]
  then
    if [ -z ${_imfeelinglucky} ]
      then
        echo "[Info] ${_scope} | We're ready to terraform destroy, are we good to go?"
        echo -n "    y/n: "
        read _reply
        if [[ ! ${_reply} =~ ^[Yy]$ ]]
          then
            echo -e "\nOk, lets revist this later..."
            exit 1
          else
            terraformdestroy
        fi
      else
        terraformdestroy
    fi
fi
