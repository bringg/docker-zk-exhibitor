#!/bin/bash -e
# Generates the default exhibitor config and launches exhibitor
#
DEFAULT_AWS_REGION="us-east-1"
DEFAULT_DATA_DIR="/opt/zookeeper/data/snapshots"
DEFAULT_LOG_DIR="/opt/zookeeper/data/transactions"
DEFAULT_ZK_APPLY_ALL_AT_ONCE=0
DEFAULT_ZK_ENSEMBLE_SIZE=0
DEFAULT_ZK_SETTLING_PERIOD=120000

HTTP_PROXY=""
S3_SECURITY=""

: ${AWS_REGION:=$DEFAULT_AWS_REGION}
: ${HOSTNAME:?"must be set"}
: ${HTTP_PROXY_HOST:=""}
: ${HTTP_PROXY_PASSWORD:=""}
: ${HTTP_PROXY_PORT:=""}
: ${HTTP_PROXY_USERNAME:=""}
: ${ZK_APPLY_ALL_AT_ONCE:=$DEFAULT_ZK_APPLY_ALL_AT_ONCE}
: ${ZK_DATA_DIR:=$DEFAULT_DATA_DIR}
: ${ZK_ENSEMBLE_SIZE:=$DEFAULT_ZK_ENSEMBLE_SIZE}
: ${ZK_LOG_DIR:=$DEFAULT_LOG_DIR}
: ${ZK_SETTLING_PERIOD:=$DEFAULT_ZK_SETTLING_PERIOD}

cat <<- EOF > /opt/exhibitor/defaults.conf
    auto-manage-instances-fixed-ensemble-size=$ZK_ENSEMBLE_SIZE
    auto-manage-instances-settling-period-ms=$ZK_SETTLING_PERIOD
    auto-manage-instances=1
    auto-manage-instances-apply-all-at-once=$ZK_APPLY_ALL_AT_ONCE
    backup-max-store-ms=21600000
    backup-period-ms=600000
    check-ms=30000
    cleanup-max-files=20
    cleanup-period-ms=300000
    client-port=2181
    connect-port=2888
    election-port=3888
    log-index-directory=$ZK_LOG_DIR
    observer-threshold=0
    zoo-cfg-extra=tickTime\=2000&initLimit\=10&syncLimit\=5&quorumListenOnAllIPs\=true
    zookeeper-data-directory=$ZK_DATA_DIR
    zookeeper-install-directory=/opt/zookeeper
    zookeeper-log-directory=$ZK_LOG_DIR
EOF

if [[ -n ${AWS_ACCESS_KEY_ID} && -n ${AWS_SECRET_ACCESS_KEY} ]]; then
    cat <<- EOF > /opt/exhibitor/credentials.properties
    com.netflix.exhibitor.s3.access-key-id=${AWS_ACCESS_KEY_ID}
    com.netflix.exhibitor.s3.access-secret-key=${AWS_SECRET_ACCESS_KEY}
EOF
  S3_SECURITY="--s3credentials /opt/exhibitor/credentials.properties"
fi

if [[ -n ${S3_BUCKET} ]]; then
    echo "backup-extra=throttle\=&bucket-name\=${S3_BUCKET}&key-prefix\=${S3_PREFIX}&max-retries\=4&retry-sleep-ms\=30000" >> /opt/exhibitor/defaults.conf
    BACKUP_CONFIG="--configtype s3 --s3config ${S3_BUCKET}:${S3_PREFIX} ${S3_SECURITY} --s3region ${AWS_REGION} --s3backup true"
else
    echo "backup-extra=directory\=/opt/zookeeper/local_configs" >> /opt/exhibitor/defaults.conf
    BACKUP_CONFIG="--configtype file --fsconfigdir /opt/zookeeper/local_configs --filesystembackup true"

    mkdir -p /opt/zookeeper/local_configs

    [[ -n ${GS_BUCKET} ]] && {
        [[ -n ${GS_PREFIX} ]] && GS_PREFIX="--only-dir ${GS_PREFIX}"
        [[ -e /opt/exhibitor/key-file.json ]] && GS_KEY_FILE="--key-file /opt/exhibitor/key-file.json"

        gcsfuse \
        --stat-cache-ttl 0 \
        --type-cache-ttl 0 \
        ${GS_KEY_FILE} \
        ${GS_PREFIX} \
        ${GS_BUCKET} /opt/zookeeper/local_configs \
        || exit 1
    }
fi

[[ -n ${ZK_PASSWORD} ]] && {
	SECURITY="--security web.xml --realm Zookeeper:realm --remoteauth basic:zk"
	echo "zk: ${ZK_PASSWORD},zk" > realm
}

[[ -n $HTTP_PROXY_HOST ]] && {
    cat <<- EOF > /opt/exhibitor/proxy.properties
      com.netflix.exhibitor.s3.proxy-host=${HTTP_PROXY_HOST}
      com.netflix.exhibitor.s3.proxy-port=${HTTP_PROXY_PORT}
      com.netflix.exhibitor.s3.proxy-username=${HTTP_PROXY_USERNAME}
      com.netflix.exhibitor.s3.proxy-password=${HTTP_PROXY_PASSWORD}
EOF

    HTTP_PROXY="--s3proxy=/opt/exhibitor/proxy.properties"
}

exec 2>&1

mkdir -p $ZK_DATA_DIR $ZK_LOG_DIR

exec java -jar /opt/exhibitor/exhibitor.jar \
  --defaultconfig /opt/exhibitor/defaults.conf \
  --hostname ${HOSTNAME} \
  --port 8181 \
  ${BACKUP_CONFIG} \
  ${HTTP_PROXY} \
  ${SECURITY}
