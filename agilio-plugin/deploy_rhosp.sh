#!/bin/bash

set -x

echo applying args $1

openstack overcloud deploy $1 --templates ~/tripleo-heat-templates \
  -e ~/overcloud_images.yaml \
  -e ~/tripleo-heat-templates/environments/network-isolation.yaml \
  -e ~/tripleo-heat-templates/environments/contrail/contrail-plugins.yaml \
  -e ~/tripleo-heat-templates/environments/contrail/contrail-services.yaml \
  -e ~/tripleo-heat-templates/environments/contrail/contrail-net.yaml \
  -e ~/tripleo-heat-templates/agilio-plugin/agilio-env.yaml \
  --roles-file ~/tripleo-heat-templates/roles_data_contrail_aio.yaml 

#  -e ~/tripleo-heat-templates/agilio/agilio-env.yaml \

