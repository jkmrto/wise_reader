defmodule WiseReader.Transaction do
  defstruct date: nil,
            amount: nil,
            description: nil,
            category: nil

  def from_json(json) do
    %__MODULE__{
      date: json["date"],
      amount: json["details"]["amount"]["value"],
      description: json["details"]["description"],
      category: json["details"]["category"]
    }
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
    |> Enum.map(&WiseReader.Transaction.from_json(&1))
    |> Enum.filter(&(&1.description != "Balance cashback"))
  end
end
