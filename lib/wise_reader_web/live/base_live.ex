defmodule WiseReaderWeb.BaseLive do
  use WiseReaderWeb, :live_view

  alias WiseReader.Transactions
  alias WiseReader.Transactions.Transaction

  @categories Transaction.categories()

  def mount(_params, _session, socket) do
    transactions = Transactions.get_transcations()

    stats = Transactions.calculate_amount_per_category(transactions)
    svg = build_pie_chart_svg(stats)

    socket = assign(socket, :transactions, transactions)
    socket = assign(socket, :svg, Phoenix.HTML.safe_to_string(svg))
    socket = assign(socket, :show, :expenses)
    socket = assign(socket, :stats, stats)

    IO.inspect(stats)

    {:ok, socket}
  end

  def handle_event("refresh", _value, socket) do
    Transactions.refresh_transactions()
    transactions = Transactions.get_transcations()

    {:noreply, assign(socket, :transactions, transactions)}
  end

  def handle_event("category-modified", payload, socket) do
    %{"id" => id, "category" => category} = payload
    Transactions.update_transaction_category(id, category)

    {:noreply, socket}
  end

  def handle_event("show-expenses", _value, socket) do
    socket = assign(socket, :show, :expenses)

    {:noreply, socket}
  end

  def handle_event("show-stats", _value, socket) do
    socket = assign(socket, :show, :stats)

    {:noreply, socket}
  end

  defp bg_row(index) do
    if rem(index, 2) == 0, do: "bg-gray-100", else: "bg-white"
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-row space-x-4 mx-10">
      <button
        phx-click="refresh"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Refresh
      </button>

      <button
        phx-click="show-expenses"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Expenses
      </button>

      <button
        phx-click="show-stats"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Stats
      </button>
    </div>

    <%= if @show == :expenses  do %>
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
    <% end %>

    <%= if @show == :stats  do %>
      <div class="flex flex-row justify-between my-20">
        <div class="contents mx-15">
          <%= raw(@svg) %>
        </div>
        <div class="mx-10">
          <table class="min-w-full">
            <tbody>
              <%= for {[category, amount], index} <- Enum.with_index(@stats)  do %>
                <tr class={bg_row(index) <> " border-b"}>
                  <td class="px-6 py-2 whitespace-nowrap text-sm font-small text-gray-900">
                    <%= category %>
                  </td>

                  <td class="px-6 py-2 whitespace-nowrap text-sm font-small text-gray-900">
                    <%= amount %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>
    """
  end

  def category_selector(assigns) do
    assigns = Map.put(assigns, :categories, ["none"] ++ @categories)

    ~H"""
    <select id={@transaction.id} phx-hook="InfiniteScroll">
      <%= for category <- @categories do %>
        <option selected={is_selected(@transaction.category, category)} value={category}>
          <%= String.capitalize(category) %>
        </option>
      <% end %>
    </select>
    """
  end

  defp is_selected(same_category, same_category), do: true
  defp is_selected(_tx_category, _option_category), do: false

  defp build_pie_chart_svg(stats) do
    dataset = Contex.Dataset.new(stats, ["Channel", "Count"])

    opts = [
      mapping: %{category_col: "Channel", value_col: "Count"},
      # colour_palette: ["16a34a", "c13584", "499be4", "FF0000", "00f2ea"],
      legend_setting: :legend_right,
      data_labels: true
    ]

    dataset
    |> Contex.Plot.new(Contex.PieChart, 600, 400, opts)
    |> Contex.Plot.to_svg()
  end
end
