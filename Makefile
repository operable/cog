.DEFAULT_GOAL := run
DOCKER_IMAGE ?= operable/cog:0.5-dev

# Note: 'run' does not reset the database, in case you have data
# you're actively using. If this is your first time, run `make
# reset-db` before executing this recipe.
run:
	iex -S mix phoenix.server

reset-db:
	mix ecto.reset --no-start

docker:
	docker build --build-arg MIX_ENV=prod -t $(DOCKER_IMAGE) .

.PHONY: docker
