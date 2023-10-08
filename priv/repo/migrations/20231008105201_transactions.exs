defmodule WiseReader.Repo.Migrations.Transactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:reference, :string, null: false)
      add(:amount, :decimal)
      add(:description, :string)
      add(:category, :string)
      add(:date, :utc_datetime)

      add(:wise, :boolean, default: true)

      timestamps()
    end

    create(unique_index(:transactions, :reference))
  end
end
