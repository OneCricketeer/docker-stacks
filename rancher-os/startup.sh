#!/usr/bin/env bash

set -ua

function wait_for_it {
  ./dockerize-darwin -timeout "$1s" -wait "tcp://$2"
}

RANCHER_OS_VER="v1.5.1" # script first tested with v1.2.0

# Number of VMs
: ${RANCHER_NODES:=3}

# VM CPU & memory sizes
: ${VIRTUALBOX_MEMORY_SIZE:=$(((1024 * 2) + 512))}
export VIRTUALBOX_CPU_COUNT=2

# This is only used when provisioning Rancher Agents. Requires an external Rancher server. RancherOS itself does not require either. 
export RANCHER_AGENT_VER='v1.2.11' # script first tested with v1.2.10

# Downloading RancherOS
VIRTUALBOX_ISO=https://releases.rancher.com/os/$RANCHER_OS_VER/rancheros.iso
if [ ! -f "rancheros-${RANCHER_OS_VER}.iso" ]; then
    echo -e "Rancher OS ISO (${RANCHER_OS_VER}) not available. Downloading..."
    wget -O "rancheros-${RANCHER_OS_VER}.iso" -nc $VIRTUALBOX_ISO
fi

# Start docker registry locally for caching docker images between RancherOS nodes
docker-compose up -d registry

echo "Waiting for Docker Registry before caching Docker images..."

[ -f rancher.env ] && source rancher.env
: ${DOCKER_REGISTRY:="$EXT_IP:5000"}
wait_for_it 10 $DOCKER_REGISTRY && sleep 5

docker-compose up -d rancher-server
echo "Waiting for Rancher Server..." && wait_for_it 30 localhost:8080 && sleep 75

if [[ "x" == "x${EXT_IP}" ]]; then 
  echo "WARNING: external IP is not provided. Going to try to use ifconfig to look it up"
  # This at least works on a Mac, with the first IP listed as the primary external one...
  # TODO: Existance of ip command would likely mean a linux box, so should probably test that someday
  EXT_IP=$(ifconfig | grep -E "([0-9]{1,3}\.){3}[0-9]{1,3}" \
     | grep -v 127.0.0.1 | awk '{ print $2 }' | cut -f2 -d: | head -n1)
fi

# note: Rancher server is only required when provisioning rancher agents. 
: ${RANCHER_SERVER:="$EXT_IP:8080"}

echo "Initializing Rancher API..."
#curl -X PUT -w "\n" \
#  -H 'Accept: application/json' \
#  -H 'Content-Type: application/json' \
#  -d '{"activeValue":"http://'${RANCHER_SERVER}'", "id":"api.host", "name":"api.host", "source":"Database", "value":"http://'${RANCHER_SERVER}'"}' \
#  "http://${RANCHER_SERVER}/v2-beta/settings/api.host"


curl -X PUT -w "\n" \
    -H 'x-api-action-links: actionLinks' \
    -H 'content-type: application/json' -H 'accept: application/json' \
    --data-binary '{"id":"api.host","name":"api.host", "type":"activeSetting","baseType":"setting", "inDb":true,"source":"Database", "activeValue":"http://'${RANCHER_SERVER}'","value":"http://'${RANCHER_SERVER}'"}' \
    "${RANCHER_SERVER}/v2-beta/settings/api.host"

if [[ "x" == "x${RANCHER_REGISTRATION_URL}" ]]; then
  echo "RANCHER_REGISTRATION_URL is unset. Using Rancher API"
  N=0
  while true; do
    if [ $N -gt 30 ]; then
      echo "Unable to get the registration url"
      echo "Please open http://${RANCHER_SERVER}/env/1a5/infra/hosts/add?driver=custom to initialize a token and try running this script again"
      exit 1
    fi
    RANCHER_REGISTRATION_URL=$(curl -s http://${RANCHER_SERVER}/v2-beta/registrationtokens | jq '.data[0].links.registrationUrl')
    if [[ $? -ne 0 ]] || [[ "x" == "x${RANCHER_REGISTRATION_URL}" ]] || [[ "null" == ${RANCHER_REGISTRATION_URL} ]]; then
      echo -n "."
    else
      echo ""
      break
    fi
    N=$(($N+1))
    sleep 2
  done
fi




export VIRTUALBOX_MEMORY_SIZE
export VIRTUALBOX_HOSTONLY_CIDR="192.168.99.1/24"
export VIRTUALBOX_BOOT2DOCKER_URL="file://$(pwd)/rancheros-${RANCHER_OS_VER}.iso"
set -xv
for N in `seq 1 $RANCHER_NODES`; do
  vm_id="rancher$(printf "%02d" $N)"
  # Change IP's if using different VM subnet
  vm_ip="192.168.99.1$(printf '%02d' $(($N - 1)))"
  if [[ ! $(docker-machine inspect $vm_id >/dev/null) ]]; then
    # Create a new machine -- Uses above boot2docker url for image
    docker-machine create -d virtualbox $vm_id

    # Enable insecure docker registries
    if [[ ! -z "$DOCKER_REGISTRY" ]]; then
      docker-machine ssh "$vm_id" \
        "sudo ros s stop docker && sudo mkdir -p /etc/docker \
          && echo '{\"insecure-registries\": [\"${DOCKER_REGISTRY}\", \"${DOCKER_REGISTRY_FQDN}:5000\"]}' | sudo tee /etc/docker/daemon.json >/dev/null \
          && sudo chown root:root /etc/docker/daemon.json && sudo chmod 600 /etc/docker/daemon.json \
          && echo '$EXT_IP   $DOCKER_REGISTRY_FQDN' | sudo tee -a /etc/hosts >/dev/null \
          && sudo ros s start docker"
      sleep 20
    fi

    ## At this point, the node has docker running and can pull any docker image via 'docker pull jomoore.docker:5000/image:tag'
    ## TODO: bootstrap kubernetes, hashistack, docker-swarm, mesos, etc.


    ## refactor this: rancher_agent $vm_id $vm_ip $DOCKER_REGISTRY $RANCHER_AGENT_VER $RANCHER_SERVER $RANCHER_TOKEN 'RANCHER_ENV=dev'
    # Start Rancher Agent on each machine and register with Rancher server
    docker-machine ssh "$vm_id" \
      "sudo docker run --rm --privileged \
          -e CATTLE_HOST_LABELS='RANCHER_ENV=dev' \
          -e CATTLE_AGENT_IP='$vm_ip' \
          -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher \
          ${DOCKER_REGISTRY}/rancher/agent:${RANCHER_AGENT_VER} $RANCHER_REGISTRATION_URL"
  fi
done
