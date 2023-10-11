defmodule WiseReader.Transactions do
  alias WiseReader.Transactions.Transaction

  import Ecto.Query

  def get_transcations() do
    query = from(t in Transaction, order_by: [desc: :date])
    WiseReader.Repo.all(query)
  end

  def update_transaction_category(transaction_id, category) do
    Transaction
    |> WiseReader.Repo.get(transaction_id)
    |> Transaction.changeset(%{"category" => category})
    |> WiseReader.Repo.update()
  end
end
