defmodule WiseReader.Transactions.Transaction do
  use Ecto.Schema

  @categories ["groceries", "gym", "rent", "transport", "coworking", "leisure"]
  @valid_imported_from [:wise, :bankinter]
  @fields [:reference, :amount, :description, :category, :imported_from, :date]

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "transactions" do
    field(:reference, :string)
    field(:amount, :decimal)
    field(:description, :string)

    field(:category, :string)
    field(:imported_from, Ecto.Enum, values: @valid_imported_from)
    field(:date, :utc_datetime)

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> Ecto.Changeset.cast(params, @fields)
    |> Ecto.Changeset.validate_inclusion(:imported_from, @valid_imported_from)
  end

  def categories, do: @categories

  def from_json(json) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    with {:ok, date, 0} <- DateTime.from_iso8601(json["date"]) do
      %{
        date: DateTime.truncate(date, :second),
        amount: maybe_cast_float_to_decimal(json["amount"]["value"]),
        reference: json["referenceNumber"],
        description: json["details"]["description"],
        wise: true,
        updated_at: now,
        inserted_at: now
      }
    end
  end

  defp maybe_cast_float_to_decimal(nil), do: nil
  defp maybe_cast_float_to_decimal(float), do: Decimal.from_float(float)
end
