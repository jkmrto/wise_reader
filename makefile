run:
	iex -S mix phx.server

migrate:
	mix ecto.migrate

rollback:
	mix ecto.rollback

deploy:
	fly deploy

port-forward-db:
	fly proxy 5432 -a wise-reader-db

scale-up:
	fly scale count 1

scale-down:
	fly scale count 0

docker-compose-up:
	docker-compose -f docker-compose.wise-config.yml -f docker-compose.yml up
