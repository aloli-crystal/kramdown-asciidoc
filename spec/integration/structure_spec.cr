require "./spec_helper"

# Document-level structural properties. These aren't tied to a specific
# element; they're invariants that should hold for any reasonable
# AsciiDoc output and are easy to regress when the renderer changes.
describe "Integration · document structure" do
  it "separates consecutive paragraphs with a blank line" do
    result = IntegrationHelper.convert("First paragraph.\n\nSecond paragraph.")
    # Two `\n` between paragraphs is an empty line in AsciiDoc.
    result.should contain("First paragraph.\n\nSecond paragraph.")
  end

  it "separates a heading from the following paragraph with a blank line" do
    result = IntegrationHelper.convert("# Title\n\nBody text.")
    result.should contain("= Title\n\nBody text.")
  end

  it "emits the document title first in the output" do
    result = IntegrationHelper.convert(<<-MD)
      # Main Title

      Body.

      ## Section

      Sub.
      MD
    # The document title must appear before the first section heading.
    title_idx = result.index("= Main Title")
    section_idx = result.index("== Section")
    title_idx.should_not be_nil
    section_idx.should_not be_nil
    (title_idx.not_nil! < section_idx.not_nil!).should be_true
  end

  it "keeps list items on consecutive lines" do
    result = IntegrationHelper.convert("- a\n- b\n- c")
    result.should contain("* a\n* b\n* c")
  end

  it "keeps ordered list items on consecutive lines" do
    result = IntegrationHelper.convert("1. a\n2. b\n3. c")
    result.should contain(". a\n. b\n. c")
  end

  it "emits nothing spurious on a document that is just a heading" do
    result = IntegrationHelper.convert("# Just a Heading")
    result.should eq("= Just a Heading\n")
  end

  it "round-trips nicely when the same input is fed twice in succession" do
    # Converting a Markdown document should not change the result if
    # the same input is processed twice — i.e. the converter is
    # deterministic (no hidden state, no random ids, etc.).
    source = "# Title\n\nA **paragraph**."
    a = IntegrationHelper.convert(source)
    b = IntegrationHelper.convert(source)
    a.should eq(b)
  end
end
