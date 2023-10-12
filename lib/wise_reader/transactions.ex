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

  def refresh_transactions() do
    {:ok, response} = WiseReader.WiseClient.call()

    tx_wise =
      response.body
      |> Jason.decode!()
      |> WiseReader.Transactions.Transaction.process_transations()

    tx_references_wise = Enum.map(tx_wise, & &1.reference)

    tx_references_db = Enum.map(get_transcations(), & &1.reference)

    new_references = tx_references_wise -- tx_references_db

    new_txs = Enum.filter(tx_wise, fn tx -> tx.reference in new_references end)

    WiseReader.Repo.insert_all(Transaction, new_txs)
  end
end
