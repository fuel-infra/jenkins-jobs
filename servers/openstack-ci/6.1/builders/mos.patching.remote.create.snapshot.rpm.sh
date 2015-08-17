function retry {
    local count=3
    local sleep=5
        local optname
        while getopts 'c:s:' optname
        do
            case $optname in
                c) count=$OPTARG ;;
                s) sleep=$OPTARG ;;
                ?) return 1 ;;
            esac
        done
        shift $((OPTIND - 1))
        local ec
        while true
        do
            "$@" && true
            ec=$?
            (( count-- ))
            if [[ $ec -eq 0 || $count -eq 0 ]]
            then
                break
            else
                sleep "$sleep"
            fi
        done
        return "$ec"
}

REMOTE_URL="https://patching-ci.infra.mirantis.net"
REMOTE_JOB="6.1.create_snapshot.centos-6"
JOBURL=${REMOTE_URL}/view/All/job/${REMOTE_JOB}
RESULT=None

retry curl -X POST ${JOBURL}/buildWithParameters --user "${PATCHING_USER}":"${PATCHING_PASSWORD}"
sleep 10
BUILDNUMBER=$(curl --silent ${JOBURL}/lastBuild/api/json | python -c \
'import sys
from yaml import load, Loader
obj = load(sys.stdin, Loader=Loader)
print obj["number"]')

#TODO: Implement timeout (about 10 min) for this loop
while [ "${RESULT}" = None ]; do
    sleep 120
    RESULT=$(curl --silent ${JOBURL}/"${BUILDNUMBER}"/api/json | python -c \
'import sys
from yaml import load, Loader
obj = load(sys.stdin, Loader=Loader)
print obj["result"]')
done
if [ "${RESULT}" = FAILURE ]; then
    exit 1
fi
