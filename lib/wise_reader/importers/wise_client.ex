defmodule WiseReader.Importers.WiseClient do
  def call() do
    url =
      "https://api.transferwise.com/v1/profiles/13675836/balance-statements/11835403/statement.json?currency=EUR&intervalStart=2023-01-01T00:00:00.000Z&intervalEnd=2024-01-01T00:00:00.000Z&type=COMPACT"

    # TODO: move this config/runtime.ex
    token = System.get_env("TOKEN")
    headers = [{"Authorization", "Bearer #{token}"}]

    resp = HTTPoison.get(url, headers)

    case resp do
      {:ok, resp = %HTTPoison.Response{status_code: 403}} ->
        {"x-2fa-approval", code_2fa} = List.keyfind(resp.headers, "x-2fa-approval", 0)

        signature = sca(code_2fa)

        headers = [
          {"Authorization", "Bearer #{token}"},
          {"x-2fa-approval", code_2fa},
          {"X-Signature", signature}
        ]

        HTTPoison.get(url, headers)
    end
  end

  def sca(code_2fa) do
    rsa_priv_key = ExPublicKey.load!("wise_private.pem")
    {:ok, signature} = ExPublicKey.sign(code_2fa, rsa_priv_key)

    signature
    |> Base.url_encode64()
    |> String.replace("_", "/")
    |> String.replace("-", "+")
  end
end
