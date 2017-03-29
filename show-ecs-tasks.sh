#!/bin/bash

# $ for cluster in $(aws ecs list-clusters --query clusterArns | tr -d '[]",'); do aws ecs describe-tasks --cluster $cluster --tasks "$(aws ecs list-tasks --cluster $cluster --query 'taskArns' | grep RUNNING -C999)"; done


clusters=$(aws ecs list-clusters | jq .clusterArns | tr -d '[]",')

for cluster in $clusters; do
    echo "********* CLUSTER: $cluster *********"
    echo
    task_arns=$(aws ecs list-tasks --cluster $cluster --query "taskArns")
    results=$(aws ecs describe-tasks \
                --cluster $cluster \
                --tasks "$task_arns")
    failures=$(echo $results | jq .failures)
    tasks=$(echo "$results" | jq .tasks)
    echo "Failures:"
    echo "$failures"
    echo

    echo "Tasks:"
    echo "$tasks" | jq '.[] | .containers[].lastStatus + " " + .containers[].name + " " + .group + " " + .containerInstanceArn' | tr -d '"' | column -t -s " "
    echo
done

