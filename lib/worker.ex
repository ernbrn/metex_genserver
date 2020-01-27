defmodule Metex.Worker do
  use GenServer

  @api_key "5fdc4b227d087ca935060f28aecc33a6"
  @kelvin_to_celsius_conversion_value 273.15
  @name __MODULE__

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts ++ [name: @name])
  end

  def get_temperature(location) do
    GenServer.call(@name, {:location, location})
  end

  def get_stats do
    GenServer.call(@name, :get_stats)
  end

  def reset_stats do
    GenServer.cast(@name, :reset_stats)
  end

  def stop do
    GenServer.cast(@name, :stop)
  end

  def name do
    @name
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:location, location}, _from, stats) do
    case temperature_of(location) do
      {:ok, temp} ->
        new_stats = update_stats(stats, location)
        {:reply, "#{temp}°C", new_stats}

      {:error, error} ->
        {:reply, error, stats}
    end
  end

  def handle_call(:get_stats, _from, stats) do
    {:reply, stats, stats}
  end

  def handle_cast(:reset_stats, _stats) do
    {:noreply, %{}}
  end

  def handle_cast(:stop, stats) do
    {:stop, :normal, stats}
  end

  def terminate(reason, stats) do
    IO.puts("server terminated because of #{IO.inspect(reason)}")
    IO.inspect(stats)
    :ok
  end

  def handle_info(message, stats) do
    IO.puts("Received this random message: #{inspect(message)}")
    {:noreply, stats}
  end

  ## Helper Functions

  defp temperature_of(location) do
    location
    |> build_url()
    |> HTTPoison.get()
    |> parse_response()
  end

  defp build_url(location) do
    ("http://api.openweathermap.org/data/2.5/weather?q=" <> location <> "&appid=" <> @api_key)
    |> URI.encode()
  end

  defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}) do
    body
    |> JSON.decode!()
    |> compute_temperature()
  end

  defp parse_response(error) do
    {:error, error}
  end

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - @kelvin_to_celsius_conversion_value) |> Float.round(1)

      {:ok, temp}
    rescue
      error -> {:error, error}
    end
  end

  defp update_stats(old_stats, location) do
    case Map.has_key?(old_stats, location) do
      true ->
        Map.update!(old_stats, location, &(&1 + 1))

      false ->
        Map.put_new(old_stats, location, 1)
    end
  end
end
