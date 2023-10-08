defmodule WiseReader.Repo do
  use Ecto.Repo,
    otp_app: :wise_reader,
    adapter: Ecto.Adapters.Postgres
end
