#!/bin/bash

# Description : Flatten a docker image
#
# Usage   : flatten_image.sh <existing-image-to-shrink> <name-of-generated-shrunk-image>
#
# Example : ./flatten_image.sh aia/base/javaimage aia/base/java:1.0.1-SNAPSHOT
#

_awk=/usr/bin/awk
_grep=/usr/bin/grep
_docker=/usr/bin/docker
_echo=/bin/echo
_script=$(basename "$0")

_os=$(lsb_release -is)
[ ${_os} == "Ubuntu" ] && _grep=/bin/grep

usage() {
    $_echo "usage: $_script <existing-image-to-shrink> <name-of-generated-shrunk-image>"
}

if [ $# -ne 2 ]; then
    $_echo "Error: incorrect number of args"
    usage
    exit 1
fi

old_repository=$1
new_repository=$2

echo "Script $_script shrinking image '$old_repository' to '$new_repository'"

[[ $old_repository == *":"* ]] && old_name=$(echo $old_repository | cut -d: -f1) \
                               || old_name=$old_repository
tmp_image=temp-img

abort_script()
{
    $_echo -e "ERROR : $1"
    exit 1
}

IMAGE_ID=`$_docker images | $_grep "${old_name}" | $_awk '{print $3}'`
[ $? -ne 0 ] || [ -z "${IMAGE_ID}" ] && abort_script "Failed to get image ID for ${old_repository}"
    
$_docker run --name=${tmp_image} -ti -d $IMAGE_ID /bin/bash
[ $? -ne 0 ] && abort_script "Could not run container for ${old_repository}"
    
TMP_CONTAINER_ID=`$_docker ps | $_grep ${tmp_image} | $_awk '{print $1}'`
[ $? -ne 0 ] || [ -z "${TMP_CONTAINER_ID}" ] && abort_script "Failed to get container ID for ${tmp_image}"
    
$_docker export $TMP_CONTAINER_ID > /tmp/$TMP_CONTAINER_ID.tar
[ $? -ne 0 ] && abort_script "Could not export container to tar for image ${old_repository}"
    
cat /tmp/$TMP_CONTAINER_ID.tar | $_docker import - ${new_repository}
[ $? -ne 0 ] && abort_script "Could not import $TMP_CONTAINER_ID.tar"
    
$_docker stop $TMP_CONTAINER_ID
[ $? -ne 0 ] && abort_script "Failed to stop container: $TMP_CONTAINER_ID"
    
$_docker rm $TMP_CONTAINER_ID
[ $? -ne 0 ] && abort_script "Failed to remove container: $TMP_CONTAINER_ID"
    
$_docker rmi $IMAGE_ID
[ $? -ne 0 ] && abort_script "Failed to remove image: $IMAGE_ID"
    
rm -f /tmp/$TMP_CONTAINER_ID.tar
[ $? -ne 0 ] && abort_script "Failed to remove file: /tmp/$TMP_CONTAINER_ID.tar"

