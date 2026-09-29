module KramdownAsciidoc
  # Represents a parsed Markdown document as a sequence of block-level nodes.
  class Document
    getter nodes : Array(Node)

    def initialize
      @nodes = [] of Node
    end

    def add(node : Node)
      @nodes << node
    end
  end

  # Base class for all AST nodes.
  abstract class Node
  end

  class HeadingNode < Node
    getter level : Int32
    getter content : String

    def initialize(@level, @content)
    end
  end

  class ParagraphNode < Node
    getter content : String

    def initialize(@content)
    end
  end

  class FencedCodeNode < Node
    getter language : String?
    getter content : String

    def initialize(@content, @language = nil)
    end
  end

  class BlockquoteNode < Node
    getter content : String

    def initialize(@content)
    end
  end

  class UnorderedListNode < Node
    getter items : Array(String)

    def initialize(@items)
    end
  end

  class OrderedListNode < Node
    getter items : Array(String)

    def initialize(@items)
    end
  end

  class HorizontalRuleNode < Node
    def initialize
    end
  end

  class TableNode < Node
    getter headers : Array(String)
    getter rows : Array(Array(String))

    def initialize(@headers, @rows)
    end
  end

  class HtmlCommentNode < Node
    getter content : String

    def initialize(@content)
    end
  end

  class HtmlBlockNode < Node
    getter content : String

    def initialize(@content)
    end
  end

  # A simple line-by-line Markdown parser that produces an AST of block-level nodes.
  # Inline formatting is preserved in the raw text and handled by the Converter.
  class Parser
    def self.parse(markdown : String) : Document
      new(markdown).parse
    end

    @lines : Array(String)
    @pos : Int32 = 0

    private def initialize(markdown : String)
      @lines = markdown.lines
      # Remove trailing newline artifact from lines
      if @lines.last? == ""
        # keep it — we'll handle blank lines as separators
      end
    end

    def parse : Document
      doc = Document.new
      while @pos < @lines.size
        start = @pos
        node = parse_block
        doc.add(node) if node
        # Garde-fou : chaque bloc doit consommer au moins une ligne, sinon
        # la boucle ne se termine jamais (cf. lignes de tableau orphelines).
        raise "KramdownAsciidoc::Parser: no progress at line #{start + 1}" if @pos == start
      end
      doc
    end

    private def current_line : String?
      @lines[@pos]?
    end

    private def advance : String?
      line = @lines[@pos]?
      @pos += 1
      line
    end

    private def parse_block : Node?
      # Skip blank lines
      while @pos < @lines.size && @lines[@pos].strip.empty?
        @pos += 1
      end
      return nil if @pos >= @lines.size

      line = @lines[@pos]

      # HTML comment (single-line or multi-line)
      if line.strip.starts_with?("<!--")
        return parse_html_comment
      end

      # Fenced code block
      if line.strip.starts_with?("```")
        return parse_fenced_code
      end

      # Heading (ATX style)
      if match = line.match(/^(\#{1,6})\s+(.*)$/)
        @pos += 1
        level = match[1].size
        content = match[2].rstrip
        # Remove trailing # characters
        content = content.gsub(/\s+#+\s*$/, "")
        return HeadingNode.new(level, content)
      end

      # Horizontal rule
      if line.strip.matches?(/^(-{3,}|\*{3,}|_{3,})$/)
        @pos += 1
        return HorizontalRuleNode.new
      end

      # Table (with header and separator row)
      if line.strip.starts_with?("|") && @pos + 1 < @lines.size && @lines[@pos + 1].strip.matches?(/^\|[\s\-:|]+\|$/)
        return parse_table
      end

      # Table without header, as kramdown does: a row not followed by a
      # separator, or a line containing a pipe followed by such a row
      if line.strip.starts_with?("|") || (line.includes?("|") && @lines[@pos + 1]?.try(&.strip.starts_with?("|")))
        return parse_table_rows_only
      end

      # Blockquote (up to 3 spaces of indentation, as in kramdown)
      if blockquote_line?(line)
        return parse_blockquote
      end

      # Unordered list
      if line.match(/^(\s*)[-*+]\s+/)
        return parse_unordered_list
      end

      # Ordered list
      if line.match(/^(\s*)\d+\.\s+/)
        return parse_ordered_list
      end

      # HTML block (non-comment)
      if line.strip.starts_with?("<") && !line.strip.starts_with?("<!--")
        return parse_html_block
      end

      # Paragraph (default)
      parse_paragraph
    end

    private def parse_fenced_code : FencedCodeNode
      opening = advance.not_nil!.strip
      language = nil
      if match = opening.match(/^```(\w+)/)
        language = match[1]
      end

      content_lines = [] of String
      while @pos < @lines.size
        line = @lines[@pos]
        if line.strip == "```"
          @pos += 1
          break
        end
        content_lines << line
        @pos += 1
      end

      FencedCodeNode.new(content_lines.join("\n"), language)
    end

    private def blockquote_line?(line : String) : Bool
      line.matches?(/^ {0,3}>( |$)/)
    end

    private def parse_blockquote : BlockquoteNode
      lines = [] of String
      while @pos < @lines.size
        line = @lines[@pos]
        line = line.lstrip if blockquote_line?(line)
        if line.starts_with?("> ")
          lines << line[2..]
          @pos += 1
        elsif line == ">"
          lines << ""
          @pos += 1
        else
          break
        end
      end
      BlockquoteNode.new(lines.join("\n").strip)
    end

    private def parse_unordered_list : UnorderedListNode
      items = [] of String
      while @pos < @lines.size
        line = @lines[@pos]
        if match = line.match(/^(\s*)[-*+]\s+(.*)$/)
          items << match[2]
          @pos += 1
        elsif line.strip.empty?
          break
        else
          # Continuation line — append to last item
          if items.size > 0
            items[-1] = items[-1] + " " + line.strip
          end
          @pos += 1
        end
      end
      UnorderedListNode.new(items)
    end

    private def parse_ordered_list : OrderedListNode
      items = [] of String
      while @pos < @lines.size
        line = @lines[@pos]
        if match = line.match(/^(\s*)\d+\.\s+(.*)$/)
          items << match[2]
          @pos += 1
        elsif line.strip.empty?
          break
        else
          # Continuation line
          if items.size > 0
            items[-1] = items[-1] + " " + line.strip
          end
          @pos += 1
        end
      end
      OrderedListNode.new(items)
    end

    private def parse_table : TableNode
      # Header row
      header_line = advance.not_nil!
      headers = parse_table_row(header_line)

      # Separator row (skip it)
      @pos += 1

      TableNode.new(headers, parse_table_body)
    end

    private def parse_table_rows_only : TableNode
      TableNode.new([] of String, parse_table_body)
    end

    # Data rows: like kramdown, any following non-blank line containing a
    # pipe is a row, even when it does not start with one
    # (e.g. `{% if x %}| a | b |`).
    private def parse_table_body : Array(Array(String))
      rows = [] of Array(String)
      while @pos < @lines.size
        line = @lines[@pos]
        break if line.strip.empty?
        break unless line.includes?("|")
        rows << parse_table_row(line)
        @pos += 1
      end
      rows
    end

    private def parse_table_row(line : String) : Array(String)
      cells = line.strip.split("|")
      # Remove first and last empty elements from leading/trailing |
      cells.shift if cells.first?.try(&.strip.empty?)
      cells.pop if cells.last?.try(&.strip.empty?)
      cells.map(&.strip)
    end

    private def parse_html_comment : HtmlCommentNode
      line = @lines[@pos]

      # Single-line comment
      if match = line.match(/<!--(.*)-->/)
        @pos += 1
        return HtmlCommentNode.new(match[1].strip)
      end

      # Multi-line comment
      content_lines = [] of String
      first = line.sub("<!--", "").strip
      content_lines << first unless first.empty?
      @pos += 1

      while @pos < @lines.size
        line = @lines[@pos]
        if line.includes?("-->")
          last = line.sub("-->", "").strip
          content_lines << last unless last.empty?
          @pos += 1
          break
        end
        content_lines << line
        @pos += 1
      end

      HtmlCommentNode.new(content_lines.join("\n").strip)
    end

    private def parse_html_block : HtmlBlockNode
      lines = [] of String
      while @pos < @lines.size
        line = @lines[@pos]
        break if line.strip.empty?
        lines << line
        @pos += 1
      end
      HtmlBlockNode.new(lines.join("\n"))
    end

    private def parse_paragraph : ParagraphNode
      # The first line is always consumed: parse_block has already ruled out
      # every other block type, so breaking on it would loop forever.
      lines = [@lines[@pos]]
      @pos += 1
      while @pos < @lines.size
        line = @lines[@pos]
        break if line.strip.empty?
        break if line.strip.starts_with?("#")
        break if line.strip.starts_with?("```")
        break if line.strip.starts_with?("> ")
        break if line.strip.matches?(/^(-{3,}|\*{3,}|_{3,})$/)
        break if line.match(/^[-*+]\s+/)
        break if line.match(/^\d+\.\s+/)
        break if line.strip.starts_with?("<")
        break if line.strip.starts_with?("|")
        lines << line
        @pos += 1
      end
      ParagraphNode.new(lines.join(" ").strip)
    end
  end
end
