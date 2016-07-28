use Mix.Config

config :emqttd, :access,
  auth: [cog_internal: []],
  acl: [cog_internal: []]

config :emqttd, :broker,
  sys_interval: 60,
  retained: [expired_after: 0,
             max_message_num: 100000,
             max_payload_size: 1048576],
  pubsub: [pool_size: 8,
           subscription: true,
           route_aging: 5]

config :emqttd, :mqtt,
  packet: [max_clientid_len: 512,
           max_packet_size: 1048576],
  client: [idle_timeout: 1],
  session: [max_inflight: 100,
            unack_retry_interval: 60,
            await_rel_timeout: 20,
            max_awaiting_rel: 0,
            collect_interval: 0,
            expired_after: 120],
  queue: [type: :simple,
          max_length: 100,
          low_watermark: 0.2,
          high_watermark: 0.6,
          queue_qos0: true]

config :emqttd, :sysmon,
  long_gc: false,
  long_schedule: 240,
  large_heap: 8388608,
  busy_port: false,
  busy_dist_port: false

config :emqttd, :plugins,
  plugins_dir: '/dev/null',
  loaded_file: '/dev/null'

config :emqttd, :modules,
  presence: [qos: 0],
  subscription: [:backend]
