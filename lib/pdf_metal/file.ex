defmodule PdfMetal.File do
  @doc """
  Add the PDF header.
  """
  def add_header({objects, offset, binary}) do
     header = "%PDF-1.4\n\x{128}\x{129}\x{130}\x{131}\n"
     {objects, offset + byte_size(header), binary <> header}
  end

  @doc """
  Given a list of objects, generate their binary representation with their size.
  """
  def transform_objects({objects, offset, binary}) do
    {binary_objects, new_offset} = transform_objects(objects, offset, [])
    {binary_objects, new_offset, binary}
  end

  defp transform_objects([], offset, binary_objects) do
    {binary_objects |> Enum.reverse, offset}
  end
  defp transform_objects([object | objects], offset, binary_objects) do
    binary_object = PdfMetal.Objects.to_binary(object)
    new_offset = offset + byte_size(binary_object)
    new_binary_objects = [{offset, binary_object} | binary_objects]
    transform_objects(objects, new_offset, new_binary_objects)
  end

  @doc """
  Add the PDF body.
  """
  def add_body({binary_objects, offset, binary}) do
    binary_body = binary_objects |> Enum.map(&elem(&1, 1)) |> Enum.join
    {binary_objects, offset, binary <> binary_body}
  end

  @doc """
  Add the cross-reference table.
  """
  def add_cross_reference_table({binary_objects, offset, binary}) do
    binary_table = """
    xref
    0 #{length(binary_objects) + 1}
    0000000000 65535 f
    #{Enum.map(binary_objects, &generate_entry/1)}
    """
    {binary_objects, offset, binary <> binary_table}
  end

  defp generate_entry({offset, _}) do
    binary_offset = :io_lib.format("~10..0B", [offset]) |> List.to_string
    "#{binary_offset} 00000 n \n"
  end

  @doc """
  Add the trailer of the PDF.
  """
  def add_trailer({binary_objects, offset, binary}) do
    dict = %{'Size': length(binary_objects), 'Root': {1, 0}}
      |> PdfMetal.Objects.to_pdf |> PdfMetal.Objects.to_binary
    binary_trailer = """
    trailer #{dict}
    startxref
    #{offset}
    %%EOF
    """
    {binary_objects, offset, binary <> binary_trailer}
  end

  @doc """
  Generate the binary representation of the PDF from its objects.
  """
  def generate_pdf(objects) do
    {objects, 0, ""}
      |> add_header
      |> transform_objects
      |> add_body
      |> add_cross_reference_table
      |> add_trailer
      |> elem(2)
  end
end
