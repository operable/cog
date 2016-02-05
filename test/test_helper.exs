exclude_slack = System.get_env("TEST_SLACK") == nil
exclude_hipchat = System.get_env("TEST_HIPCHAT") == nil

ExUnit.start(exclude: [slack: exclude_slack, hipchat: exclude_hipchat])
