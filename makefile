run:
	iex -S mix phx.server

migrate:
	mix ecto.migrate

rollback:
	mix ecto.rollback

deploy:
	fly deploy
