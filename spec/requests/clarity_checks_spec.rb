require "rails_helper"

RSpec.describe "ClarityChecks", type: :request do
  let(:user)     { create(:user) }
  let(:other)    { create(:user) }
  let(:proposal) { create(:proposal, user: user) }

  let(:single_result) do
    {
      "single_proposal"  => true,
      "votable"          => true,
      "verdict_line"     => "This is one proposal, and members can answer it yes or no.",
      "rewritten_motion" => "That the tool library opens from 9am to noon every Saturday from April through October.",
      "reader_questions" => [ "Who covers a shift when a volunteer cannot come?" ],
      "suggested_edits"  => [ "Say whether the hours start in the first week of April.", "Name who keeps the volunteer list." ],
      "split_into"       => []
    }
  end

  let(:bundled_result) do
    single_result.merge(
      "single_proposal"  => false,
      "votable"          => false,
      "verdict_line"     => "This is two proposals: Saturday hours and a new tool budget.",
      "rewritten_motion" => "",
      "split_into"       => [
        { "name" => "Saturday hours", "motion" => "That the tool library opens on Saturday mornings." },
        { "name" => "Tool budget",    "motion" => "That the association buys two new ladders." }
      ]
    )
  end

  def run_check
    post proposal_clarity_checks_path(proposal)
  end

  describe "POST /proposals/:proposal_id/checks" do
    context "when not signed in" do
      it "redirects to sign in" do
        run_check
        expect(response).to redirect_to(sign_in_path)
      end
    end

    context "when signed in as the owner with a valid response" do
      before do
        sign_in_as(user)
        gemini_returns(single_result.to_json)
      end

      it "calls GeminiService with the template and the draft's variables" do
        expect(GeminiService).to receive(:generate).with(
          template:  "votepip_motion_v1",
          variables: {
            title:            proposal.title,
            body:             proposal.body,
            problem:          proposal.problem,
            decider:          "the whole community votes on it directly",
            deadline_or_cost: proposal.deadline_or_cost
          }
        ).and_return(single_result.to_json)
        run_check
      end

      it "creates a completed check with the parsed fields and the raw response" do
        expect { run_check }.to change(ClarityCheck, :count).by(1)
        check = ClarityCheck.last
        expect(check.status).to eq("completed")
        expect(check.gemini_raw).to eq(single_result.to_json)
        expect(check.single_proposal).to be(true)
        expect(check.rewritten_motion).to eq(single_result["rewritten_motion"])
        expect(check.suggested_edits.size).to eq(2)
        expect(check.generated_at).to be_present
      end

      it "redirects to the result page" do
        run_check
        expect(response).to redirect_to(proposal_clarity_check_path(proposal, ClarityCheck.last))
      end

      it "accepts a response wrapped in a ```json fence" do
        gemini_returns("```json\n#{single_result.to_json}\n```")
        run_check
        expect(ClarityCheck.last.status).to eq("completed")
      end

      it "accepts a single proposal without a split_into key" do
        gemini_returns(single_result.except("split_into").to_json)
        run_check
        expect(ClarityCheck.last.status).to eq("completed")
      end

      it "stores split_into for a bundled draft" do
        gemini_returns(bundled_result.to_json)
        run_check
        check = ClarityCheck.last
        expect(check.status).to eq("completed")
        expect(check.split_into.map { |p| p["name"] }).to eq([ "Saturday hours", "Tool budget" ])
      end
    end

    context "when the response cannot be used" do
      before { sign_in_as(user) }

      {
        "is not JSON"                                => "this is not json at all",
        "is a JSON array"                            => "[1, 2]",
        "has a string instead of a boolean"          => :string_boolean,
        "has one suggested edit"                     => :one_edit,
        "has five reader questions"                  => :five_questions,
        "has an empty motion for a single proposal"  => :empty_motion,
        "splits a single proposal"                   => :split_single,
        "has one split for a bundled draft"          => :one_split,
        "has a split without a motion"               => :split_no_motion
      }.each do |description, raw|
        it "marks the check failed and keeps the raw text when the response #{description}" do
          text = case raw
          when :string_boolean  then single_result.merge("votable" => "yes").to_json
          when :one_edit        then single_result.merge("suggested_edits" => [ "Only one." ]).to_json
          when :five_questions  then single_result.merge("reader_questions" => Array.new(5) { |i| "Q#{i}?" }).to_json
          when :empty_motion    then single_result.merge("rewritten_motion" => " ").to_json
          when :split_single    then single_result.merge("split_into" => bundled_result["split_into"]).to_json
          when :one_split       then bundled_result.merge("split_into" => bundled_result["split_into"].first(1)).to_json
          when :split_no_motion then bundled_result.merge("split_into" => [ { "name" => "A" }, { "name" => "B", "motion" => "That b." } ]).to_json
          else raw
          end
          gemini_returns(text)

          expect { run_check }.to change(ClarityCheck, :count).by(1)
          check = ClarityCheck.last
          expect(check.status).to eq("failed")
          expect(check.gemini_raw).to eq(text)
          expect(check.failure_reason).to be_present
          expect(response).to redirect_to(proposal_clarity_check_path(proposal, check))
        end
      end

      it "fails a response that repeats a person named in the draft (PersonNameCheck)" do
        proposal.update!(body: "This proposal thanks Dana Whitlock and keeps her as treasurer for another three years.")
        gemini_returns(single_result.merge("rewritten_motion" => "That Dana Whitlock stays treasurer for three more years.").to_json)

        run_check
        check = ClarityCheck.last
        expect(check.status).to eq("failed")
        expect(check.failure_reason).to include("named a person")

        follow_redirect!
        expect(response.body).to include("named a person from your draft", "Retry", "Dana Whitlock stays treasurer")
        expect(response.body).not_to include("Download .md")
      end

      it "completes when the draft names a person and the output uses the role" do
        proposal.update!(body: "This proposal thanks Dana Whitlock and keeps her as treasurer for another three years.")
        gemini_returns(single_result.merge("rewritten_motion" => "That the treasurer serves three more years.").to_json)
        run_check
        expect(ClarityCheck.last.status).to eq("completed")
      end
    end

    context "when GeminiService raises" do
      before { sign_in_as(user) }

      {
        GeminiService::BudgetExceededError => "daily AI request limit",
        GeminiService::GatekeeperError     => "couldn't be processed",
        GeminiService::OutputGuardError    => "didn't pass our safety checks",
        GeminiService::TimeoutError        => "took too long",
        GeminiService::GeminiError         => "An unexpected error occurred"
      }.each do |error_class, message|
        it "renders the #{error_class.name.demodulize} message with 422 and creates no check" do
          gemini_raises(error_class)
          expect { run_check }.not_to change(ClarityCheck, :count)
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include(message)
        end
      end
    end

    # open-base's ApplicationController answers RecordNotFound with a redirect to root and an alert.
    context "when signed in as a different user" do
      it "does not find the proposal, calls no AI, and creates no check" do
        sign_in_as(other)
        expect(GeminiService).not_to receive(:generate)
        expect { run_check }.not_to change(ClarityCheck, :count)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("That record could not be found.")
      end
    end

    context "rate limit" do
      it "refuses the 11th check within a minute" do
        sign_in_as(user)
        gemini_returns(single_result.to_json)
        10.times { run_check }
        expect(response).to have_http_status(:redirect)
        run_check
        expect(response).to have_http_status(:too_many_requests)
        expect(ClarityCheck.count).to eq(10)
      end
    end
  end

  describe "GET /proposals/:proposal_id/checks (the error page's Try again)" do
    it "redirects to the proposal" do
      sign_in_as(user)
      get proposal_clarity_checks_path(proposal)
      expect(response).to redirect_to(proposal_path(proposal))
    end
  end

  describe "GET /proposals/:proposal_id/checks/:id" do
    context "for a completed single proposal" do
      let(:check) { create(:clarity_check, :completed, proposal: proposal, generated_at: 1.minute.from_now) }

      it "shows the verdict, motion, questions, edits, actions, and disclaimer" do
        sign_in_as(user)
        get proposal_clarity_check_path(proposal, check)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(
          "One proposal", "Votable as written", check.verdict_line, "Rewritten motion", check.rewritten_motion,
          "A reader might still ask", check.reader_questions.first, "Suggested edits", check.suggested_edits.last,
          "Download .md", "Show raw response", "AI-generated."
        )
        expect(response.body).not_to include("Split into", "Your draft has changed")
      end
    end

    context "for a bundled draft" do
      it "shows the split-into motions" do
        check = create(:clarity_check, :bundled, proposal: proposal)
        sign_in_as(user)
        get proposal_clarity_check_path(proposal, check)
        expect(response.body).to include("Split into 2 proposals", "Repaint the lobby", "That bikes may not be left in the hallway.")
        expect(response.body).not_to include("Rewritten motion")
      end
    end

    context "for a failed check" do
      it "shows the reason, Retry, and the raw response, with no download" do
        check = create(:clarity_check, :failed, proposal: proposal)
        sign_in_as(user)
        get proposal_clarity_check_path(proposal, check)
        expect(response.body).to include("could not be used", check.failure_reason, "Retry", "malformed response")
        expect(response.body).not_to include("Download .md")
      end
    end

    it "warns when the draft changed after the check" do
      check = create(:clarity_check, :completed, proposal: proposal, generated_at: 1.hour.ago)
      proposal.update!(title: "A newer title")
      sign_in_as(user)
      get proposal_clarity_check_path(proposal, check)
      expect(response.body).to include("Your draft has changed since this check")
    end

    it "does not show another user's check" do
      check = create(:clarity_check, :completed, proposal: proposal)
      sign_in_as(other)
      get proposal_clarity_check_path(proposal, check)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That record could not be found.")
    end

    it "does not show a check under a different proposal of the same user" do
      check = create(:clarity_check, :completed, proposal: proposal)
      sign_in_as(user)
      get proposal_clarity_check_path(create(:proposal, user: user), check)
      expect(response).to redirect_to(root_path)
    end
  end
end
