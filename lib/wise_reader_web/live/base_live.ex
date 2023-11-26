defmodule WiseReaderWeb.BaseLive do
  use WiseReaderWeb, :live_view

  alias WiseReader.Importers.Bankinter
  alias WiseReader.Transactions
  alias WiseReader.Transactions.Transaction
  alias WiseReader.Transactions.Wise

  @categories Transaction.categories()
  @default_month "november"
  @default_tab :expenses

  @months [
    "january",
    "feburary",
    "march",
    "april",
    "may",
    "june",
    "july",
    "august",
    "september",
    "october",
    "november",
    "december"
  ]
  @month_to_index @months
                  |> Enum.with_index()
                  |> Enum.into(%{}, fn {month_str, index} -> {month_str, index + 1} end)

  def mount(_params, _session, socket) do
    socket = assign(socket, :tab, :expenses)
    socket = assign(socket, :show_modal, false)

    socket = assign(socket, :uploaded_files, [])
    socket = allow_upload(socket, :import_bankinter, accept: ~w(.csv), max_entries: 1)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    month_str = Map.get(params, "month", @default_month)
    tab = get_tab(params)

    index_month = @month_to_index[month_str]
    transactions_per_month = Transactions.get_transactions_grouped_by_date()

    month_transactions = Map.get(transactions_per_month, index_month, [])

    stats = Transactions.calculate_amount_per_category(month_transactions)
    svg = build_pie_chart_svg(stats)

    socket = assign(socket, :svg, Phoenix.HTML.safe_to_string(svg))
    socket = assign(socket, :stats, stats)
    socket = assign(socket, :transactions, month_transactions)
    socket = assign(socket, :month, month_str)
    socket = assign(socket, :tab, tab)

    {:noreply, socket}
  end

  def handle_event("refresh", _value, socket) do
    Wise.import_transactions()
    transactions = Transactions.get_transcations()

    {:noreply, assign(socket, :transactions, transactions)}
  end

  def handle_event("validate-import-bankinter", _value, socket), do: {:noreply, socket}

  def handle_event("import-bankinter", _value, socket) do
    filename =
      consume_uploaded_entries(socket, :import_bankinter, fn %{path: path}, entry ->
        %{client_name: filename} = entry

        {:ok, csv_content} = File.read(path)
        Bankinter.insert_new_transactions_from_csv(csv_content)

        {:ok, filename}
      end)

    socket = put_flash(socket, :info, "The file #{filename} was correctly imported")

    {:noreply, socket}
  end

  def handle_event("category-modified", payload, socket) do
    %{"id" => id, "category" => category} = payload
    Transactions.update_transaction_category(id, category)

    {:noreply, socket}
  end

  def handle_event("change-month", values, socket) do
    %{"month" => month_str} = values

    {:noreply, push_patch(socket, to: ~p"/base/#{month_str}/stats")}
  end

  def handle_event("show-expenses", _value, socket) do
    socket = assign(socket, :show, :expenses)

    {:noreply, push_patch(socket, to: ~p"/base/#{socket.assigns.month}/expenses")}
  end

  def handle_event("show-stats", _value, socket) do
    socket = assign(socket, :show, :stats)

    {:noreply, push_patch(socket, to: ~p"/base/#{socket.assigns.month}/stats")}
  end

  defp bg_row(index) do
    if rem(index, 2) == 0, do: "bg-gray-100", else: "bg-white"
  end

  def render(assigns) do
    ~H"""
    <.modal id="import-bankinter">
      <div class="flex flex-col">
        <h2>Import Bankinter movements (from CSV)</h2>
        <form
          id="upload-form"
          class="w-50"
          phx-submit="import-bankinter"
          phx-change="validate-import-bankinter"
        >
          <.live_file_input class="my-3" upload={@uploads.import_bankinter} />
          <button
            class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 my-1 mx-10 w-32 rounded"
            phx-click={JS.exec("data-cancel", to: "#import-bankinter")}
            type="submit"
          >
            Upload
          </button>
        </form>
      </div>
    </.modal>

    <div class="flex flex-row space-x-4 mx-10">
      <button
        phx-click="refresh"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Import TransferWise
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

      <button
        phx-click={show_modal("import-bankinter")}
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Import bankinter
      </button>
    </div>

    <div class="mt-10">
      <.month_tabs_selector />
    </div>

    <%= if @tab == :expenses  do %>
      <div class="inline-block sm:px-6 w-full">
        <div class="overflow-hidden">
          <table class="min-w-full">
            <thead class="bg-white border-b">
              <tr>
                <.table_cell_header content="Description" />
                <.table_cell_header content="Category" />
                <.table_cell_header content="Amount (€)" />
                <.table_cell_header content="Day" />
                <.table_cell_header content="Origin" />
              </tr>
            </thead>

            <tbody>
              <%= for {transaction, index} <- Enum.with_index(@transactions)  do %>
                <tr class={bg_row(index) <> " border-b"}>
                  <.table_cell_body content={transaction.description} />
                  <.table_cell_body content={category_selector(%{transaction: transaction})} />
                  <.table_cell_body content={Decimal.to_string(transaction.amount)} />
                  <.table_cell_body content={"#{transaction.date.day}/#{transaction.date.month}"} />
                  <.table_cell_body content={capitalized_imported_from(transaction)} />
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @tab == :stats  do %>
      <div class="flex flex-row justify-between my-20">
        <div class="contents mx-15">
          <%= raw(@svg) %>
        </div>
        <div class="mx-10">
          <.expenses_per_category_table stats={@stats} />
        </div>
      </div>
    <% end %>
    """
  end

  defp table_cell_header(assigns) do
    ~H"""
    <th scope="col" class="text-sm font-medium text-gray-900 px-6 py-4 text-left">
      <%= @content %>
    </th>
    """
  end

  defp table_cell_body(assigns) do
    ~H"""
    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
      <%= @content %>
    </td>
    """
  end

  defp expenses_per_category_table(assigns) do
    total =
      assigns.stats
      |> Enum.reduce(0.0, fn [_category, amount], acc -> acc + amount end)
      |> Float.round(2)

    assigns = Map.put(assigns, :total, total)

    ~H"""
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
        <tr class="bg-blue-200 border-b">
          <td class="px-6 py-2 whitespace-nowrap text-sm font-small text-gray-900">
            Total
          </td>

          <td class="px-6 py-2 whitespace-nowrap text-sm font-small text-gray-900">
            <%= @total %>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp get_tab(%{"tab" => tab}) when tab in ["stats", "expenses"], do: String.to_atom(tab)
  defp get_tab(_parmams), do: @default_tab

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

  defp month_tab_classes() do
    "mx-5 block border-x-0 border-b-2 border-t-0 border-transparent px-7 pb-3.5 pt-4 text-xs font-medium uppercase leading-tight text-neutral-900 hover:isolate hover:border-transparent bg-sky-100 hover:bg-neutral-100 focus:isolate focus:border-transparent data-[te-nav-active]:border-primary data-[te-nav-active]:text-primary dark:text-neutral-900 dark:hover:bg-transparent dark:data-[te-nav-active]:border-primary-400 dark:data-[te-nav-active]:text-primary-400 cursor-pointer text-center"
  end

  def month_tabs_selector(assigns) do
    ~H"""
    <ul class="flex list-none flex-row flex-wrap border-b-0 pl-0 ps-20" role="tablist" data-te-nav-ref>
      <li class="flex-2">
        <a phx-click="change-month" phx-value-month="september" class={month_tab_classes()}>
          September
        </a>
      </li>
      <li class="flex-1 flex justify-center">
        <a phx-click="change-month" phx-value-month="october" class={"w-full " <> month_tab_classes()}>
          October
        </a>
      </li>
      <li class="flex-2">
        <a phx-click="change-month" phx-value-month="november" class={month_tab_classes()}>
          November
        </a>
      </li>
    </ul>
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
    |> Contex.Plot.new(Contex.PieChart, 600, 500, opts)
    |> Contex.Plot.to_svg()
  end

  def capitalized_imported_from(%{imported_from: nil}), do: ""

  def capitalized_imported_from(%{imported_from: imported_from}),
    do: String.capitalize("#{imported_from}")
end
