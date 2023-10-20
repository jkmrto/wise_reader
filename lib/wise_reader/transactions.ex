defmodule WiseReader.Transactions do
  import Ecto.Query

  alias WiseReader.Transactions.Transaction

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

end
