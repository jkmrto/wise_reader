defmodule WiseReader.Transactions.Transaction do
  use Ecto.Schema

  @categories [
    "groceries",
    "gym",
    "rent",
    "transport",
    "coworking",
    "leisure",
    "restaurants",
    "books",
    "shopping"
  ]
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
end
