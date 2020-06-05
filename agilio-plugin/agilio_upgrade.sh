#!/bin/bash

set -x
echo Executing agilio_upgrade ========================= 

#GENERAL DOCKER CONFIG
DOCKER_USR=customer115 #ENTER_DOCKER_USERNAME_HERE
DOCKER_PASS=customer#115  #ENTER_DOCKER_PASSWORD_HERE
AGILIO_REPO="docker.io/netronomesystems/"

#AGILIO DOCKER CONFIG
#AGILIO_TAG="5.1.0-0.0-centos" 
#AGILIO_TAG="2.38-rhel-queens"
AGILIO_TAG="latest-rhel-queens"
AGILIO_IMAGE="agilio-vrouter:$AGILIO_TAG"

#FORWARDER DOCKER CONFIG
#FORWARDER_TAG="5.1.0-0.0-centos"
#FORWARDER_TAG="2.36-rhel-queens"
FORWARDER_TAG="latest-rhel-queens"
FORWARDER_IMAGE="virtio-forwarder:$FORWARDER_TAG"

docker_login(){
  docker login docker.io -u $DOCKER_USR -p $DOCKER_PASS
}

deploy_agilio_vrt(){
  echo deploying agilio_vrouter container

  docker rm --force agilio_vrouter_dev agilio_vrouter
  docker pull $AGILIO_REPO$AGILIO_IMAGE
  
  docker run -d --restart on-failure --name agilio_vrouter \
  --network=host \
  --pid=host \
  --privileged \
  -v /var/log/containers:/host/var/log/containers \
  -v /:/host \
  -v /etc/sysconfig/network-scripts:/etc/sysconfig/network-scripts \
  -v /etc/sysconfig/network:/etc/sysconfig/network \
  -v /lib/modules:/lib/modules \
  -v /usr/bin/vif:/usr/bin/vif \
  -v /var/lib/firmware/netronome:/var/lib/firmware/netronome \
  -v /var/run/docker.sock:/var/run/docker.sock \
  $AGILIO_REPO$AGILIO_IMAGE

}


deploy_virtioforwarder(){
  docker rm --force virtio_forwarder_dev virtio_forwarder
  docker pull $AGILIO_REPO$FORWARDER_IMAGE
  
  docker run -d --restart on-failure --name virtio_forwarder \
  --network=host \
  --privileged \
  -v /var/log/containers:/host/var/log/containers \
  -v /etc/agilio:/host/etc/agilio \
  -v /var/run/vrouter:/var/run/vrouter \
  -v /dev/hugepages:/dev/hugepages \
  -v /var/run/virtio-forwarder:/var/run/virtio-forwarder \
  $AGILIO_REPO$FORWARDER_IMAGE

}

if [[ `hostname` = *compute*  ]]; then
  rm -rf /tmp/payload
  docker_login
  deploy_agilio_vrt
  deploy_virtioforwarder

fi
