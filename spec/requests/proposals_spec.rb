require "rails_helper"

RSpec.describe "Proposals", type: :request do
  let(:user)     { create(:user) }
  let(:other)    { create(:user) }
  let(:proposal) { create(:proposal, user: user) }

  let(:valid_params) do
    { proposal: { title: "Bike rack by the hall", body: "Put a bike rack by the front door of the community hall.",
                  problem: "There is no place to lock bikes.", decider: "governing_body", deadline_or_cost: "" } }
  end

  context "when not signed in" do
    it "redirects every page to sign in" do
      get proposals_path
      expect(response).to redirect_to(sign_in_path)
      get dashboard_path
      expect(response).to redirect_to(sign_in_path)
      post proposals_path, params: valid_params
      expect(response).to redirect_to(sign_in_path)
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "shows the dashboard as My proposals with only the user's own proposals" do
      create(:proposal, user: user, title: "Mine to check")
      create(:proposal, user: other, title: "Someone else's draft")
      get dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My proposals", "Mine to check")
      expect(response.body).not_to include("Someone else&#39;s draft")
    end

    it "shows the latest verdict on the dashboard" do
      create(:clarity_check, :bundled, proposal: proposal)
      get proposals_path
      expect(response.body).to include("2 proposals bundled", "Not yet votable")
    end

    it "shows an empty state with no proposals" do
      get proposals_path
      expect(response.body).to include("Write your first proposal")
    end

    it "renders the new form with the labels the UI journey fills" do
      get new_proposal_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Title", "The proposal", "What problem does it solve?", "Who decides", "Deadline or cost")
    end

    it "creates a proposal and redirects to it" do
      expect { post proposals_path, params: valid_params }.to change(user.proposals, :count).by(1)
      expect(response).to redirect_to(proposal_path(Proposal.last))
    end

    it "re-renders the form with 422 on invalid input" do
      expect {
        post proposals_path, params: { proposal: valid_params[:proposal].merge(body: "short") }
      }.not_to change(Proposal, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "shows the proposal with the Check clarity button" do
      get proposal_path(proposal)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(proposal.title, "Check clarity")
    end

    it "updates a proposal" do
      patch proposal_path(proposal), params: { proposal: { title: "A clearer title" } }
      expect(response).to redirect_to(proposal_path(proposal))
      expect(proposal.reload.title).to eq("A clearer title")
    end

    it "rejects an invalid update with 422" do
      patch proposal_path(proposal), params: { proposal: { decider: "the_mayor" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "deletes a proposal" do
      proposal
      expect { delete proposal_path(proposal) }.to change(Proposal, :count).by(-1)
      expect(response).to redirect_to(proposals_path)
    end
  end

  # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
  context "when signed in as a different user" do
    before { sign_in_as(other) }

    it "cannot see, edit, update, or delete the proposal" do
      get proposal_path(proposal)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
      get edit_proposal_path(proposal)
      expect(response).to redirect_to(root_path)
      patch proposal_path(proposal), params: { proposal: { title: "Hijacked" } }
      expect(response).to redirect_to(root_path)
      expect { delete proposal_path(proposal) }.not_to change(Proposal, :count)
      expect(response).to redirect_to(root_path)
      expect(proposal.reload.title).not_to eq("Hijacked")
    end
  end
end
