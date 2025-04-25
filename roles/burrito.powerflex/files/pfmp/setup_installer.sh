#!/bin/bash
CTR=$(command -v docker || command -v podman)

if [[ $CTR == *"docker"* ]]; then
    CTR="docker"
fi

if [[ $CTR == *"podman"* ]]; then
        CTR="podman"
fi

if ! sudo $CTR info > /dev/null 2>&1; then
   echo "This script uses $CTR, and it isn't running. So, restarting $CTR.";
   sudo systemctl enable $CTR;
   sudo systemctl restart $CTR ;
   if ! sudo $CTR info > /dev/null 2>&1; then
       echo -e "\nERROR:Docker engine is still not running - Exit the script"
    exit 1
   fi
fi
    
if [ -z "$RUN_PARALLEL_DEPLOYMENTS" ]; then
  echo "RUN_PARALLEL_DEPLOYMENTS is not set."
  export RUN_PARALLEL_DEPLOYMENTS=false
fi

echo "RUN_PARALLEL_DEPLOYMENTS is set to: $RUN_PARALLEL_DEPLOYMENTS"

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ "$RUN_PARALLEL_DEPLOYMENTS" == "false" ]; then
    
    echo -e "\nRunning Single Deployment flow mode"

    OLDACONTAINERID=$(sudo $CTR ps -a | grep atlantic_installer | awk '{ print $1 }')
    if test -z "$OLDACONTAINERID" 
    then
      echo "No running Atlantic Installer container found."
    else
      echo "Found Atlantic Installer containers: $OLDACONTAINERID"
      echo "Removing it."
      #Stop atlantic & pfmp installers if running.
      sudo $CTR stop $OLDACONTAINERID > /dev/null
      sudo $CTR rm $OLDACONTAINERID  > /dev/null
      installerimgid=$(sudo $CTR images | grep atlantic_installer | tail -1 | awk '{ print $3 }')
      sudo $CTR rmi $installerimgid > /dev/null
    fi

    OLDPCONTAINERID=$(sudo $CTR ps -a | grep pfmp_installer | awk '{ print $1 }')
    if test -z "$OLDPCONTAINERID"
    then
      echo "No running PFMP Installer container found."
    else
      echo "Found PFMP Installer containers: $OLDPCONTAINERID"
      echo "Removing it."
      #Stop atlantic & pfmp installers if running.
      sudo $CTR stop $OLDPCONTAINERID > /dev/null
      sudo $CTR rm $OLDPCONTAINERID  > /dev/null
      installerimgid=$(sudo $CTR images | grep pfmp_installer | tail -1 | awk '{ print $3 }')
      sudo $CTR rmi $installerimgid > /dev/null
    fi

    DCK_NW=$(sudo $CTR network ls | grep pfmp_installer_nw | tail -1 | awk '{ print $2 }')
    if test -z "$DCK_NW"
    then
      echo "No instl_nw found."
    else
      echo "Found PFMP Installer nw: $DCK_NW"
      echo "Removing it."
      sudo $CTR network rm pfmp_installer_nw
    fi

    sudo $CTR network create pfmp_installer_nw

    #Load and start images from bundle.

    INSTALLER_PWD=$(readlink -f "$SCRIPT_DIR/../..")

    mkdir -p $INSTALLER_PWD/atlantic/inventory
    mkdir -p $INSTALLER_PWD/atlantic/logs

    echo "Loading Atlantic Installer container from : $INSTALLER_PWD" 
    sudo $CTR load -i $INSTALLER_PWD/atlantic_installer.tgz

    installer_img_tag=$(sudo $CTR images | grep atlantic_installer | tail -1 | awk '{ print $2 }')
    installer_img=$(sudo $CTR images | grep atlantic_installer | tail -1 | awk '{ print $1 }')
    sudo $CTR run --privileged -id -e INSTALLER_PORT=8383 -e MODE=INSTALLER -e PLATFORM_NODES_CREDS=/app/inventory/creds.json -e STATIC_INVENTORY=/app/inventory/inventory.json -e STATIC_VARS=/app/inventory/default_vars.json --net=pfmp_installer_nw  -v $INSTALLER_PWD/atlantic/logs/:/app/log:z -v $INSTALLER_PWD/atlantic/inventory/:/app/inventory:z -v $INSTALLER_PWD:/app/playbooks/files:z --name atlantic_installer $installer_img:$installer_img_tag

    mkdir -p "$INSTALLER_PWD/PFMP_Installer/payload"
    cp -f "$INSTALLER_PWD/apps.json" "$INSTALLER_PWD/PFMP_Installer/payload/"

    mkdir -p $INSTALLER_PWD/PFMP_Installer/logs
    mkdir -p $INSTALLER_PWD/PFMP_Installer/output

    echo "Loading PFMP Installer container from : $INSTALLER_PWD"
    sudo $CTR load -i "$INSTALLER_PWD/PFMP_Installer/PFMP_Installer.tgz"
    # copy OVERRIDE_FILE into atlantic container
    OVERRIDE_FILE=${INSTALLER_PWD}/configure-cluster-tasks-main.yml
    if [ ! -f ${OVERRIDE_FILE} ]; then
        echo -e "\nERROR: File Not Found ${OVERRIDE_FILE}"
        echo -e "\nExit with error"
        exit 1
    fi
    sudo $CTR cp ${OVERRIDE_FILE} \
    atlantic_installer:/app/playbooks/roles/configure-cluster/tasks/main.yml
    # override bootstrap_platform_timeout to 1200s(20m) 
    sudo $CTR exec atlantic_installer \
    sed -i 's/bootstrap_platform_timeout: 600/bootstrap_platform_timeout: 1200/' /app/playbooks/roles/commons/platform/defaults/main/main.yml

