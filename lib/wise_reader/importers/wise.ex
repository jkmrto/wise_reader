defmodule WiseReader.Transactions.Wise do
  alias WiseReader.Importers.WiseClient
  alias WiseReader.Transactions.Transaction
  alias WiseReader.Transactions

  @unprocessable_transaction_types [
    "CONVERSION",
    "DEPOSIT",
    "MONEY_ADDED",
    "TRANSFER",
    "UNKNOWN",
    "BALANCE CASHBACK"
  ]

  def import_transactions() do
    {:ok, response} = WiseClient.call()

    tx_wise =
      response.body
      |> Jason.decode!()
      |> process_transations()

    tx_references_wise = Enum.map(tx_wise, & &1.reference)

    tx_references_db = Enum.map(Transactions.get_transcations(), & &1.reference)

    new_references = tx_references_wise -- tx_references_db

    new_txs = Enum.filter(tx_wise, fn tx -> tx.reference in new_references end)

    WiseReader.Repo.insert_all(Transaction, new_txs)
  end

  def build_transactions_params_from_json(json) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    with {:ok, date, 0} <- DateTime.from_iso8601(json["date"]) do
      %{
        date: DateTime.truncate(date, :second),
        amount: maybe_cast_float_to_decimal(json["amount"]["value"]),
        reference: json["referenceNumber"],
        description: json["details"]["description"],
        imported_from: :wise,
        updated_at: now,
        inserted_at: now
      }
    end
  end

  defp maybe_cast_float_to_decimal(nil), do: nil
  defp maybe_cast_float_to_decimal(float), do: Decimal.from_float(float)

  def process_transations(%{"transactions" => transactions}) do
    transactions
    |> Enum.filter(&(&1["details"]["type"] not in @unprocessable_transaction_types))
    |> Enum.map(&build_transactions_params_from_json(&1))
    |> Enum.filter(&(not is_nil(&1.amount)))
    |> remove_reimbursed_transactions()
    |> Enum.map(fn transaction -> %{transaction | amount: Decimal.abs(transaction.amount)} end)
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
      Enum.reduce(transactions, Decimal.new("0"), fn transaction, acc ->
        Decimal.add(acc, transaction.amount)
      end)

    {reference, sum}
  end
end
