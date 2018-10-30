#!/bin/bash
if [[ -z ${CLAIR_HOST} ]] ; then
    echo "FATAL ERROR on ${jobName}: clair host is not set"
    exit 1
fi

if [[ -z ${GITHUB_OAUTH} ]] ; then
    echo "FATAL ERROR on ${jobName}: github oauth token is not set"
    exit 1
fi

if [[ -z ${GHPATHS} ]] ; then
    echo "FATAL ERROR on ${jobName}: github dockerfile paths not set"
    exit 1
fi

export CLAIR_OUTPUT=High
export CLAIR_THRESHOLD=10

AWS=/usr/bin/aws
TASKS=$($AWS ecs list-tasks| jq .[][]|sed -e 's/"//g')
TASKDESCS=$($AWS ecs describe-tasks --tasks $TASKS| jq .[][].taskDefinitionArn|sed -e 's/"//g')
IMAGES=()
for i in $TASKDESCS; do
    IMAGES+=($($AWS ecs describe-task-definition --task-definition $i | jq .[].containerDefinitions[].image|sed -e 's/"//g'))
done
ONLYDH=$(for i in $(echo ${IMAGES[@]}); do echo $i; done | grep uqlibrary | sort |uniq)

for i in $(echo $GHPATHS | sed -e 's/;/ /g'); do
    CONTENT=$(curl -s -u $GITHUB_OAUTH $i | grep FROM | awk '{print $2}')
    INARRAY=$(echo ${ONLYDH[@]} | grep -c $CONTENT)
    echo $CONTENT
    if [ $INARRAY -eq 0 ]; then
        ONLYDH+=($CONTENT)
    fi
done

for i in $(echo ${ONLYDH[@]}); do
    echo "Scanning $i"
    RESULT=$(klar $i)
    if [ $? -eq 1 ]; then
        printf "%s" "$RESULT"
    fi
done
