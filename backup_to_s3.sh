#!/bin/bash

config=$(cat conf.json | jq -r -c .)

bucket_name=$(echo $config | jq -rc .s3_bucket_name)
region=$(echo $config | jq -rc .s3_region)
log_file=$(echo $config | jq -rc .log_file)
s3_endpoint="https://$bucket_name.s3.$region.scw.cloud"
final_folder="/mnt/s3_$bucket_name"
retention_days=$(echo $config | jq -rc .retention_days)

function s3_backup () {
	echo " × Copied" | tee -a $log_file
	mkdir -p $(dirname "$final_folder/$2")
	cp $1 "$final_folder/$2" | tee -a $log_file
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
	                s3_backup $final_file "$frequency/$(date +%y-%m-%d)/$(basename $final_file)"
	                rm -rf $final_file
	        fi
	done
	echo "Log file:" | tee -a $log_file
        s3_backup $log_file "$frequency/$(date +%y-%m-%d)/$log_file"

}

function cleanup () {
	rm -rf $log_file
	echo "Starting cleanup" | tee -a $log_file
	echo $retention_days | jq -rc 'keys_unsorted' | jq -rc .[] | while read retention_policy
	do
		duration=$(echo $retention_days | jq -rc .$retention_policy)
		echo "  - Cleaning up $retention_policy backups ($duration days):" | tee -a $log_file

		backup_folder=$final_folder/$retention_policy

		for path in $backup_folder/*
		do
			folder_name=$(basename $path)

			let date_diff=(`date +%s `-`date +%s -d $folder_name`)/86400
			if [[ $date_diff -gt $duration ]]
			then
				echo "      Deleting $backup_folder/$folder_name" | tee -a $log_file
				rm -rf "$backup_folder/$folder_name"
			fi
		done
	done
	s3_backup $log_file "cleanups/$(date +%y-%m-%d)_cleanup.log"
}

cleanup

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

