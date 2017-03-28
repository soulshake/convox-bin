#!/bin/bash


clusters=$(aws ecs list-clusters | jq .clusterArns | tr -d '[]",')

for cluster in $clusters; do
    echo "*************************************"
    echo "********* CLUSTER: $cluster *********"
    echo "*************************************"
    echo
    tasks=$(aws ecs list-tasks --cluster $cluster --query "taskArns")
    aws ecs describe-tasks \
        --cluster $cluster \
        --tasks "$tasks" \
        --output table
    echo
    exit
done

