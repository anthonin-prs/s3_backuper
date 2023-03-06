#!/bin/bash

apt-get install automake autotools-dev fuse g++ git libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config -y >/dev/null 2>&1

config=$(cat conf.json | jq -r -c .)

bucket_name=$(echo $config | jq -rc .s3_bucket_name)
passw=$(echo $config | jq -rc .s3_passw)

echo "Creating passw file"
echo $passw > /etc/passw-s3fs

chmod 600 /etc/passw-s3fs

echo "Creating folder /mnt/s3_$bucket_name"
mkdir /mnt/s3_$bucket_name

echo "Mounting $bucket_name to /mnt/s3_$bucket_name"
echo "" >> /etc/fstab
echo "# S3FS Backup Mount" >> /etc/fstab
echo "s3fs#$bucket_name /mnt/s3_$bucket_name fuse _netdev,allow_other,use_path_request_style,url=https://s3.fr-par.scw.cloud/ 0 0" >> "/etc/fstab"

mount -a
