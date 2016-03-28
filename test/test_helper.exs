exclude_slack = System.get_env("TEST_SLACK") == nil
exclude_hipchat = System.get_env("TEST_HIPCHAT") == nil
exclude_relay = System.get_env("TEST_RELAY") == nil

ExVCR.Config.cassette_library_dir("test/fixtures/cassettes")

ExUnit.start(exclude: [slack: exclude_slack, hipchat: exclude_hipchat, relay: exclude_relay])
