class metacpan_elasticsearch::instance(
  $version = hiera('metacpan::elasticsearch::version'),
  $memory = hiera('metacpan::elasticsearch::memory', '64'),
  $ip_address = hiera('metacpan::elasticsearch::ipaddress', '127.0.0.1'),
  $data_dir = hiera('metacpan::elasticsearch::datadir', '/var/elasticsearch'),
) {

  $cluster_hosts = hiera_array('metacpan::elasticsearch::cluster_hosts', [])

  # Add the port for unicast to the IP addresses
  $cluster_hosts_with_port = $cluster_hosts.map |$s| { "${s}:9300" }

  # Set ulimits
  file {
      "/etc/security/limits.d/elasticsearch":
          source => "puppet:///modules/metacpan_elasticsearch/etc/security/elasticsearch";
  }

  # Install ES, but don't run
  class { 'elasticsearch':
    package_url => "https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${$version}.deb",
    java_install => true,
    # Defaults can be in here...
    config => { 'cluster.name' => 'bm' }
  }

  # Setup an actual running instance
  $init_hash = {
    'ES_USER' => 'elasticsearch',
    'ES_GROUP' => 'elasticsearch',
    # Set min/max to the same value (recommended by es).
    'ES_HEAP_SIZE' => $memory,
  }


  # From: https://github.com/CPAN-API/metacpan-puppet/blob/36ea6fc4bacb457a03aa71343fee075a0f7feb97/modules/elasticsearch/templates/config/elasticsearch_yml.erb
  # For 0.20.x installs
  $config_hash_old = {
    'network.host' => '127.0.0.1',
    'http.port' => '9200',

    'cluster.name' => 'bm',
    'cluster.routing.allocation.concurrent_recoveries' =>  '2',

    'index.translog.flush_threshold' => '20000',

    'index.search.slowlog.threshold.query.warn' => '10s',
    'index.search.slowlog.threshold.query.info' => '2s',
    'index.search.slowlog.threshold.fetch.warn' => '1s',


    'gateway.recover_after_nodes' => '1',
    'gateway.recover_after_time' => '2m',
    'gateway.expected_nodes' => '1',
    'gateway.local.compress' => 'false',
    'gateway.local.pretty' => 'true',

    'action.auto_create_index' => '0',

    'bootstrap.mlockall' => '1',
  }

  # As recommended by clinton, for ES 1.4 as a cluster
  # This should really be via hiera or something
  $config_hash_cluster = {
    'network.host' => $ip_address,
    'http.port' => '9200',

    'cluster.name' => 'bm',

    'index.search.slowlog.threshold.query.warn' => '10s',
    'index.search.slowlog.threshold.query.info' => '2s',
    'index.search.slowlog.threshold.fetch.warn' => '1s',

    'gateway.recover_after_nodes' => '2',
    'gateway.recover_after_time' => '2m',
    'gateway.expected_nodes' => '3',

    # only allow one node to start on each box
    'node.max_local_storage_nodes' => '1',

    # require at least two nodes to be able to see each other
    # this prevents split brains
    'discovery.zen.minimum_master_nodes' => '2',

    # Turn OFF multicast, and explisitly do only unicast to listed hosts
    'discovery.zen.ping.multicast.enabled' => false,
    'discovery.zen.ping.unicast.hosts' => $cluster_hosts_with_port,

    'action.auto_create_index' => '0',

  }

  case $version {
    default : { $config_hash = $config_hash_cluster }
    '0.20.2' : { $config_hash = $config_hash_old }
  }

  elasticsearch::instance { 'es-01':
    config => $config_hash,
    init_defaults => $init_hash,
    datadir => $data_dir,
  }

}
