#!/bin/bash
if [[ -z ${CLAIR_ADDR} ]] ; then
    echo "FATAL ERROR: CLAIR_ADDR is not set"
    exit 1
fi

if [[ -z ${GITHUB_OAUTH} ]] ; then
    echo "FATAL ERROR: GITHUB_OAUTH token is not set"
    exit 1
fi

if [[ -z ${GHPATHS} ]] ; then
    echo "FATAL ERROR: GHPATHS not set"
    exit 1
fi

if [[ -z ${SNSTOPIC} ]] ; then
    echo "FATAL ERROR: SNSTOPIC not set"
    exit 1
fi

export CLAIR_OUTPUT=High
export CLAIR_THRESHOLD=10
export KLAR=/klar

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

IMAGES="Images with security issues:"
ALLRES=""
EMAIL=0

for i in $(echo ${ONLYDH[@]}); do
    echo "Scanning $i"
    RESULT=$($KLAR $i)
    if [ $? -eq 1 ]; then
        echo "Issues found in $i"
        IMAGES="$IMAGES\n$i"
        ALLRES="$ALLRES\nResults for $i\n$RESULT"
        EMAIL=1
    fi
done

if [ $EMAIL -eq 1 ]; then
        echo "Sending sns notification to $SNSTOPIC"
        $AWS sns publish --topic-arn="$SNSTOPIC" --subject="Docker vulnerability scan has found issues" --message="$(echo -e "$IMAGES\n$ALLRES")"
fi
