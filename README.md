20151112:
    - The following environment variables are currently explicitly expected:

        ICG_CLUSTER_NAME       - The name of the ES cluster
        ICG_ES_CLUSTER_PORT    - Elasticsearch cluster comms port
        ICG_ES_CONF            - The path to an elasticsearch config file 
        ICG_ES_DATA_PATH       - Fully qualified data storage path
        ICG_ES_DATA_NODE       - Boolean for data node: 'true' or 'false'
        ICG_ES_HTTP_PORT       - Elasticsearch http comms port
        ICG_ES_LOG_PATH        - Fully qualified log storage path
        ICG_ES_MASTERS         - Comma separated list of <host>:<port> pairs 
        ICG_ES_MASTER_NODE     - Boolean for master node: 'true' or 'false'
        ICG_ES_TYPE            - The type of elasticsearch node: 'search', 'master', or 'data'
        ICG_FQDN               - The runtime node's fully qualified domain name 
        ICG_HOSTNAME           - The runtime node's DNS short name

    - The following environment variable pattern is searched for the logstash config file:

        ICG_<WHATEVER>         - ICG_* vars are discovered from the config file and 'eval <icg_var_name>=\$${<icg_var_name>}'
                                 is executed to assign their values.  Failure to define in the environment each ICG_<var>
                                 in the config file produces an error, and you will not logstash today

        The following defaults will be set in order to satisfy env var replacement in the config file

        ICG_ALLOC_AWARE_ATTRIB - (default: host)
        ICG_ALLOC_CONCUR_REBAL - (default: 8)
        ICG_BOOTSTRAP_MLOCKALL - (default: true)
        ICG_BREAKER_LIMIT      - (default: 65) (percentage)
        ICG_CORS_ALLOW_ORIGIN  - (default: "/.*/")
        ICG_HTTP_CORS_ENABLED  - (default: true)
        ICG_MIN_MASTER_NODES   - (default: 1)
        ICG_MULTICAST_ENABLED  - (default: false)
        ICG_MULTICAST_PING     - (default: false)
        ICG_SAME_SHARD_HOST    - (default: true)
        ICG_SCRIPT_INDEXED     - (default: on)
        ICG_SCRIPT_INLINE      - (default: on)
