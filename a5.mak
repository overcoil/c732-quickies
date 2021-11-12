
#
# Janky front-end for EMR
# 
# This is intended to be used a la a Jupyter notebook where you fill in some values selectively to save your fingers
#
# Pre-req:
#   0. This script anticipates multiple clusters (e.g., large-up). Hence, the SMALL/S and LARGE/L prefixes.
#   1. Create a EMR cluster from the web console to trigger the creation of the default security groups. 
#      Look these up and fill them into EMSG/ESSG. Note that SG are region-specific; hence the variants of EMSG/ESSG.
#   2. Look up the subnet(s) in your VPC and filled them into SMALLSNET/LARGESNET.
#   3. Set LOG_DEST to a bucket/path.
#   4. Save the cluster id (into SCID/LCID) after you use create the cluster. (It is also saved into small-up.out.)
#   5. The spark-submit/job2/job3 targets are setup to spark-submit a pyspark program. Be careful with whitespaces.
#


REGION_CAC1=ca-central-1
REGION_USW2=us-west-2

EMR_VERSION=emr-6.4.0

# pick these off your AWS web console at VPC/Subnets 
SNET_USW2=subnet-02cbbfc87b057053c
SNET_CAC1=subnet-bea6c8c4

# ...and these from EC2/Security Groups *after* you have created one EMR cluster via the console
EMSG_USW2=sg-08a5d5439d354790c
ESSG_USW2=sg-0bbf69f06cccb4802

EMSG_CAC1=sg-047bc32c974c70a58
ESSG_CAC1=sg-06db599d47e8116a2

#===================

# adjust from this point on:

REGION=$(REGION_USW2)
LOG_DEST=s3n://c732-kaiyeec-a5/emr-logs/

SMALLSNET=$(SNET_USW2)
EMRSSG=$(ESSG_USW2)
EMRMSG=$(EMSG_USW2)

SMALLNAME=c732-emr-2x-m4.2xl
SINST=m4.2xlarge
SNODE=2
SCID=j-G9HXGLETIE8Y

LARGENAMEse=c732-emr-4x-m6gd.xl
LINST=m6gd.xlarge
LNODE=4
LCID=j-21C2XNA48DDK8

# ref: https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-spark-submit-step.html
# NB: there must be *no spaces* in the following!
J2PGM=s3://c732-kaiyeec-a5/weather_etl.py
J2ARGS=s3://c732-kaiyeec-a5/weather-1,s3://c732-kaiyeec-a5/output/w1

J3PGM=s3://c732-kaiyeec-a5/weather_etl_s3_select.py
J3ARGS=s3://c732-kaiyeec-a5/weather-1,s3://c732-kaiyeec-a5/output/w1s


# for use with the large cluster (LCID)

J4PGM=s3://c732-kaiyeec-a5/relative_score.py
J4ARGS=s3://public-cmpt-732/reddit-5,s3://c732-kaiyeec-a5/output/large-r5,--bcast

J5PGM=s3://c732-kaiyeec-a5/weather_etl_s3_select.py
J5ARGS=s3://c732-kaiyeec-a5/weather-1,s3://c732-kaiyeec-a5/output/w1s


.PHONY: ls describe small-up small-kill spark-submit job2 job3

ls:
	aws --region $(REGION) emr list-clusters

s3ls:
	aws --region $(REGION) s3 ls --recursive s3://c732-kaiyeec-a5/output

describe:
	aws --region $(REGION) --output json emr describe-cluster --cluster-id $(SCID) | grep "\"State\""
	aws --region $(REGION) --output json emr describe-cluster --cluster-id $(LCID) | grep "\"State\""

small-up:
	aws --region $(REGION) emr create-cluster --applications Name=Spark Name=Zeppelin \
		--ec2-attributes '{"InstanceProfile":"EMR_EC2_DefaultRole", \
			"SubnetId":"$(SMALLSNET)", \
			"EmrManagedSlaveSecurityGroup":"$(EMRSSG)", \
			"EmrManagedMasterSecurityGroup":"$(EMRMSG)"}' \
		--service-role EMR_DefaultRole --enable-debugging \
		--instance-groups \
			'[{"InstanceCount":1, \
					"EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"SizeInGB":32,"VolumeType":"gp2"}, \
								"VolumesPerInstance":4}]}, \
					"InstanceGroupType":"MASTER", \
					"InstanceType":"m4.2xlarge", \
					"Name":"Master Instance Group"}, \
			{"InstanceCount":$(SNODE), \
					"EbsConfiguration":{"EbsBlockDeviceConfigs":[{"VolumeSpecification":{"SizeInGB":32,"VolumeType":"gp2"}, \
								"VolumesPerInstance":4}]}, \
					"InstanceGroupType":"CORE", \
					"InstanceType":"$(SINST)", \
					"Name":"Core Instance Group"}]'  \
		--release-label $(EMR_VERSION) \
		--configurations '[{"Classification":"spark","Properties":{}}]'  \
		--scale-down-behavior TERMINATE_AT_TASK_COMPLETION  \
		--log-uri '$(LOG_DEST)' \
		--name '$(SMALLNAME)'

small-kill:
	aws --region $(REGION) emr terminate-clusters --cluster-id $(SCID)

large-kill:
	aws --region $(REGION) emr terminate-clusters --cluster-id $(LCID)

spark-submit:
	aws --region $(REGION) emr add-steps --cluster-id $(SCID) \
	--steps Type=Spark,Name="cli-job1",Jar="command-runner.jar",ActionOnFailure=CONTINUE,Args=[s3://c732-kaiyeec-a5/relative_score.py,s3://c732-kaiyeec-a5/reddit-1,s3://c732-kaiyeec-a5/output/janky1,--bcast] 

job2:
	aws --region $(REGION) emr add-steps --cluster-id $(SCID) \
	--steps Type=Spark,Name="cli-job2",Jar="command-runner.jar",ActionOnFailure=CONTINUE,Args=[$(J2PGM),$(J2ARGS)]

job3:
	aws --region $(REGION) emr add-steps --cluster-id $(SCID) \
	--steps Type=Spark,Name="cli-job3",Jar="command-runner.jar",ActionOnFailure=CONTINUE,Args=[$(J3PGM),$(J3ARGS)]

ljob4:
	aws --region $(REGION) emr add-steps --cluster-id $(LCID) \
	--steps Type=Spark,Name="cli-ljob4",Jar="command-runner.jar",ActionOnFailure=CONTINUE,Args=[$(J4PGM),$(J4ARGS)]

ljob5:
	aws --region $(REGION) emr add-steps --cluster-id $(LCID) \
	--steps Type=Spark,Name="cli-ljob5",Jar="command-runner.jar",ActionOnFailure=CONTINUE,Args=[$(J5PGM),$(J5ARGS)]

# better idea: https://docs.aws.amazon.com/cli/latest/userguide/cli-usage-alias.html
whoami:
	aws sts get-caller-identity

