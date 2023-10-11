defmodule WiseReader.Transactions do
  alias WiseReader.Transactions.Transaction

  import Ecto.Query

  def get_transcations() do
    query = from(t in Transaction, order_by: [desc: :date])
    WiseReader.Repo.all(query)
  end
end
