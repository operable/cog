# Is there a better way to do this? (kevsmith 12/4/2015)
GENERATED_FILES := deps/piper/lib/piper/permissions/piper_rule_lexer.erl \
		   deps/piper/lib/piper/permissions/piper_rule_parser.erl

.DEFAULT_GOAL := run

DOCKER_IMAGE      ?= operable/cog:0.5-dev

deps:
	mix deps.get

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

.PHONY: test docker unit-tests integration-tests deps
