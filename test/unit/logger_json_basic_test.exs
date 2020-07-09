defmodule LoggerJSONBasicTest do
  use Logger.Case, async: false
  require Logger
  alias LoggerJSON.Formatters.BasicLogger

  setup do
    :ok =
      Logger.configure_backend(
        LoggerJSON,
        device: :user,
        level: nil,
        metadata: [],
        json_encoder: Jason,
        on_init: :disabled,
        formatter: BasicLogger
      )
  end

  describe "metadata" do
    test "can be configured" do
      Logger.configure_backend(LoggerJSON, metadata: [:user_id])

      assert capture_log(fn ->
               Logger.debug("hello")
             end) =~ "hello"

      Logger.metadata(user_id: 11)
      Logger.metadata(dynamic_metadata: 5)

      log =
        fn -> Logger.debug("hello") end
        |> capture_log()
        |> Jason.decode!()

      assert %{"user_id" => 11} == log["metadata"]
    end

    test "can be configured to :all" do
      Logger.configure_backend(LoggerJSON, metadata: :all)

      Logger.metadata(user_id: 11)
      Logger.metadata(dynamic_metadata: 5)

      log =
        fn -> Logger.debug("hello") end
        |> capture_log()
        |> Jason.decode!()

      assert %{"user_id" => 11, "dynamic_metadata" => 5} = log["metadata"]
    end

    test "can be empty" do
      Logger.configure_backend(LoggerJSON, metadata: [])

      Logger.metadata(user_id: 11)
      Logger.metadata(dynamic_metadata: 5)

      log =
        fn -> Logger.debug("hello") end
        |> capture_log()
        |> Jason.decode!()

      assert %{"message" => "hello"} = log
      assert %{} == log["metadata"]
    end
  end

  test "logs chardata messages" do
    Logger.configure_backend(LoggerJSON, metadata: :all)

    log =
      fn -> Logger.debug([?α, ?β, ?ω]) end
      |> capture_log()
      |> Jason.decode!()

    assert %{"message" => "αβω"} = log
  end

  describe "when doesn't set tz " do
    test "timestamp can be formatted RFC3339" do
      Logger.configure_backend(LoggerJSON, metadata: [])
      log =
        fn -> Logger.debug("hello") end
        |> capture_log()
        |> Jason.decode!()
      assert Regex.match?(~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/, log["time"])
    end
  end

  describe "when set tz=UTC" do
    setup do
      now_tz = System.get_env("TZ")
      System.put_env("TZ", "Etc/UTC")
      on_exit(fn ->
        if now_tz == nil do
          System.delete_env("TZ")
        else
          System.put_env("TZ", now_tz)
        end
      end)
    end
    test "timestamp can be formatted RFC3339" do
      Logger.configure_backend(LoggerJSON, metadata: [])
      log =
        fn -> Logger.debug("hello") end
        |> capture_log()
        |> Jason.decode!()
      assert Regex.match?(~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/, log["time"])
    end
  end

  describe "when set tz=Asia/Tokyo" do
    setup [:set_tz_asia]
    test "timestamp can be formatted RFC3339" do
      Logger.configure_backend(LoggerJSON, metadata: [])
      log =
        fn -> Logger.debug("hello") end
        |> capture_log()
        |> Jason.decode!()
      assert Regex.match?(~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}\+09\:00/, log["time"])
    end
  end

  describe "when set tz=Asia/Tokyo and utc_log=true" do
    setup [:set_tz_asia, :set_utc_log]
    test "timestamp can be formatted Zulu Format" do
      Logger.configure_backend(LoggerJSON, metadata: [])
      log =
        fn -> Logger.debug("hello") end
        |> capture_log()
        |> Jason.decode!()
      assert Regex.match?(~r/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/, log["time"])
    end
  end

  defp set_tz_asia(_) do
    now_tz = System.get_env("TZ")
    System.put_env("TZ", "Asia/Tokyo")
    on_exit(fn ->
      if now_tz == nil do
        System.delete_env("TZ")
      else
        System.put_env("TZ", now_tz)
      end
    end)
  end

  defp set_utc_log(_) do
    now_utc_log = Application.fetch_env!(:logger, :utc_log)
    Application.put_env(:logger, :utc_log, true)
    on_exit(fn ->
      if now_utc_log == nil do
        Application.delete_env(:logger, :utc_log)
      else
        Application.put_env(:logger, :utc_log, now_utc_log)
      end
    end)
  end
end
