defmodule WiseReader.Transactions.Transaction do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "transactions" do
    field(:reference, :string)
    field(:amount, :decimal)
    field(:description, :string)

    field(:category, :string)
    field(:date, :utc_datetime)

    field(:wise, :boolean, default: true)

    timestamps()
  end

  def from_json(json) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second) 

    with {:ok, date, 0} <- DateTime.from_iso8601(json["date"]) do
      %{
        date: DateTime.truncate(date, :second),
        amount: json["details"]["amount"]["value"],
        reference: json["referenceNumber"],
        description: json["details"]["description"],
        category: json["details"]["category"],
        wise: true,
        updated_at: now,
        inserted_at: now
      }
    end
  end

  def dummy() do
    "transactions_sample.json"
    |> File.read!()
    |> Jason.decode!()
    |> process_transations()
  end

  def process_transations(body) do
    body
    |> Map.get("transactions")
    |> Enum.map(&from_json(&1))
    |> Enum.filter(&(&1.description != "Balance cashback"))
  end
end
