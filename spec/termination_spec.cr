require "./spec_helper"

# Non-regression: lines starting with a pipe that were not part of a table
# with a separator row made the parser loop forever (100 % CPU).
describe "KramdownAsciidoc.convert termination" do
  it "converts a pipe line followed by a table row without separator" do
    ConversionGuard.convert("x| A | b |\n| N | c |\n").should eq(
      "[%noheader,cols=3*]\n|===\n| x | A | b \n\n| N | c | \n|===\n")
  end

  it "converts a single table row without separator as a headerless table" do
    ConversionGuard.convert("| N | c |\n").should eq(
      "[%noheader,cols=2*]\n|===\n| N | c \n|===\n")
  end

  it "keeps a lone line containing a pipe as a paragraph" do
    ConversionGuard.convert("x| A | b |\n").should eq "x| A | b |\n"
  end

  it "keeps a row not starting with a pipe inside a table" do
    md = "| a | b |\n|--|--|\nx| A | b |\n| N | c |\n"
    ConversionGuard.convert(md).should eq(
      "|===\n| a | b \n\n| x | A | b | \n\n| N | c \n|===\n")
  end

  it "converts a Liquid-guarded row as in a Partiduo template" do
    md = "| Libellé | Montant |\n|--|--:|\n" \
         "{% if totaux.acompte %}| Acomptes déduits | 10 |\n" \
         "| **Net à payer** | 90 |\n"
    ConversionGuard.convert(md).should eq(
      "|===\n| Libellé | Montant \n\n| {% if totaux.acompte %} | Acomptes déduits | 10 | \n\n" \
      "| *Net à payer* | 90 \n|===\n")
  end

  it "ends the table at a line without pipe" do
    md = "| a | b |\n|--|--|\n| A | b |\nx\n| N | c |\n"
    ConversionGuard.convert(md).should eq(
      "|===\n| a | b \n\n| A | b \n|===\n\nx\n\n" \
      "[%noheader,cols=2*]\n|===\n| N | c \n|===\n")
  end

  it "converts a # not followed by a space as a paragraph" do
    ConversionGuard.convert("#foo\n").should eq "#foo\n"
  end

  it "converts an indented blockquote" do
    ConversionGuard.convert("  > cite\n").should eq "____\ncite\n____\n"
  end
end
