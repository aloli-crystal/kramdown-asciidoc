require "./spec_helper"

describe KramdownAsciidoc do
  describe ".convert" do
    # --- Headings ---
    describe "headings" do
      it "converts level 1 heading" do
        KramdownAsciidoc.convert("# Hello").should eq "= Hello\n"
      end

      it "converts level 2 heading" do
        KramdownAsciidoc.convert("## Section").should eq "== Section\n"
      end

      it "converts level 3 heading" do
        KramdownAsciidoc.convert("### Subsection").should eq "=== Subsection\n"
      end

      it "converts level 4 heading" do
        KramdownAsciidoc.convert("#### Level 4").should eq "==== Level 4\n"
      end

      it "converts level 5 heading" do
        KramdownAsciidoc.convert("##### Level 5").should eq "===== Level 5\n"
      end

      it "converts level 6 heading" do
        KramdownAsciidoc.convert("###### Level 6").should eq "====== Level 6\n"
      end

      it "strips trailing # from headings" do
        KramdownAsciidoc.convert("## Title ##").should eq "== Title\n"
      end
    end

    # --- Bold ---
    describe "bold" do
      it "converts **bold** to *bold*" do
        KramdownAsciidoc.convert("This is **bold** text.").should eq "This is *bold* text.\n"
      end

      it "converts __bold__ to *bold*" do
        KramdownAsciidoc.convert("This is __bold__ text.").should eq "This is *bold* text.\n"
      end
    end

    # --- Italic ---
    describe "italic" do
      it "converts *italic* to _italic_" do
        KramdownAsciidoc.convert("This is *italic* text.").should eq "This is _italic_ text.\n"
      end
    end

    # --- Inline code ---
    describe "inline code" do
      it "preserves `code` as `code`" do
        KramdownAsciidoc.convert("Use `puts` to print.").should eq "Use `puts` to print.\n"
      end
    end

    # --- Fenced code blocks ---
    describe "fenced code blocks" do
      it "converts fenced code block without language" do
        md = "```\nputs \"hello\"\n```"
        expected = "----\nputs \"hello\"\n----\n"
        KramdownAsciidoc.convert(md).should eq expected
      end

      it "converts fenced code block with language" do
        md = "```ruby\nputs \"hello\"\n```"
        expected = "[source,ruby]\n----\nputs \"hello\"\n----\n"
        KramdownAsciidoc.convert(md).should eq expected
      end
    end

    # --- Links ---
    describe "links" do
      it "converts [text](url) to link:url[text]" do
        KramdownAsciidoc.convert("Visit [Google](https://google.com).").should eq "Visit link:https://google.com[Google].\n"
      end
    end

    # --- Images ---
    describe "images" do
      it "converts ![alt](url) to image:url[alt]" do
        KramdownAsciidoc.convert("![Logo](logo.png)").should eq "image:logo.png[Logo]\n"
      end
    end

    # --- Blockquotes ---
    describe "blockquotes" do
      it "converts blockquote" do
        md = "> This is a quote"
        expected = "____\nThis is a quote\n____\n"
        KramdownAsciidoc.convert(md).should eq expected
      end

      it "converts multi-line blockquote" do
        md = "> Line one\n> Line two"
        expected = "____\nLine one\nLine two\n____\n"
        KramdownAsciidoc.convert(md).should eq expected
      end
    end

    # --- Unordered lists ---
    describe "unordered lists" do
      it "converts - list items to * items" do
        md = "- Item one\n- Item two\n- Item three"
        expected = "* Item one\n* Item two\n* Item three\n"
        KramdownAsciidoc.convert(md).should eq expected
      end

      it "converts * list items to * items" do
        md = "* Alpha\n* Beta"
        expected = "* Alpha\n* Beta\n"
        KramdownAsciidoc.convert(md).should eq expected
      end
    end

    # --- Ordered lists ---
    describe "ordered lists" do
      it "converts numbered list items to . items" do
        md = "1. First\n2. Second\n3. Third"
        expected = ". First\n. Second\n. Third\n"
        KramdownAsciidoc.convert(md).should eq expected
      end
    end

    # --- Horizontal rules ---
    describe "horizontal rules" do
      it "converts --- to '''" do
        KramdownAsciidoc.convert("---").should eq "'''\n"
      end

      it "converts *** to '''" do
        KramdownAsciidoc.convert("***").should eq "'''\n"
      end

      it "converts ___ to '''" do
        KramdownAsciidoc.convert("___").should eq "'''\n"
      end
    end

    # --- Tables ---
    describe "tables" do
      it "converts Markdown table to AsciiDoc table" do
        md = "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |"
        result = KramdownAsciidoc.convert(md)
        result.should contain("|===")
        result.should contain("| Header 1")
        result.should contain("| Cell 1")
      end

      it "produces valid AsciiDoc table structure" do
        md = "| Name | Age |\n| --- | --- |\n| Alice | 30 |\n| Bob | 25 |"
        expected = "|===\n| Name | Age \n\n| Alice | 30 \n\n| Bob | 25 \n|===\n"
        KramdownAsciidoc.convert(md).should eq expected
      end
    end

    # --- HTML comments ---
    describe "HTML comments" do
      it "converts single-line HTML comment to AsciiDoc comment block" do
        md = "<!-- This is a comment -->"
        expected = "////\nThis is a comment\n////\n"
        KramdownAsciidoc.convert(md).should eq expected
      end
    end

    # --- Paragraphs ---
    describe "paragraphs" do
      it "preserves paragraph text" do
        KramdownAsciidoc.convert("Hello world.").should eq "Hello world.\n"
      end

      it "separates paragraphs with blank lines" do
        md = "First paragraph.\n\nSecond paragraph."
        expected = "First paragraph.\n\nSecond paragraph.\n"
        KramdownAsciidoc.convert(md).should eq expected
      end
    end

    # --- Combined conversions ---
    describe "combined" do
      it "converts a document with heading and bold" do
        md = "# Hello\n\nThis is **bold**."
        expected = "= Hello\n\nThis is *bold*.\n"
        KramdownAsciidoc.convert(md).should eq expected
      end

      it "converts a complex document" do
        md = <<-MD
          # Title

          A paragraph with **bold** and *italic*.

          ## Code Example

          ```crystal
          puts "hello"
          ```

          - Item 1
          - Item 2

          > A quote

          ---
          MD
        result = KramdownAsciidoc.convert(md)
        result.should contain("= Title")
        result.should contain("*bold*")
        result.should contain("_italic_")
        result.should contain("[source,crystal]")
        result.should contain("----")
        result.should contain("* Item 1")
        result.should contain("____")
        result.should contain("'''")
      end
    end
  end

  describe ".convert_file" do
    it "converts a file and returns the result" do
      tmp_input = File.tempfile("test", ".md") do |f|
        f.print "# Test\n\nHello **world**."
      end
      begin
        result = KramdownAsciidoc.convert_file(tmp_input.path)
        result.should eq "= Test\n\nHello *world*.\n"
      ensure
        tmp_input.delete
      end
    end

    it "writes output to a file when output_path is given" do
      tmp_input = File.tempfile("test", ".md") do |f|
        f.print "# Test"
      end
      tmp_output = File.tempfile("test", ".adoc")
      begin
        KramdownAsciidoc.convert_file(tmp_input.path, tmp_output.path)
        File.read(tmp_output.path).should eq "= Test\n"
      ensure
        tmp_input.delete
        tmp_output.delete
      end
    end
  end
end
