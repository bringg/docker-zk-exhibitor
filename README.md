Runs an [Exhibitor](https://github.com/soabase/exhibitor/)-managed [ZooKeeper](http://zookeeper.apache.org/) instance using S3 or GCS for backups and automatic node discovery.

Based on the Docker Index as [simenduev/zookeeper-exhibitor](https://index.docker.io/u/simenduev/zookeeper-exhibitor/):

    docker pull bringg/zookeeper-exhibitor

### Why to Fork?

This is forked version of [mbabineau/zookeeper-exhibitor](https://github.com/mbabineau/docker-zk-exhibitor)

The fork add support for the following:

* Google Cloud Storage support (via `gcsfuse`), requires privileged mode, see below
* Updated Exhibitor and Zookeeper to their latest versions
* Using official Java container, based on Alpine flavor
* Allow to specify settling-period (`ZK_SETTLING_PERIOD`)

### Versions

* Exhibitor 1.7.1
* ZooKeeper 3.4.14

### Usage

The container expects the following environment variables to be passed in:

* `HOSTNAME` - addressable hostname for this node (Exhibitor will forward users of the UI to this address)
* `GS_BUCKET` - (optional) bucket used by Exhibitor for backups and coordination
* `GS_PREFIX` - (optional) key prefix within `GS_BUCKET` to use for this cluster
* `S3_BUCKET` - (optional) bucket used by Exhibitor for backups and coordination
* `S3_PREFIX` - (optional) key prefix within `S3_BUCKET` to use for this cluster
* `AWS_ACCESS_KEY_ID` - (optional) AWS access key ID with read/write permissions on `S3_BUCKET`
* `AWS_SECRET_ACCESS_KEY` - (optional) secret key for `AWS_ACCESS_KEY_ID`
* `AWS_REGION` - (optional) the AWS region of the S3 bucket (defaults to `us-east-1`)
* `ZK_APPLY_ALL_AT_ONCE` - (optional) If non zero, will make config changes all at once. Default 0
* `ZK_DATA_DIR` - (optional) Zookeeper data directory
* `ZK_LOG_DIR` - (optional) Zookeeper log directory
* `ZK_PASSWORD` - (optional) the HTTP Basic Auth password for the "zk" user
* `ZK_SETTLING_PERIOD` - (optional) How long in ms to wait for the Ensemble to settle. Default 2 minutes
* `ZK_ENABLE_LOGS_BACKUP` - (optional) If true, enables backup of ZooKeeper log files. Default true
* `HTTP_PROXY_HOST` - (optional) HTTP Proxy hostname
* `HTTP_PROXY_PORT` - (optional) HTTP Proxy port
* `HTTP_PROXY_USERNAME` - (optional) HTTP Proxy username
* `HTTP_PROXY_PASSWORD` - (optional) HTTP Proxy password

Starting the container:

    docker run -p 8181:8181 -p 2181:2181 -p 2888:2888 -p 3888:3888 \
        -e S3_BUCKET=<bucket> \
        -e S3_PREFIX=<key_prefix> \
        -e AWS_ACCESS_KEY_ID=<access_key> \
        -e AWS_SECRET_ACCESS_KEY=<secret_key> \
        -e HOSTNAME=<host> \
        bringg/zookeeper-exhibitor:latest

Once the container is up, confirm Exhibitor is running:

    $ curl -s localhost:8181/exhibitor/v1/cluster/status | python -m json.tool
    [
        {
            "code": 3,
            "description": "serving",
            "hostname": "<host>",
            "isLeader": true
        }
    ]

_See Exhibitor's [wiki](https://github.com/soabase/exhibitor/wiki/REST-Introduction) for more details on its REST API._

You can also check Exhibitor's web UI at `http://<host>:8181/exhibitor/v1/ui/index.html`

Then confirm ZK is available:

    $ echo ruok | nc <host> 2181
    imok

### AWS IAM Policy

Exhibitor can also use an IAM Role attached to an instance instead of passing access or secret keys. This is an example policy that would be needed for the instance:

```json
{
    "Statement": [
        {
            "Resource": [
                "arn:aws:s3:::exhibitor-bucket/*",
                "arn:aws:s3:::exhibitor-bucket"
            ],
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:DeleteObject",
                "s3:GetBucketAcl",
                "s3:GetBucketPolicy",
                "s3:GetObject",
                "s3:GetObject",
                "s3:GetObjectAcl",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:ListMultipartUploadParts",
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Effect": "Allow"
        }
    ]
}
```

Starting the container:

    docker run -p 8181:8181 -p 2181:2181 -p 2888:2888 -p 3888:3888 \
        -e S3_BUCKET=<bucket> \
        -e S3_PREFIX=<key_prefix> \
        -e HOSTNAME=<host> \
        bringg/zookeeper-exhibitor:latest

### Google Cloud Storage

The most important note is that in order to be able to mount GS bucket (via `gcsfuse`), the container required to run in **privileged** mode.
Credentials for use with GCS will automatically be loaded using [Google application default credentials](https://developers.google.com/identity/protocols/application-default-credentials#howtheywork), unless you mount a JSON key file.

After everything is in place, this is how you start the container with GCS support:

    docker run -p 8181:8181 -p 2181:2181 -p 2888:2888 -p 3888:3888 \
        --privileged \
        -e GS_BUCKET=<bucket> \
        -e GS_PREFIX=<key_prefix> \
        -e HOSTNAME=<host> \
        -v <path to json file>:/opt/exhibitor/key-file.json \
        bringg/zookeeper-exhibitor
