#!/bin/bash

rack_hostname() {
    [ -z $1 ] && echo "Please provide a stack name, e.g.:" && cf_stacks && return
    aws cloudformation describe-stacks \
        --region $AWS_DEFAULT_REGION \
        --stack-name $1 \
        --query 'Stacks[*].Outputs[?OutputKey==`Dashboard`].OutputValue' | grep -v "\[" | grep -v "\]"
}

cf_stacks() {
    echo "Region: $AWS_DEFAULT_REGION"

    aws cloudformation describe-stacks \
        --region $AWS_DEFAULT_REGION \
        --query "Stacks[*].StackName" | sort | grep -v "\[" | grep -v "\]"
}

list_buckets() {
    aws s3api list-buckets --query 'Buckets[].Name' | grep -v "\[" | grep -v "\]"
}

delete_buckets() {
    buckets="$*"
    for bucket in $buckets; do
        region=$(aws s3api get-bucket-location --bucket "$bucket" --query 'LocationConstraint' |  sed 's/"//g')
        [ -z $region ] && continue
        echo "aws s3 rb --force s3://${bucket} --region $region"
        aws s3 rb --force "s3://${bucket}" --region "$region"
    done
}
