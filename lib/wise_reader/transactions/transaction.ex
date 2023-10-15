defmodule WiseReader.Transactions.Transaction do
  use Ecto.Schema

  @unprocessable_transaction_types [
    "CONVERSION",
    "DEPOSIT",
    "MONEY_ADDED",
    "TRANSFER",
    "UNKNOWN",
    "BALANCE CASHBACK"
  ]

  @categories ["groceries", "gym", "rent", "transport", "coworking", "leisure"]

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

  def changeset(struct, params) do
    struct
    |> Ecto.Changeset.cast(params, [:category])
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

  def dummy() do
    "transactions_sample.json"
    |> File.read!()
    |> Jason.decode!()
    |> process_transations()
  end

  def process_transations(body) do
    body
    |> Map.get("transactions")
    |> Enum.filter(&(&1["details"]["type"] not in @unprocessable_transaction_types))
    |> Enum.map(&from_json(&1))
    |> Enum.filter(&(not is_nil(&1.amount)))
    |> remove_reimbursed_transactions()
  end

  defp remove_reimbursed_transactions(transactions) do
    check_all_repated_transactions_are_reimbursements(transactions)

    transactions
    |> Enum.group_by(& &1.reference)
    |> Enum.filter(fn {_reference, transactions} -> length(transactions) == 1 end)
    |> Enum.map(fn {_reference, [transaction]} -> transaction end)
  end

  defp check_all_repated_transactions_are_reimbursements(transactions) do
    summed_transactions_non_zero =
      transactions
      |> Enum.group_by(& &1.reference)
      |> Enum.filter(fn {_reference, transactions} -> length(transactions) > 1 end)
      |> Enum.map(&sum_up_transactions/1)
      |> Enum.filter(fn {_reference, sum_amount} -> sum_amount == Decimal.new("0") end)

    case summed_transactions_non_zero do
      [] ->
        :ok

      _ ->
        transactions_reference = Enum.map(summed_transactions_non_zero, &elem(&1, 0))
        "Error proccessing repeated transactions #{inspect(transactions_reference)}"
    end
  end

  defp sum_up_transactions({reference, transactions}) do
    sum =
      Enum.reduce(transactions, Decimal.new("0"), fn transaction, acc -> Decimal.add(acc, transaction.amount) end)

    {reference, sum}
  end
end
