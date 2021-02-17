#!/bin/bash -e

if [ -d common-infra ]; then
  cd common-infra
fi

if [ ! -f ../.env ]; then
  echo "!!! Missing .env file, see env.example for details"
  exit 1
fi

source ../.env

STACK_NAME=$CLOUD_ENV-common-infra

aws cloudformation create-stack --stack-name $STACK_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=EnvName,ParameterValue=$CLOUD_ENV \
  --template-body file://template.yaml

sleep 5

for i in {1..3}
do
  aws cloudformation describe-stacks --stack-name $STACK_NAME \
    --profile $AWS_PROFILE \
    --region $AWS_REGION \
    --no-paginate \
    --output text \
    --query "Stacks[*][StackName, StackStatus]"
  sleep 3
done

aws cloudformation list-stack-resources --stack-name $STACK_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --no-paginate \
  --output text \
  --query "StackResourceSummaries[*][LogicalResourceId, ResourceType, ResourceStatus]"