else

    echo -e "\nRunning Parallel Deployment flow mode"
    
    echo ""
    echo "######################################################################################"
    echo -e "\nsudo $CTR images"
    sudo $CTR images
    echo "######################################################################################"
    echo ""
    
    echo ""
    echo "######################################################################################"
    echo -e "\nsudo $CTR ps"
    sudo $CTR ps
    echo "######################################################################################"
    echo ""
    
    echo ""
    echo "######################################################################################"
    echo -e "\nsudo $CTR network ls"
    sudo $CTR network ls
    echo "######################################################################################"
    echo ""
    
    deployment_prefix_id="_use_${pfmp_bundle}_${BUILD_NUMBER}"
    atlantic_installer_name=atlantic_installer${deployment_prefix_id}
    pfmp_installer_name=pfmp_installer${deployment_prefix_id}
    pfmp_docker_network_name=pfmp_installer_nw${deployment_prefix_id}
    
    echo -e "\npfmp_docker_network_name ${pfmp_docker_network_name}"
    echo -e "\nsudo $CTR network create ${pfmp_docker_network_name}"
    sudo $CTR network create ${pfmp_docker_network_name}
        
    echo ""
    echo "atlantic_installer_name=${atlantic_installer_name}" | tee -a ${WORKSPACE}/deployment_data.ini
    echo "pfmp_installer_name=${pfmp_installer_name}" | tee -a ${WORKSPACE}/deployment_data.ini
    echo "pfmp_docker_network_name=${pfmp_docker_network_name}" | tee -a ${WORKSPACE}/deployment_data.ini
    echo ""
    echo "######################################################################################"
    #echo -e "\npfmp_docker_network_name ${pfmp_docker_network_name}"
    echo -e "\nsudo $CTR network ls"
    sudo $CTR network ls
    echo "######################################################################################"
    echo ""

    INSTALLER_PWD=$(readlink -f "$SCRIPT_DIR/../..")

    mkdir -p $INSTALLER_PWD/atlantic/inventory
    mkdir -p $INSTALLER_PWD/atlantic/logs

    echo "Loading Atlantic Installer container from : INSTALLER_PWD/atlantic_installer.tgz" 
    echo "sudo $CTR load -i $INSTALLER_PWD/atlantic_installer.tgz"
    sudo $CTR load -i $INSTALLER_PWD/atlantic_installer.tgz | tee -a ${WORKSPACE}/atlantic_installer.log
    
        image_load_output=$(cat ${WORKSPACE}/atlantic_installer.log | grep 'Loaded image: ' | tail -n 1)

        echo
    echo "Image load output: ${image_load_output}"
        echo

    atlantic_installer_colon_count=$(echo "${image_load_output}" | tr -cd ':' | wc -c)
    echo ""
    if [ "$atlantic_installer_colon_count" -eq 3 ]; then
        ainstaller_img_load=`echo "${image_load_output}" | cut -f2,3 -d: | tr -d '[:space:]'`
        ainstaller_img_tag_load=`echo "${image_load_output}" | cut -f4 -d: | tr -d '[:space:]'`
    else
        ainstaller_img_load=`echo "${image_load_output}" | cut -f2 -d: | tr -d '[:space:]'`
        ainstaller_img_tag_load=`echo "${image_load_output}" | cut -f3 -d: | tr -d '[:space:]'`
    fi
    echo -e "\nainstaller_img_load ${ainstaller_img_load}"
    echo -e "\nainstaller_img_tag_load ${ainstaller_img_tag_load}"
    
    if [ ! -z ${ainstaller_img_load} ] ; then
        installer_img=${ainstaller_img_load}
        echo -e "\ninstaller_img ${installer_img}"
        if [ ! -z ${ainstaller_img_tag_load} ] ; then
            installer_img_tag=${ainstaller_img_tag_load}
            echo -e "\ninstaller_img_tag ${installer_img_tag}"
        else
            echo -e "\nERROR:ainstaller_img_tag_load variable is empty"
            echo -e "\nExit with error"
            exit 1
        fi
    else
        echo -e "\nERROR:ainstaller_img_load variable is empty"
        echo -e "\nExit with error"
        exit 1
    fi
    
    #installer_img=$(sudo $CTR images | grep atlantic_installer | grep -v -e use | tail -1 | awk '{ print $1 }')
    #installer_img_tag=$(sudo $CTR images | grep atlantic_installer | grep -v -e use | tail -1 | awk '{ print $2 }')


    echo -e "\n$CTR tag ${installer_img}:${installer_img_tag} ${atlantic_installer_name}:${installer_img_tag}"
    $CTR tag ${installer_img}:${installer_img_tag} ${atlantic_installer_name}:${installer_img_tag}
    #echo -e "\nsudo $CTR rmi -f ${installer_img}:${installer_img_tag}"
    #sudo $CTR rmi -f ${installer_img}:${installer_img_tag}
    installer_img=${atlantic_installer_name}
    
    echo ""
    echo "######################################################################################"
    echo -e "\nsudo $CTR images"
    sudo $CTR images
    echo "######################################################################################"
    echo ""
    
    echo -e "\nsudo $CTR run --privileged -id -e INSTALLER_PORT=8383 -e MODE=INSTALLER -e PLATFORM_NODES_CREDS=/app/inventory/creds.json -e \
    STATIC_INVENTORY=/app/inventory/inventory.json -e STATIC_VARS=/app/inventory/default_vars.json --net=${pfmp_docker_network_name}  \
    -v ${INSTALLER_PWD}/atlantic/logs/:/app/log:z -v ${INSTALLER_PWD}/atlantic/inventory/:/app/inventory:z -v ${INSTALLER_PWD}:/app/playbooks/files:z \
    --name ${atlantic_installer_name} ${installer_img}:${installer_img_tag}"
    
    sudo $CTR run --privileged -id -e INSTALLER_PORT=8383 -e MODE=INSTALLER -e PLATFORM_NODES_CREDS=/app/inventory/creds.json -e \
    STATIC_INVENTORY=/app/inventory/inventory.json -e STATIC_VARS=/app/inventory/default_vars.json --net=${pfmp_docker_network_name}  \
    -v ${INSTALLER_PWD}/atlantic/logs/:/app/log:z -v ${INSTALLER_PWD}/atlantic/inventory/:/app/inventory:z -v ${INSTALLER_PWD}:/app/playbooks/files:z \
    --name ${atlantic_installer_name} ${installer_img}:${installer_img_tag}
    echo ""
    echo "######################################################################################"
    echo -e "\nsudo $CTR ps"
    sudo $CTR ps
    echo "######################################################################################"
    echo ""
    
    mkdir -p "$INSTALLER_PWD/PFMP_Installer/payload"
    cp -f "$INSTALLER_PWD/apps.json" "$INSTALLER_PWD/PFMP_Installer/payload/"

    mkdir -p $INSTALLER_PWD/PFMP_Installer/logs
    mkdir -p $INSTALLER_PWD/PFMP_Installer/output

    #echo "Loading PFMP Installer container from : $INSTALLER_PWD"
    #sudo $CTR load -i "$INSTALLER_PWD/PFMP_Installer/PFMP_Installer.tgz"
fi
