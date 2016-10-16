# Is there a better way to do this? (kevsmith 12/4/2015)
GENERATED_FILES := deps/piper/lib/piper/permissions/piper_rule_lexer.erl \
		   deps/piper/lib/piper/permissions/piper_rule_parser.erl

.DEFAULT_GOAL := run

ifdef BUILDKITE_BUILD_NUMBER
# TEST_DATABASE_URL is set in Buildkite; it points to an Amazon RDS
# PostgreSQL instance we use
TEST_DATABASE_URL := $(TEST_DATABASE_URL).$(BUILDKITE_BUILD_NUMBER)
endif

DOCKER_IMAGE      ?= operable/cog:0.5-dev

deps:
	mix deps.get

ifeq ($(wildcard NO_CI),)
ci: export MIX_ENV = test
ci: ci-setup test-all ci-cleanup

ci-reset:
	@echo "Resetting build environment"
#	@rm -rf _build

ci-setup: deps ci-reset
# Nuke mnesia dirs so we don't get borked on emqttd upgrades
	rm -rf Mnesia.* $(GENERATED_FILES) deps

ci-cleanup:
	mix ecto.drop
else
ci:
	@echo "NO_CI file found. CI build targets skipped."
	@exit 0
endif

setup:
	mix deps.get
	mix ecto.create
	mix ecto.migrate

# Note: 'run' does not reset the database, in case you have data
# you're actively using. If this is your first time, run `make
# reset-db` before executing this recipe.
run:
	iex -S mix phoenix.server

reset-db: deps
	mix ecto.reset --no-start

test-rollbacks: export MIX_ENV = test
test-rollbacks: reset-db
	mix do ecto.rollback --all, ecto.drop

test: export MIX_ENV = test
test: deps reset-db
	mix test $(TEST)

test-all: export MIX_ENV = test
test-all: unit-tests integration-tests

unit-tests: export MIX_ENV = test
unit-tests: deps reset-db
	mix test --exclude=integration

integration-tests: export MIX_ENV = test
integration-tests: deps reset-db
	mix test --only=integration

test-watch: export MIX_ENV = test
test-watch: reset-db
	mix test.watch $(TEST)

coverage: export MIX_ENV = test
coverage: reset-db
coverage:
	mix coveralls.html

docker:
	docker build --build-arg MIX_ENV=prod -t $(DOCKER_IMAGE) .

.PHONY: ci ci-setup ci-cleanup test docker unit-tests integration-tests deps
