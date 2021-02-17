#!/bin/bash -e

if [ ! -f .env ]; then
  echo "!!! Missing .env file, see env.example for details"
  exit 1
fi

source .env

aws cloudformation update-stack --stack-name $STACK_NAME \
  --profile $AWS_PROFILE \
  --region $AWS_REGION \
  --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=MasterUserPassword,ParameterValue=$DB_PASSWD \
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
