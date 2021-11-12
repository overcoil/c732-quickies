
#
# Janky front-end for Redshift
# 
# This Makefile is for operating the Redshift cluster on AWS, not for building the sample data.
#  
# Refer to README.md instead on details on building the synthetic data (including uploading to S3)
#
# Pre-req:
#   1. Create your Redshift subnet group. Use the web console or:
#        $ aws ec2 describe-vpcs
#        $ aws ec2 describe-subnets
#        $ aws redshift create-cluster-subnet-group 
#

REGION_CAC1=ca-central-1
REGION_USW2=us-west-2


#===================

# adjust from this point on:

REGION=$(REGION_USW2)

# publicly accessible cluster
CNAME=c732-red-a12
CINST=dc2.large
SNET=fill-me-in
SNETG=c732-snetg-a11-open

# use a different variable with delete-cluster to avoid accidental cluster deletion!
DNAME=fill-me-in


.PHONY: ls status describe create-cluster create-snetg delete-cluster pause resume

ls:
	aws --region $(REGION) redshift describe-clusters

status:
	aws --region $(REGION) --output json redshift describe-clusters --cluster-identifier $(CNAME) | grep ClusterStatus

describe:
	aws --region $(REGION) redshift describe-clusters --cluster-identifier $(CNAME)

create-cluster:
	aws --region $(REGION) redshift create-cluster \
		--node-type $(CINST) --cluster-type single-node \
		--cluster-subnet-group-name $(SNETG) \
		--master-username c732-red-admin --master-user-password Sunshine4u \
		--region $(REGION) \
		--cluster-identifier $(CNAME) 

# untested... but a reasonable starting point
create-snetg:
	aws --region $(REGION) create-cluster-subnet-group \
		--subnet-ids $(SNET) \
		--cluster-subnet-group-name $(SNETG)

delete-cluster:
	aws --region $(REGION) redshift delete-cluster --skip-final-cluster-snapshot --cluster-identifier $(DNAME)

pause:
	aws --region $(REGION) redshift pause-cluster --cluster-identifier $(CNAME)

resume:
	aws --region $(REGION) redshift resume-cluster --cluster-identifier $(CNAME)

