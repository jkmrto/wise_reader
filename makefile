run:
	source .env; iex -S mix phx.server

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

# Suspend application
scale-down:
	fly scale count 0

docker-compose-db-up:
	docker-compose up  postgres -d

docker-compose-up:
	docker-compose -f docker-compose.wise-config.yml -f docker-compose.yml up
