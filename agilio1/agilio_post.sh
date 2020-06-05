#!/bin/bash

set -x
echo Executing agilio_post config 

#GENERAL DOCKER CONFIG
DOCKER_USR=customer115 #ENTER_DOCKER_USERNAME_HERE
DOCKER_PASS=customer#115  #ENTER_DOCKER_PASSWORD_HERE
AGILIO_REPO="docker.io/netronomesystems/"

#AGILIO DOCKER CONFIG
AGILIO_TAG="5.1.0-0.0-centos" 
AGILIO_IMAGE="agilio-vrouter:$AGILIO_TAG"

#FORWARDER DOCKER CONFIG
FORWARDER_TAG="5.1.0-0.0-centos"
FORWARDER_IMAGE="virtio-forwarder:$FORWARDER_TAG"

docker_login(){
  docker login docker.io -u $DOCKER_USR -p $DOCKER_PASS
}

conf_nm(){
  echo configuring NetworkManager
  echo [keyfile] > /etc/NetworkManager/conf.d/nfp.conf
  echo unmanaged-devices=driver:nfp,driver:nfp_netvf >> /etc/NetworkManager/conf.d/nfp.conf
  systemctl restart NetworkManager
}

deploy_agilio_vrt(){
  echo deploying agilio_vrouter container

  docker rm --force agilio_vrouter_dev agilio_vrouter
  docker pull $AGILIO_REPO$AGILIO_IMAGE
  
  docker run -d --restart on-failure --name agilio_vrouter \
  --network=host \
  --privileged \
  -v /var/log/containers:/host/var/log/containers \
  -v /tmp:/host/tmp \
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
  -v /tmp:/host/tmp \
  -v /var/run/vrouter:/var/run/vrouter \
  -v /dev/hugepages:/dev/hugepages \
  -v /var/run/virtio-forwarder:/var/run/virtio-forwarder \
  $AGILIO_REPO$FORWARDER_IMAGE

}

configure_virtioforwarder(){
   echo "configuring virtio-forwarder"
   
   FWD_CONF="/tmp/payload/etc.default.virtioforwarder"
   . /var/lib/docker/volumes/vrouter_port_control/_data/uid_gid.sh
   sed -i "/VIRTIOFWD_SOCKET_OWNER/c\VIRTIOFWD_SOCKET_OWNER=$VHOST_UID" $FWD_CONF
   sed -i "/VIRTIOFWD_SOCKET_GROUP/c\VIRTIOFWD_SOCKET_GROUP=$VHOST_GID" $FWD_CONF
   echo -e "\n # CONFIGURED" >> $FWD_CONF
}

wait_for_payload(){
  while [ ! -d "/tmp/payload" ]; do 
    echo "waiting for payload"
    sleep 1
    done
  #TODO: add timeout
  echo "payload found"
}

configure_nova(){
      echo "configuring nova"
      export NOVA_DIR=var/lib/docker/volumes/vrouter_port_control/_data
      yes | cp -rf /tmp/payload/nova-config/* /$NOVA_DIR/

      echo "patching nova"
      docker exec -u root nova_compute /opt/plugin/bin/update-nova.sh
      docker commit nova_compute 

      echo "configuring pci whitelist $DASH"
      NOVA_CONF=/var/lib/config-data/puppet-generated/nova_libvirt/etc/nova/nova.conf
      if [ `grep 19ee $NOVA_CONF | wc -l` != "0" ]; then
            echo whiltelist already configured
      else
        echo appending pci whitelist
        echo '[pci]' >> ${NOVA_CONF}
        lspci -Dnmmd 19ee:6003 | head -n 59 | cut -f 1 -d ' ' | sed 's/\(.*\)/{"vendor_id":"19ee","product_id":"6003","device_type":"type-VF","address":"\1"}/' | tr '\n' ',' | sed 's/\(.*\),/passthrough_whitelist=[\1]/' >> ${NOVA_CONF}    
        echo "restarting libvirt and nova_compute"
        docker restart nova_libvirt
        docker restart nova_compute      
      fi

}

configure_selinux(){
   mkdir -p /var/run/vrouter
   chown qemu:qemu /var/run/vrouter/
   semanage fcontext -a -t qemu_var_run_t /var/run/vrouter
   restorecon -v /var/run/vrouter
   chmod 755 /var/run/vrouter/
}


if [[ `hostname` = *compute*  ]]; then
  conf_nm
  rm -rf /tmp/payload
  docker_login
  deploy_agilio_vrt
  wait_for_payload
  configure_nova
  configure_selinux
  configure_virtioforwarder
  deploy_virtioforwarder

fi
