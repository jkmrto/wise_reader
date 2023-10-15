defmodule WiseReader.Transactions do
  import Ecto.Query

  alias WiseReader.Transactions.Transaction

  @unprocessable_transaction_types [
    "CONVERSION",
    "DEPOSIT",
    "MONEY_ADDED",
    "TRANSFER",
    "UNKNOWN",
    "BALANCE CASHBACK"
  ]

  def get_transcations() do
    query = from(t in Transaction, order_by: [desc: :date])
    WiseReader.Repo.all(query)
  end

  def get_transactions_grouped_by_date() do
    # TODO: Probably this could be optimized at DB level someway
    transactions = get_transcations()
    Enum.group_by(transactions, &DateTime.to_date(&1.date).month)
  end

  def update_transaction_category(transaction_id, category) do
    Transaction
    |> WiseReader.Repo.get(transaction_id)
    |> Transaction.changeset(%{"category" => category})
    |> WiseReader.Repo.update()
  end

  def refresh_transactions() do
    {:ok, response} = WiseReader.WiseClient.call()

    tx_wise =
      response.body
      |> Jason.decode!()
      |> process_transations()

    tx_references_wise = Enum.map(tx_wise, & &1.reference)

    tx_references_db = Enum.map(get_transcations(), & &1.reference)

    new_references = tx_references_wise -- tx_references_db

    new_txs = Enum.filter(tx_wise, fn tx -> tx.reference in new_references end)

    WiseReader.Repo.insert_all(Transaction, new_txs)
  end

  def calculate_amount_per_category(transactions) do
    transactions
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {key, elements} ->
      {key, Enum.map(elements, & &1.amount) |> Enum.reduce(&Decimal.add(&1, &2))}
    end)
    |> Enum.filter(fn {category, _amount} -> category not in [nil, ""] end)
    |> Enum.map(fn {category, decimal_sum} ->
      [String.capitalize(category), Decimal.to_float(decimal_sum)]
    end)
    |> Enum.sort_by(fn [_category, amount] -> amount end, :desc)
  end

  def process_transations(%{"transactions" => transactions}) do
    transactions
    |> Enum.filter(&(&1["details"]["type"] not in @unprocessable_transaction_types))
    |> Enum.map(&Transaction.from_json(&1))
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
      Enum.reduce(transactions, Decimal.new("0"), fn transaction, acc ->
        Decimal.add(acc, transaction.amount)
      end)

    {reference, sum}
  end
end
