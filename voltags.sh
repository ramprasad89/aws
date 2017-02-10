#! /bin/bash
# Purpose of the script is to tag the aws ebs volumes as per the tags in the respective instances.

SCRIPT='aws_tag.py'
/usr/bin/python "$SCRIPT" -m > /data/home/rpanda/aws_tag_missing.txt

awk '/vol/ {print $1}' /data/home/rpanda/aws_tag_missing.txt > /data/home/rpanda/volumeids

for i in `cat volumeids`
do
	# Since we create instances in us-east and us-west so finding the region in which the volume exists first. We will be using this region variable in every aws-cli command to be
    	# region-specific
  	az=`aws ec2 describe-volumes --region us-east-1 --filters Name=volume-id,Values=$i --query Volumes[0].AvailabilityZone | sed 's/"//g' | cut -c'1-9'`
        az1=`aws ec2 describe-volumes --region us-west-2 --filters Name=volume-id,Values=$i --query Volumes[0].AvailabilityZone | sed 's/"//g' | cut -c'1-9'`

	if [ $az != "null" ] && [ $az == "us-east-1" ]
	then
        	region=$az
	elif [ $az1 != "null" ] && [ $az1 == "us-west-2" ]
	then
        	region=$az1
	fi

	# Finding the instance id using describe-volumes and the number of tags (nof_tags) as tag number varies from instance to instance.
	instanceid=`aws ec2 describe-volumes --region $region --volume-ids $i --query Volumes[0].Attachments[0].InstanceId | awk -F"\"" '{print $2}'`
	nof_tags=$((`aws ec2 describe-instances --region $region --instance-ids $instanceid --query Reservations[0].Instances[0].Tags[].Key | wc -l`-2))

		for (( j=0; j<nof_tags; j++))
		do
				# Find the key and value for the tags and create the tags for the volumes
				key=`aws ec2 describe-instances --region $region --instance-ids $instanceid --query Reservations[0].Instances[0].Tags[$j].Key | awk -F"\"" '{print $2}'`
				value=`aws ec2 describe-instances --region $region --instance-ids $instanceid --query Reservations[0].Instances[0].Tags[$j].Value | awk -F"\"" '{print $2}'`

				aws ec2 create-tags --resources $i --region $region --tags Key=$key,Value=$value

				echo -e "$i\t$instanceid\t$key\t$value"
		done
done
