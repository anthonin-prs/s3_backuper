#!/bin/bash

config=$(cat config.json | jq -r -c .)

bucket_name=$(echo $config | jq -rc .s3_bucket_name)
region=$(echo $config | jq -rc .s3_region)
log_file=$(echo $config | jq -rc .log_file)
s3_endpoint="https://$bucket_name.s3.$region.scw.cloud"

function s3_backup () {
	echo " × Uploaded" | tee -a $log_file
	aws --endpoint-url $s3_endpoint s3 cp $1 s3://$2 --only-show-errors | tee -a $log_file
}


function zip_content () {
	if [[ $1 != *.zip ]] && [[ $1 != *.tar.gz ]]
	then
		zip -qr $1.zip $1
		echo " × Compressed" >> $log_file
		echo $1.zip
	else
		echo $1
	fi
}

function backup_selected_frequency () {
	config=$1
	frequency=$2
	rm -rf $log_file

	echo " --- Backup du $(date +%D) ---" | tee -a $log_file

	printf "\n\n- $frequency backup:\n" | tee -a $log_file
	echo $config | jq -rc .$frequency[] | while read file
	do
	        if [ -e "$file" ]; then
	                echo "$file:" | tee -a $log_file
	                final_file=$(zip_content $file)
	                s3_backup $final_file "$frequency/$(echo $frequency)_$(date +%y-%m-%d)/$(basename $final_file)"
	                rm -rf $final_file
	        fi
	done
	echo "Log file:" | tee -a $log_file
        s3_backup $log_file "$frequency/$(echo $frequency)_$(date +%y-%m-%d)/$log_file"

}

daily=$(backup_selected_frequency $config "daily")
cat $log_file

if [[ $(date +%u) == 1 ]] || [[ $1 == "ALL" ]]
then
        weekly=$(backup_selected_frequency $config "weekly")
	cat $log_file
fi

if [[ $(date +%d) == 1 ]] || [[ $1 == "ALL" ]]
then
        monthly=$(backup_selected_frequency $config "monthly")
	cat $log_file
fi

rm -rf $log_file
