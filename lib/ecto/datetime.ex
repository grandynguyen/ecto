defmodule Ecto.DateTime.Util do
  @moduledoc false

  @doc "Pads with zero"
  def zero_pad(val, count) do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end

  @doc "Converts to integer if possible"
  def to_i(nil), do: nil
  def to_i(int) when is_integer(int), do: int
  def to_i(bin) when is_binary(bin) do
    case Integer.parse(bin) do
      {int, ""} -> int
      _ -> nil
    end
  end

  @doc "A guard to check for dates"
  defmacro is_date(_year, month, day) do
    quote do
      unquote(month) in 1..12 and unquote(day) in 1..31
    end
  end

  @doc "A guard to check for times"
  defmacro is_time(hour, min, sec) do
    quote do
      unquote(hour) in 0..23 and unquote(min) in 0..59 and unquote(sec) in 0..59
    end
  end

  @doc """
  Checks if the trailing part of a date/time matches ISO specs.
  """
  defmacro is_iso(x) do
    quote do: unquote(x) in ["", "Z"]
  end

  @doc """
  Gets microseconds from rest and validates it.

  Returns nil if an invalid format is given.
  """
  def usec("." <> rest) do
    case Integer.parse(rest) do
      {int, rest} when int in 0..999999 and is_iso(rest) -> to_usec(int)
      _ -> nil
    end
  end
  def usec(rest) when is_iso(rest), do: 0
  def usec(_), do: nil

  defp to_usec(int) when int < 10, do: int * 100000
  defp to_usec(int) when int < 100, do: int * 10000
  defp to_usec(int) when int < 1000, do: int * 1000
  defp to_usec(int) when int < 10000, do: int * 100
  defp to_usec(int) when int < 100000, do: int * 10
  defp to_usec(int) when int < 1000000, do: int * 1
end

defmodule Ecto.Date do
  import Ecto.DateTime.Util

  @moduledoc """
  An Ecto type for dates.
  """

  @behaviour Ecto.Type
  defstruct [:year, :month, :day]

  @doc """
  The Ecto primitive type.
  """
  def type, do: :date

  @doc """
  Casts to date.
  """
  def cast(<<year::4-bytes, ?-, month::2-bytes, ?-, day::2-bytes>>),
    do: from_parts(to_i(year), to_i(month), to_i(day))
  def cast(%Ecto.Date{} = d),
    do: {:ok, d}
  def cast(%{"year" => year, "month" => month, "day" => day}),
    do: from_parts(to_i(year), to_i(month), to_i(day))
  def cast(%{year: year, month: month, day: day}),
    do: from_parts(to_i(year), to_i(month), to_i(day))
  def cast(_),
    do: :error

  defp from_parts(year, month, day) when is_date(year, month, day) do
    {:ok, %Ecto.Date{year: year, month: month, day: day}}
  end
  defp from_parts(_, _, _), do: :error

  @doc """
  Converts an `Ecto.Date` into a date triplet.
  """
  def dump(%Ecto.Date{year: year, month: month, day: day}) do
    {:ok, {year, month, day}}
  end

  @doc """
  Converts a date triplet into an `Ecto.Date`.
  """
  def load({year, month, day}) do
    {:ok, %Ecto.Date{year: year, month: month, day: day}}
  end

  @doc """
  Converts `Ecto.Date` to its ISO 8601 string representation.
  """
  def to_string(date) do
    String.Chars.Ecto.Date.to_string(date)
  end

  @doc """
  Returns an `Ecto.Date` in local time.
  """
  def local do
    erl_load(:erlang.localtime)
  end

  @doc """
  Returns an `Ecto.Date` in UTC.
  """
  def utc do
    erl_load(:erlang.universaltime)
  end

  defp erl_load({{year, month, day}, _time}) do
    %Ecto.Date{year: year, month: month, day: day}
  end

  defimpl String.Chars do
    def to_string(%Ecto.Date{year: year, month: month, day: day}) do
      zero_pad(year, 4) <> "-" <> zero_pad(month, 2) <> "-" <> zero_pad(day, 2)
    end
  end
end

defmodule Ecto.Time do
  import Ecto.DateTime.Util

  @moduledoc """
  An Ecto type for time.
  """

  @behaviour Ecto.Type
  defstruct [:hour, :min, :sec]

  @doc """
  The Ecto primitive type.
  """
  def type, do: :time

  @doc """
  Casts to time.
  """
  def cast(<<hour::2-bytes, ?:, min::2-bytes, ?:, sec::2-bytes, rest::binary>>) do
    if usec(rest) do
      from_parts(to_i(hour), to_i(min), to_i(sec))
    else
      :error
    end
  end
  def cast(%Ecto.Time{} = t),
    do: {:ok, t}
  def cast(%{"hour" => hour, "min" => min} = map),
    do: from_parts(to_i(hour), to_i(min), to_i(Map.get(map, "sec", 0)))
  def cast(%{hour: hour, min: min} = map),
    do: from_parts(to_i(hour), to_i(min), to_i(Map.get(map, :sec, 0)))
  def cast(_),
    do: :error

  defp from_parts(hour, min, sec) when is_time(hour, min, sec) do
    {:ok, %Ecto.Time{hour: hour, min: min, sec: sec}}
  end
  defp from_parts(_, _, _), do: :error

  @doc """
  Converts an `Ecto.Time` into a time triplet.
  """
  def dump(%Ecto.Time{hour: hour, min: min, sec: sec}) do
    {:ok, {hour, min, sec, 0}}
  end

  @doc """
  Converts a time triplet into an `Ecto.Time`.
  """
  def load({hour, min, sec, _}) do
    {:ok, %Ecto.Time{hour: hour, min: min, sec: sec}}
  end

  @doc """
  Converts `Ecto.Time` to its ISO 8601 without timezone string representation.
  """
  def to_string(time) do
    String.Chars.Ecto.Time.to_string(time)
  end

  @doc """
  Returns an `Ecto.Time` in local time.
  """
  def local do
    erl_load(:erlang.localtime)
  end

  @doc """
  Returns an `Ecto.Time` in UTC.
  """
  def utc do
    erl_load(:erlang.universaltime)
  end

  defp erl_load({_, {hour, min, sec}}) do
    %Ecto.Time{hour: hour, min: min, sec: sec}
  end

  defimpl String.Chars do
    def to_string(%Ecto.Time{hour: hour, min: min, sec: sec}) do
      zero_pad(hour, 2) <> ":" <> zero_pad(min, 2) <> ":" <> zero_pad(sec, 2)
    end
  end
