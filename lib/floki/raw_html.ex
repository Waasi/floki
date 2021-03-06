defmodule Floki.RawHTML do
  @moduledoc false

  @self_closing_tags [
    "area",
    "base",
    "br",
    "col",
    "command",
    "embed",
    "hr",
    "img",
    "input",
    "keygen",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr"
  ]

  @encoder &HtmlEntities.encode/1

  def raw_html(html_tree, options) do
    encoder =
      case Keyword.fetch(options, :encode) do
        {:ok, true} -> @encoder
        {:ok, false} -> & &1
        :error -> default_encoder()
      end

    build_raw_html(html_tree, "", encoder)
  end

  defp build_raw_html([], html, _encoder), do: html
  defp build_raw_html(string, _html, encoder) when is_binary(string), do: encoder.(string)

  defp build_raw_html(tuple, html, encoder) when is_tuple(tuple),
    do: build_raw_html([tuple], html, encoder)

  defp build_raw_html([string | tail], html, encoder) when is_binary(string) do
    build_raw_html(tail, html <> encoder.(string), encoder)
  end

  defp build_raw_html([{:comment, comment} | tail], html, encoder),
    do: build_raw_html(tail, html <> "<!--#{comment}-->", encoder)

  defp build_raw_html([{:pi, "xml", attrs} | tail], html, encoder) do
    build_raw_html(tail, html <> "<?xml " <> tag_attrs(attrs) <> "?>", encoder)
  end

  defp build_raw_html([{:doctype, type, public, system} | tail], html, encoder) do
    attr =
      case {public, system} do
        {"", ""} -> ""
        {"", system} -> " SYSTEM \"#{system}\""
        {public, system} -> " PUBLIC \"#{public}\" \"#{system}\""
      end

    build_raw_html(tail, html <> "<!DOCTYPE #{type}#{attr}>", encoder)
  end

  defp build_raw_html([{type, attrs, children} | tail], html, encoder) do
    build_raw_html(tail, html <> tag_for(type, attrs, children, encoder), encoder)
  end

  defp tag_attrs(attr_list) do
    attr_list
    |> Enum.reduce("", &build_attrs/2)
    |> String.trim()
  end

  defp tag_with_attrs(type, [], children), do: "<#{type}" <> close_open_tag(type, children)

  defp tag_with_attrs(type, attrs, children) do
    "<#{type} #{tag_attrs(attrs)}" <> close_open_tag(type, children)
  end

  defp close_open_tag(type, []) when type in @self_closing_tags, do: "/>"
  defp close_open_tag(_type, _), do: ">"

  defp close_end_tag(type, []) when type in @self_closing_tags, do: ""
  defp close_end_tag(type, _), do: "</#{type}>"

  defp build_attrs({attr, true}, attrs), do: ~s(#{attrs} #{attr})
  defp build_attrs({attr, value}, attrs), do: ~s(#{attrs} #{attr}="#{value}")
  defp build_attrs(attr, attrs), do: "#{attrs} #{attr}"

  defp tag_for(type, attrs, content, _encoder) when type in ["script", "style"] do
    tag_with_attrs(type, attrs, []) <> Enum.join(content) <> "</#{type}>"
  end

  defp tag_for(type, attrs, children, encoder) do
    tag_with_attrs(type, attrs, children) <>
      build_raw_html(children, "", encoder) <> close_end_tag(type, children)
  end

  defp default_encoder do
    if Application.get_env(:floki, :encode_raw_html, true) do
      @encoder
    else
      & &1
    end
  end
end
