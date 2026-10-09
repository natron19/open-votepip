require "rails_helper"

RSpec.describe Proposal, type: :model do
  describe "validations" do
    it "is valid with the factory attributes" do
      expect(build(:proposal)).to be_valid
    end

    it "requires a user" do
      expect(build(:proposal, user: nil)).not_to be_valid
    end

    it "requires a title of at most 120 characters" do
      expect(build(:proposal, title: "")).not_to be_valid
      expect(build(:proposal, title: "x" * 121)).not_to be_valid
    end

    it "requires a body of 20 to 3000 characters" do
      expect(build(:proposal, body: "Too short")).not_to be_valid
      expect(build(:proposal, body: "x" * 3001)).not_to be_valid
      expect(build(:proposal, body: "x" * 3000)).to be_valid
    end

    it "requires a problem of 10 to 1000 characters" do
      expect(build(:proposal, problem: "")).not_to be_valid
      expect(build(:proposal, problem: "short")).not_to be_valid
      expect(build(:proposal, problem: "x" * 1001)).not_to be_valid
    end

    it "accepts every known decider and rejects others" do
      Proposal::DECIDERS.each { |d| expect(build(:proposal, decider: d)).to be_valid }
      expect(build(:proposal, decider: "the_mayor")).not_to be_valid
      expect(build(:proposal, decider: nil)).not_to be_valid
    end

    it "allows a blank deadline_or_cost but caps it at 200 characters" do
      expect(build(:proposal, deadline_or_cost: nil)).to be_valid
      expect(build(:proposal, deadline_or_cost: "x" * 201)).not_to be_valid
    end
  end

  describe "constants" do
    it "lists the three deciders, each with a label and a prompt phrase" do
      expect(Proposal::DECIDERS).to eq(%w[whole_community governing_body delegate])
      expect(Proposal::DECIDER_LABELS.keys).to eq(Proposal::DECIDERS)
      expect(Proposal::DECIDER_PROMPTS.keys).to eq(Proposal::DECIDERS)
    end
  end

  describe "associations" do
    it "destroys its clarity checks" do
      proposal = create(:proposal)
      create(:clarity_check, :completed, proposal: proposal)
      expect { proposal.destroy }.to change(ClarityCheck, :count).by(-1)
    end

    it "returns the newest check as latest_clarity_check" do
      proposal = create(:proposal)
      create(:clarity_check, :completed, proposal: proposal, generated_at: 2.days.ago)
      newest = create(:clarity_check, :completed, proposal: proposal, generated_at: 1.hour.ago)
      expect(proposal.reload.latest_clarity_check).to eq(newest)
    end

    it "is destroyed with its user" do
      proposal = create(:proposal)
      expect { proposal.user.destroy }.to change(Proposal, :count).by(-1)
    end
  end

  describe "#ai_variables" do
    it "sends the draft fields and the decider phrase, and nothing about the author" do
      proposal = build(:proposal, decider: "delegate", deadline_or_cost: "")
      vars = proposal.ai_variables
      expect(vars.keys).to eq(%i[title body problem decider deadline_or_cost])
      expect(vars[:decider]).to eq("a delegate carries it to a wider body")
      expect(vars[:deadline_or_cost]).to eq("Not stated")
      expect(vars.values.join).not_to include(proposal.user.name, proposal.user.email)
    end
  end
end