end

defmodule Ecto.DateTime do
  import Ecto.DateTime.Util

  @moduledoc """
  An Ecto type for dates and times.
  """

  @behaviour Ecto.Type
  defstruct [:year, :month, :day, :hour, :min, :sec]

  @doc """
  The Ecto primitive type.
  """
  def type, do: :datetime

  @doc """
  Casts to date time.
  """
  def cast(<<year::4-bytes, ?-, month::2-bytes, ?-, day::2-bytes, sep,
             hour::2-bytes, ?:, min::2-bytes, ?:, sec::2-bytes, rest::binary>>) when sep in [?\s, ?T] do
    if usec(rest) do
      from_parts(to_i(year), to_i(month), to_i(day),
                 to_i(hour), to_i(min), to_i(sec))
    else
      :error
    end
  end

  def cast(%Ecto.DateTime{} = dt) do
    {:ok, dt}
  end

  def cast(%{"year" => year, "month" => month, "day" => day, "hour" => hour, "min" => min} = map) do
    from_parts(to_i(year), to_i(month), to_i(day),
               to_i(hour), to_i(min), to_i(Map.get(map, "sec", 0)))
  end

  def cast(%{year: year, month: month, day: day, hour: hour, min: min} = map) do
    from_parts(to_i(year), to_i(month), to_i(day),
               to_i(hour), to_i(min), to_i(Map.get(map, :sec, 0)))
  end

  def cast(_) do
    :error
  end

  defp from_parts(year, month, day, hour, min, sec)
      when is_date(year, month, day) and is_time(hour, min, sec) do
    {:ok, %Ecto.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec}}
  end
  defp from_parts(_, _, _, _, _, _), do: :error

  @doc """
  Converts an `Ecto.DateTime` into a `{date, time}` tuple.
  """
  def dump(%Ecto.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec}) do
    {:ok, {{year, month, day}, {hour, min, sec, 0}}}
  end

  @doc """
  Converts a `{date, time}` tuple into an `Ecto.DateTime`.
  """
  def load({{year, month, day}, {hour, min, sec, _msec}}) do
    {:ok, %Ecto.DateTime{year: year, month: month, day: day,
                         hour: hour, min: min, sec: sec}}
  end

  @doc """
  Converts `Ecto.DateTime` into an `Ecto.Date`.
  """
  def to_date(%Ecto.DateTime{year: year, month: month, day: day}) do
    %Ecto.Date{year: year, month: month, day: day}
  end

  @doc """
  Converts `Ecto.DateTime` into an `Ecto.Time`.
  """
  def to_time(%Ecto.DateTime{hour: hour, min: min, sec: sec}) do
    %Ecto.Time{hour: hour, min: min, sec: sec}
  end

  @doc """
  Converts the given `Ecto.Date` and `Ecto.Time` into `Ecto.DateTime`.
  """
  def from_date_and_time(%Ecto.Date{year: year, month: month, day: day},
                         %Ecto.Time{hour: hour, min: min, sec: sec}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end

  @doc """
  Converts `Ecto.DateTime` to its ISO 8601 UTC string representation.
  """
  def to_string(datetime) do
    String.Chars.Ecto.DateTime.to_string(datetime)
  end

  @doc """
  Returns an `Ecto.DateTime` in local time.
  """
  def local do
    erl_load(:erlang.localtime)
  end

  @doc """
  Returns an `Ecto.DateTime` in UTC.
  """
  def utc do
    erl_load(:erlang.universaltime)
  end

  defp erl_load({{year, month, day}, {hour, min, sec}}) do
    %Ecto.DateTime{year: year, month: month, day: day,
                   hour: hour, min: min, sec: sec}
  end

  defimpl String.Chars do
    def to_string(%Ecto.DateTime{year: year, month: month, day: day, hour: hour, min: min, sec: sec}) do
      zero_pad(year, 4) <> "-" <> zero_pad(month, 2) <> "-" <> zero_pad(day, 2) <> "T" <>
      zero_pad(hour, 2) <> ":" <> zero_pad(min, 2) <> ":" <> zero_pad(sec, 2) <> "Z"
    end
  end
end
