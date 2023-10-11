defmodule WiseReaderWeb.BaseLive do
  use WiseReaderWeb, :live_view

  alias WiseReader.Transactions
  alias WiseReader.Transactions.Transaction

  @categories Transaction.categories()

  def mount(_params, _session, socket) do
    transactions = Transactions.get_transcations()
    {:ok, assign(socket, :transactions, transactions)}
  end

  def handle_event("refresh", _value, socket) do
    {:ok, response} = WiseReader.WiseClient.call()

    transactions =
      response.body
      |> Jason.decode!()
      |> WiseReader.Transactions.Transaction.process_transations()

    {:noreply, assign(socket, :transactions, transactions)}
  end

  def handle_event("category-modified", payload, socket) do
    IO.inspect(payload, label: "#### category-modified received with payload:")
    %{"id" => id, "category" => category} = payload
    Transactions.update_transaction_category(id, category)

    {:noreply, socket}
  end

  defp bg_row(index) do
    if rem(index, 2) == 0, do: "bg-gray-100", else: "bg-white"
  end

  def render(assigns) do
    ~H"""
    <button
      phx-click="refresh"
      class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
    >
      Refresh
    </button>

    <div class="flex flex-col">
      <div class="sm:mx-0.5 lg:mx-0.5">
        <div class="py-2 inline-block  sm:px-6">
          <div class="overflow-hidden">
            <table class="min-w-full">
              <thead class="bg-white border-b">
                <tr>
                  <th scope="col" class="text-sm font-medium text-gray-900 px-6 py-4 text-left">
                    Description
                  </th>

                  <th scope="col" class="text-sm font-medium text-gray-900 px-6 py-4 text-left">
                    Category
                  </th>

                  <th scope="col" class="text-sm font-medium text-gray-900 px-6 py-4 text-left">
                    Amount (€)
                  </th>

                  <th scope="col" class="text-sm font-medium text-gray-900 px-6 py-4 text-left">
                    Date
                  </th>
                </tr>
              </thead>

              <tbody>
                <%= for {transaction, index} <- Enum.with_index(@transactions)  do %>
                  <tr class={bg_row(index) <> " border-b"}>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= transaction.description %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <.category_selector transaction={transaction} />
                    </td>

                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= if transaction.amount, do: Decimal.to_string(transaction.amount) %>
                    </td>

                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= transaction.date %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def category_selector(assigns) do
    assigns = Map.put(assigns, :categories, ["none"] ++ @categories)

    ~H"""
    <select class="random" name="cars" id={@transaction.id} phx-hook="InfiniteScroll">
      <%= for category <- @categories do %>
        <option value={category}><%= String.capitalize(category) %></option>
      <% end %>
    </select>
    """
  end
end
