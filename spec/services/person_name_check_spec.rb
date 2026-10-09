require "rails_helper"

RSpec.describe PersonNameCheck do
  describe ".names_in" do
    def fulls(text)   = described_class.names_in(text).map(&:full).compact
    def surnames(text) = described_class.names_in(text).map(&:surname)

    it "finds a first and last name" do
      expect(fulls("We thank Dana Whitlock for six years of work.")).to eq([ "Dana Whitlock" ])
    end

    it "finds a surname after a title, with or without a period" do
      expect(surnames("Pastor Abernathy agrees, and so does Ms. Okafor.")).to contain_exactly("Abernathy", "Okafor")
    end

    it "ignores places, organizations, days, and months" do
      text = "The Elm Street Community Garden and Maple Hall open on Saturday in March. Riverside Commons Tenants Association agrees."
      expect(described_class.names_in(text)).to be_empty
    end

    it "ignores a title-cased heading" do
      expect(described_class.names_in("Extend Tool Library Hours On Weekends")).to be_empty
    end

    it "drops a sentence-initial word the text also uses in lowercase" do
      text = "Extend Saturday hours. We extend thanks to everyone."
      expect(described_class.names_in(text)).to be_empty
    end

    it "never treats a single capitalized word as a full name" do
      expect(fulls("Bikes go in the shed. Paint costs money.")).to be_empty
    end
  end

  describe ".found_in" do
    let(:input) { "This proposal thanks Treasurer Dana Whitlock and keeps her as treasurer." }

    it "flags a full name from the input, in any case" do
      expect(described_class.found_in("That the co-op thanks dana whitlock.", input)).to eq([ "Dana Whitlock" ])
    end

    it "flags the surname alone when capitalized" do
      expect(described_class.found_in("That Whitlock stays on.", input)).to eq([ "Whitlock" ])
    end

    it "passes output that uses the role instead of the name" do
      expect(described_class.clean?("People are chosen by ballot. That the treasurer's term follows the bylaws.", input)).to be(true)
    end

    it "does not flag a surname that is also an ordinary word in the text" do
      input = "Dana Green wants more green space by the hall."
      expect(described_class.found_in("That the co-op adds green space. Green areas help.", input)).to be_empty
      expect(described_class.found_in("That Dana Green's plan is adopted.", input)).to eq([ "Dana Green" ])
    end

    it "passes when the input names nobody" do
      expect(described_class.clean?("That the Elm Street garden opens on Saturdays.", "Open the Elm Street garden on Saturdays.")).to be(true)
    end
  end
end
