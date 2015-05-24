defmodule PdfMetal.Objects do
  import Enum, only: [map: 2, join: 2]

  @doc """
  Convert an Elixir value to the atom :null or a tuple of the type {:pdf_object, value}.
  """
  def to_pdf(nil),                              do: :null
  def to_pdf(boolean) when is_boolean(boolean), do: {:boolean, boolean}
  def to_pdf(number)  when is_number(number),   do: {:number,  number}
  def to_pdf(string)  when is_binary(string),   do: {:string,  string}
  def to_pdf(atom)    when is_atom(atom),       do: {:name,    Atom.to_string(atom)}
  def to_pdf(list)    when is_list(list),       do: {:array,   map(list, &to_pdf/1)}
  def to_pdf(map)     when is_map(map),    do: {:dictionary,   map(map, &pair_to_pdf/1)}
  def to_pdf({:stream, value}),            do: {:stream,    value}
  def to_pdf({number, generation, value}), do: {:object,    number, generation, to_pdf(value)}
  def to_pdf({number, generation}),        do: {:reference, number, generation}

  # TODO: Replace the characters outside the range 21h and 7Eh in names,
  # as well as the character # and whitespace characters.
  @doc """
  Convert :null or a tuple of the form {:pdf_object, value} to its PDF binary representation.
  """
  def to_binary(:null),               do: "null"
  def to_binary({:boolean, true}),    do: "true"
  def to_binary({:boolean, false}),   do: "false"
  def to_binary({:number,  number}),  do: "#{number}"
  def to_binary({:string,  string}),  do: ("(#{escape_parentheses(string)})")
  def to_binary({:name,    name}),    do: "/#{name}"
  def to_binary({:array,   array}),   do: "[#{array |> map(&to_binary/1) |> join(" ")}]"
  def to_binary({:dictionary, dict}), do: "<<#{dict |> map(&pair_to_binary/1) |> join(" ")}>>"
  def to_binary({:stream,  stream}),  do: generate_stream(stream)
  def to_binary({:object, number, generation, value}), do: "#{number} #{generation} obj #{to_binary(value)}\nendobj\n"
  def to_binary({:reference, number, generation}),     do: "#{number} #{generation} R"

  defp escape_parentheses(string) do
    string
      |> String.replace("(", "\\(")
      |> String.replace(")", "\\)")
  end

  defp pair_to_pdf({first, second}) do
    {to_pdf(first), to_pdf(second)}
  end

  defp pair_to_binary({first, second}) do
    "#{to_binary(first)} #{to_binary(second)}"
  end

  defp generate_stream(stream) do
    dictionary = %{'Length': byte_size(stream)}
      |> to_pdf
      |> to_binary
    "#{dictionary}\nstream\n#{stream}\nendstream"
  end
end
