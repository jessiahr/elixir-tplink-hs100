defmodule Hs100.Discover do
  @moduledoc "Process for sending periodic broadcasts to all plugs and collecting their responses."

  @default_options [
    # Port used for broadcasts.
    broadcast_port: 9999,
    # Address used for broadcasts.
    broadcast_address: "255.255.255.255",
    # Command used for broadcasting
    broadcast_command: "{\"system\":{\"get_sysinfo\":{}}}",
    # Sending broadcasts every milliseconds.
    interval_ms: 1000,
    # Marking a device as offline after 3 missed responses.
    offline_counter: 3,
  ]

  defmodule State do
    defstruct [
      options: [],
      socket: nil,
      timer: nil,
      devices: %{},
    ]
  end


  use GenServer
  require Logger

  alias Hs100.Encryption

  #--- Public

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    opts = Keyword.merge(@default_options, opts)

    {:ok, socket} = create_udp_socket()

    {:ok, timer} = :timer.apply_interval(opts[:interval_ms], __MODULE__, :trigger, [self()])

    {:ok, _} = :timer.apply_interval(1000, __MODULE__, :print_devices, [self()])

    {:ok, %State{options: opts, socket: socket, timer: timer}}
  end

  def trigger(process) do
    # Sending a message to process starting a broadcast
    GenServer.cast(process, :trigger)
  end

  def print_devices(process) do
    IO.puts "\n------------------"
    GenServer.call(process, :get_devices)
    |> Enum.each(fn {id, device} ->
      %{sysinfo: %{"alias" => alias}} = device
      IO.puts "#{id}: #{alias}"
    end)
  end

  #--- Callbacks

  def handle_cast(:trigger, state) do
    :ok = send_discover(state)
    {:noreply, state}
  end

  def handle_call(:get_devices, _from, state) do
    {:reply, state.devices, state}
  end

  def handle_info({:udp, socket, ip, port, data}, %State{socket: socket} = state) do
    state = handle_response(state, ip, port, data)
    {:noreply, state}
  end

  #--- Internals

  defp handle_response(%State{} = state, ip, port, data) do
    %{"system" => %{"get_sysinfo" => sysinfo}} = decrypt_and_parse(data)
    set_device(state, ip_to_string(ip), port, sysinfo)
  end

  defp create_udp_socket() do
    :gen_udp.open(0, [
     :binary, # Sending data as binary.
     {:broadcast, true}, # Allowing broadcasts.
     {:active, true}, # New messages will be given to handle_info()
   ])
 end

  defp send_discover(state) do
    :gen_udp.send(
      state.socket,
      to_charlist(state.options[:broadcast_address]),
      state.options[:broadcast_port],
      Encryption.encrypt(state.options[:broadcast_command])
    )
  end

  defp set_device(state, ip, port, %{"deviceId" => device_id} = sysinfo) do
    device_info = %{ip: ip, port: port, sysinfo: sysinfo}
    %{state|
      devices: Map.put(state.devices, device_id, device_info)
    }
  end

  defp ip_to_string({ip1, ip2, ip3, ip4}), do: "#{ip1}.#{ip2}.#{ip3}.#{ip4}"

  defp decrypt_and_parse(data), do: data |> Encryption.decrypt |> Poison.decode!

end