defmodule WiseReaderWeb.BaseLive do
  use WiseReaderWeb, :live_view

  alias WiseReader.Transactions
  alias WiseReader.Transactions.Transaction

  @categories Transaction.categories()
  @default_month 10

  def mount(_params, _session, socket) do
    transactions_per_month = Transactions.get_transactions_grouped_by_date()

    stats = Transactions.calculate_amount_per_category(transactions_per_month[@default_month])
    svg = build_pie_chart_svg(stats)

    socket = assign(socket, :transactions, transactions_per_month[@default_month])
    socket = assign(socket, :svg, Phoenix.HTML.safe_to_string(svg))
    socket = assign(socket, :show, :expenses)
    socket = assign(socket, :stats, stats)
    socket = assign(socket, :show_modal, false)

    socket = assign(socket, :uploaded_files, [])
    socket = allow_upload(socket, :import_bankinter, accept: ~w(.csv), max_entries: 1)

    {:ok, socket}
  end

  def handle_event("refresh", _value, socket) do
    Transactions.refresh_transactions()
    transactions = Transactions.get_transcations()

    {:noreply, assign(socket, :transactions, transactions)}
  end

  def handle_event("validate-import-bankinter", _value, socket) do
    {:noreply, socket}
  end

  alias WiseReader.Importers.Bankinter

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

  # {completed_movements, pending_movements} = Enum.split(chao, index) 

  def handle_event("category-modified", payload, socket) do
    %{"id" => id, "category" => category} = payload
    Transactions.update_transaction_category(id, category)

    {:noreply, socket}
  end

  def handle_event("show-expenses", _value, socket) do
    socket = assign(socket, :show, :expenses)

    {:noreply, socket}
  end

  def handle_event("change-month", values, socket) do
    %{"month" => month_str} = values
    month = String.to_integer(month_str)

    transactions_per_month = Transactions.get_transactions_grouped_by_date()

    stats = Transactions.calculate_amount_per_category(transactions_per_month[month])
    svg = build_pie_chart_svg(stats)

    socket = assign(socket, :svg, Phoenix.HTML.safe_to_string(svg))
    socket = assign(socket, :stats, stats)
    socket = assign(socket, :transactions, Map.get(transactions_per_month, month, []))

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
    <.modal id="import-bankinter">
      <div class="flex flex-col">
        <h2>This is a modal</h2>
        <form id="upload-form" phx-submit="import-bankinter" phx-change="validate-import-bankinter">
          <.live_file_input upload={@uploads.import_bankinter} />
          <button type="submit">Upload</button>
        </form>
      </div>
    </.modal>

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

    <%= if @show == :expenses  do %>
      <div class="inline-block  sm:px-6">
        <div class="overflow-hidden">
          <table class="min-w-full">
            <thead class="bg-white border-b">
              <tr>
                <.table_cell_header content="Description" />
                <.table_cell_header content="Category" />
                <.table_cell_header content="Amount (€)" />
                <.table_cell_header content="Date" />
              </tr>
            </thead>

            <tbody>
              <%= for {transaction, index} <- Enum.with_index(@transactions)  do %>
                <tr class={bg_row(index) <> " border-b"}>
                  <.table_cell_body content={transaction.description} />
                  <.table_cell_body content={category_selector(%{transaction: transaction})} />
                  <.table_cell_body content={Decimal.to_string(transaction.amount)} />
                  <.table_cell_body content={transaction.date} />
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @show == :stats  do %>
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
      |> Enum.reduce(0, fn [_category, amount], acc -> acc + amount end)
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
        <a phx-click="change-month" phx-value-month={9} class={month_tab_classes()}>
          September
        </a>
      </li>
      <li class="flex-1 flex justify-center">
        <a phx-click="change-month" phx-value-month={10} class={"w-full " <> month_tab_classes()}>
          October
        </a>
      </li>
      <li class="flex-2">
        <a phx-click="change-month" phx-value-month={11} class={month_tab_classes()}> November </a>
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
end
