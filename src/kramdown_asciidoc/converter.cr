module KramdownAsciidoc
  # Converts a parsed Markdown Document (AST) into AsciiDoc text.
  class Converter
    HEADING_MARKERS = {
      1 => "=",
      2 => "==",
      3 => "===",
      4 => "====",
      5 => "=====",
      6 => "======",
    }

    def self.convert(document : Document) : String
      new.convert(document)
    end

    def convert(document : Document) : String
      blocks = document.nodes.map { |node| convert_node(node) }
      result = blocks.join("\n\n")
      # Ensure single trailing newline
      result = result.strip
      result += "\n" unless result.empty?
      result
    end

    private def convert_node(node : Node) : String
      case node
      when HeadingNode
        convert_heading(node)
      when ParagraphNode
        convert_paragraph(node)
      when FencedCodeNode
        convert_fenced_code(node)
      when BlockquoteNode
        convert_blockquote(node)
      when UnorderedListNode
        convert_unordered_list(node)
      when OrderedListNode
        convert_ordered_list(node)
      when HorizontalRuleNode
        convert_horizontal_rule
      when TableNode
        convert_table(node)
      when HtmlCommentNode
        convert_html_comment(node)
      when HtmlBlockNode
        convert_html_block(node)
      else
        ""
      end
    end

    private def convert_heading(node : HeadingNode) : String
      marker = HEADING_MARKERS[node.level]? || "=" * node.level
      "#{marker} #{convert_inline(node.content)}"
    end

    private def convert_paragraph(node : ParagraphNode) : String
      convert_inline(node.content)
    end

    private def convert_fenced_code(node : FencedCodeNode) : String
      result = String.build do |io|
        if lang = node.language
          io << "[source,#{lang}]\n"
        end
        io << "----\n"
        io << node.content
        io << "\n----"
      end
      result
    end

    private def convert_blockquote(node : BlockquoteNode) : String
      content = convert_inline(node.content)
      "____\n#{content}\n____"
    end

    private def convert_unordered_list(node : UnorderedListNode) : String
      node.items.map { |item| "* #{convert_inline(item)}" }.join("\n")
    end

    private def convert_ordered_list(node : OrderedListNode) : String
      node.items.map { |item| ". #{convert_inline(item)}" }.join("\n")
    end

    private def convert_horizontal_rule : String
      "'''"
    end

    private def convert_table(node : TableNode) : String
      headerless = node.headers.empty?
      # AsciiDoc takes the column count from the first row (or the `cols`
      # attribute) and drops the cells of an incomplete last row: rows are
      # padded with empty cells so that no content is lost.
      cols = headerless ? (node.rows.max_of?(&.size) || 1) : node.headers.size

      result = String.build do |io|
        if headerless
          # Headerless table (kramdown table without separator row): the
          # column count is explicit and no row may be taken as a header.
          io << "[%noheader,cols=#{cols}*]\n"
        end
        io << "|===\n"

        # Header row
        unless headerless
          node.headers.each do |header|
            io << "| #{convert_inline(header)} "
          end
          io << "\n"
        end

        # Data rows — each row separated by a blank line from the header
        node.rows.each_with_index do |row, index|
          io << "\n" unless index == 0 && headerless
          row.each do |cell|
            io << "| #{convert_inline(cell)} "
          end
          (-row.size % cols).times { io << "| " }
          io << "\n"
        end

        io << "|==="
      end
      result
    end

    private def convert_html_comment(node : HtmlCommentNode) : String
      "////\n#{node.content}\n////"
    end

    private def convert_html_block(node : HtmlBlockNode) : String
      "++++\n#{node.content}\n++++"
    end

    # Converts Markdown inline formatting to AsciiDoc inline formatting.
    #
    # The key challenge is distinguishing **bold** (double asterisk) from *italic*
    # (single asterisk) in Markdown. We process them in one pass to avoid the bold
    # result `*text*` being misinterpreted as italic.
    def convert_inline(text : String) : String
      result = text

      # Images: ![alt](url) → image:url[alt]  (must come before links)
      result = result.gsub(/!\[([^\]]*)\]\(([^)]+)\)/) do |_, match|
        "image:#{match[2]}[#{match[1]}]"
      end

      # Links: [text](url) → link:url[text]
      result = result.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |_, match|
        "link:#{match[2]}[#{match[1]}]"
      end

      # Strikethrough: ~~text~~ → [line-through]#text#
      result = result.gsub(/~~([^~]+)~~/, "[line-through]#\\1#")

      # Bold + italic asterisk conversion in a single pass
      result = convert_emphasis_asterisks(result)

      # Bold (underscore): __text__ → *text*
      result = result.gsub(/__([^_]+)__/, "*\\1*")

      result
    end

    # Processes asterisk-based emphasis in one pass, correctly distinguishing
    # **bold** (→ *bold*) from *italic* (→ _italic_).
    private def convert_emphasis_asterisks(text : String) : String
      result = String.build(text.size) do |io|
        i = 0
        while i < text.size
          if text[i] == '*'
            if i + 1 < text.size && text[i + 1] == '*'
              # Double asterisk → bold
              # Find closing **
              close = text.index("**", i + 2)
              if close
                inner = text[(i + 2)...close]
                io << '*'
                io << inner
                io << '*'
                i = close + 2
              else
                io << text[i]
                i += 1
              end
            else
              # Single asterisk → italic
              # Find closing single * (not **)
              close = find_closing_single_asterisk(text, i + 1)
              if close >= 0
                inner = text[(i + 1)...close]
                io << '_'
                io << inner
                io << '_'
                i = close + 1
              else
                io << text[i]
                i += 1
              end
            end
          else
            io << text[i]
            i += 1
          end
        end
      end
      result
    end

    # Finds the position of a closing single * that is not part of a ** pair.
    private def find_closing_single_asterisk(text : String, start : Int32) : Int32
      i = start
      while i < text.size
        if text[i] == '*'
          if i + 1 < text.size && text[i + 1] == '*'
            # This is part of ** — skip both
            i += 2
          else
            return i
          end
        else
          i += 1
        end
      end
      -1
    end
  end
end
