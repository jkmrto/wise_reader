defmodule WiseReader.Importers.Bankinter do
  alias WiseReader.Repo
  alias WiseReader.Transactions.Transaction

  def insert_new_transactions_from_csv(csv_content) do
    rows_csv = String.split(csv_content, "\r\n")

    raw_completed_movements_rows = discard_pending_movements_rows(rows_csv)
    regex = ~r/(\d{1,2})\/(\d{1,2})\/(\d{2})/
    completed_movements = Enum.filter(raw_completed_movements_rows, &Regex.match?(regex, &1))

    completed_movements
    |> Enum.map(fn row_string -> String.split(row_string, ";") end)
    |> Enum.filter(fn [_date, _descr, credit_or_debit, _amount, _] ->
      credit_or_debit == "Crédito"
    end)
    |> Enum.map(&build_transaction_from_row(&1))
    |> Enum.each(&Repo.insert(&1))
  end

  defp build_transaction_from_row(parsed_row) do
    [date_str, description, _credit_or_debit, amount, _] = parsed_row

    reference = "bankinter_#{date_str}_#{description}"

    {:ok, date} = parse_date(date_str)
    {:ok, datetime} = DateTime.new(date, ~T[00:00:00.000])
    datetime = DateTime.truncate(datetime, :second)

    %Transaction{
      reference: reference,
      amount: String.replace(amount, ",", ".") |> Decimal.new() |> Decimal.abs(),
      description: description,
      date: datetime
    }
  end

  # TODO: Maybe this function could be in a more global file
  defp parse_date(date_str) do
    [month_str, day_str, year_str] = String.split(date_str, "/")

    {year, month, day} =
      {String.to_integer("20" <> year_str), String.to_integer(month_str),
       String.to_integer(day_str)}

    case Date.from_erl({year, month, day}) do
      {:ok, date} -> {:ok, date}
      {:error, reason} -> {:error, "Invalid date: #{reason}"}
    end
  end

  defp discard_pending_movements_rows(rows_csv) do
    index_pending_movements =
      Enum.find_index(rows_csv, fn row -> String.contains?(row, "MOVIMIENTOS PENDIENTES") end)

    {completed_movements, _pending_movements} = Enum.split(rows_csv, index_pending_movements)
    completed_movements
  end
end
