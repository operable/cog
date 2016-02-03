# Is there a better way to do this? (kevsmith 12/4/2015)
GENERATED_FILES := deps/piper/lib/piper/permissions/piper_rule_lexer.erl \
		   deps/piper/lib/piper/permissions/piper_rule_parser.erl

.DEFAULT_GOAL := run

ifdef BUILDKITE_BUILD_NUMBER
# TEST_DATABASE_URL is set in Buildkite; it points to an Amazon RDS
# PostgreSQL instance we use
TEST_DATABASE_URL := $(TEST_DATABASE_URL).$(BUILDKITE_BUILD_NUMBER)
endif

DIRTY_SCHEDULER_SUPPORT := $(shell ERL_CRASH_DUMP=/dev/null erl -noshell -eval "erlang:system_info(dirty_cpu_schedulers)." -eval "init:stop()" > /dev/null 2>&1; echo $$?)

ci: export DATABASE_URL = $(TEST_DATABASE_URL)
ci: export MIX_ENV = test
ci: ci-setup test-all ci-cleanup

ci-reset:
	@echo "Resetting build environment"
	@rm -rf _build

ci-setup: ci-reset
# Nuke mnesia dirs so we don't get borked on emqttd upgrades
	rm -rf Mnesia.* $(GENERATED_FILES)
	mix deps.get

ci-cleanup:
	mix ecto.drop

setup: check-for-dirty-schedulers
	mix deps.get
	mix ecto.create
	mix ecto.migrate

check-for-dirty-schedulers:
ifneq ($(DIRTY_SCHEDULER_SUPPORT), 0)
	$(error Erlang must be compiled with support for dirty schedulers)
endif

# Note: 'run' does not reset the database, in case you have data
# you're actively using. If this is your first time, run `make
# reset-db` before executing this recipe.
run: check-for-dirty-schedulers
	iex --sname cog_dev@localhost -S mix phoenix.server

reset-db:
	mix ecto.reset

test-rollbacks: export MIX_ENV = test
test-rollbacks: reset-db
	mix do ecto.rollback --all, ecto.drop

test: export MIX_ENV = test
test: reset-db
	mix test $(TEST)

test-all: export MIX_ENV = test
test-all: reset-db
	mix test \
		--include slack \
		--include hipchat

test-watch: export MIX_ENV = test
test-watch: reset-db
	mix test.watch $(TEST)

.PHONY: ci ci-setup ci-cleanup test
