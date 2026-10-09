require "rails_helper"

RSpec.describe ClarityCheck, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:clarity_check)).to be_valid
    end

    it "requires a proposal" do
      expect(build(:clarity_check, proposal: nil)).not_to be_valid
    end

    it "accepts every known status and rejects others" do
      ClarityCheck::STATUSES.each { |s| expect(build(:clarity_check, status: s)).to be_valid }
      expect(build(:clarity_check, status: "unknown")).not_to be_valid
    end

    it "lists the statuses" do
      expect(ClarityCheck::STATUSES).to eq(%w[pending completed failed])
    end
  end

  describe "associations" do
    it "has a user through its proposal" do
      check = create(:clarity_check)
      expect(check.user).to eq(check.proposal.user)
    end
  end

  describe "defaults" do
    it "starts pending with empty lists" do
      check = ClarityCheck.create!(proposal: create(:proposal))
      expect(check.status).to eq("pending")
      expect([ check.reader_questions, check.suggested_edits, check.split_into ]).to all(eq([]))
    end
  end

  describe "#stale?" do
    it "is true when the proposal changed after the check" do
      check = create(:clarity_check, :completed, generated_at: 1.hour.ago)
      check.proposal.update!(title: "A clearer title")
      expect(check.stale?).to be(true)
    end

    it "is false when the check is newer than the proposal" do
      check = create(:clarity_check, :completed, generated_at: 1.minute.from_now)
      expect(check.stale?).to be(false)
    end
  end

  describe "#to_markdown" do
    it "includes the verdict, the motion, the questions, the edits, and the draft" do
      check = create(:clarity_check, :completed)
      md = check.to_markdown
      expect(md).to include("# Clarity check: #{check.proposal.title}")
      expect(md).to include("**One proposal?** Yes")
      expect(md).to include("> #{check.rewritten_motion}")
      expect(md).to include(check.reader_questions.first)
      expect(md).to include(*check.suggested_edits)
      expect(md).to include(check.proposal.body)
      expect(md).not_to include("Split into")
    end

    it "lists the split motions for a bundled draft" do
      check = create(:clarity_check, :bundled)
      md = check.to_markdown
      expect(md).to include("## Split into 2 proposals")
      expect(md).to include("1. **Repaint the lobby**: That the co-op repaints the lobby before winter.")
      expect(md).not_to include("## Rewritten motion")
    end

    it "names the file after the proposal title" do
      check = create(:clarity_check, :completed)
      expect(check.markdown_filename).to eq("saturday-hours-for-the-tool-library-clarity-check.md")
    end
  end
end
