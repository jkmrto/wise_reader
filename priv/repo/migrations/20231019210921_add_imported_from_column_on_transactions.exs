defmodule WiseReader.Repo.Migrations.AddImportedFromColumnOnTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add(:imported_from, :string, null: true)
    end
  end
end
