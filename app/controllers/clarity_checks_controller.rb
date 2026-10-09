class ClarityChecksController < ApplicationController
  TEMPLATE = "votepip_motion_v1".freeze

  before_action :set_proposal

  rate_limit to: 10, within: 1.minute, only: :create, by: -> { current_user.id }

  # shared/_ai_error's "Try again" button is a GET to the current path; send it back to the proposal.
  def index
    redirect_to proposal_path(@proposal)
  end

  def show
    @clarity_check = @proposal.clarity_checks.find(params[:id])
  end

  def create
    raw = GeminiService.generate(template: TEMPLATE, variables: @proposal.ai_variables)

    @clarity_check = @proposal.clarity_checks.create!(
      status:       "pending",
      gemini_raw:   raw,
      generated_at: Time.current
    )

    result = parse_clarity!(raw)
    @clarity_check.update!(result.merge(status: "completed"))
    redirect_to proposal_clarity_check_path(@proposal, @clarity_check)

  rescue ParseError => e
    @clarity_check.update!(status: "failed", failure_reason: e.message.truncate(250), gemini_raw: e.raw)
    redirect_to proposal_clarity_check_path(@proposal, @clarity_check)

  rescue GeminiService::BudgetExceededError
    render "shared/ai_error_page", locals: { error_type: :budget_exceeded }, status: :unprocessable_entity

  rescue GeminiService::GatekeeperError
    render "shared/ai_error_page", locals: { error_type: :gatekeeper_blocked }, status: :unprocessable_entity

  rescue GeminiService::OutputGuardError
    render "shared/ai_error_page", locals: { error_type: :output_blocked }, status: :unprocessable_entity

  rescue GeminiService::TimeoutError
    render "shared/ai_error_page", locals: { error_type: :timeout }, status: :unprocessable_entity

  rescue GeminiService::GeminiError
    render "shared/ai_error_page", locals: { error_type: :error }, status: :unprocessable_entity
  end

  private

  def set_proposal
    @proposal = current_user.proposals.find(params[:proposal_id])
  end

  ParseError = Class.new(StandardError) do
    attr_reader :raw
    def initialize(msg, raw:)
      super(msg)
      @raw = raw
    end
  end

  # Validates the votepip_motion_v1 JSON and returns the ClarityCheck attributes.
  # Hard rule enforced here, not trusted to the model: the output never repeats a person name from the draft.
  def parse_clarity!(raw)
    fail_parse = ->(msg) { raise ParseError.new(msg, raw: raw) }

    stripped = raw.to_s.strip.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    parsed   = JSON.parse(stripped)
    fail_parse.("Expected a JSON object") unless parsed.is_a?(Hash)

    single  = parsed["single_proposal"]
    votable = parsed["votable"]
    fail_parse.("single_proposal must be true or false") unless [ true, false ].include?(single)
    fail_parse.("votable must be true or false") unless [ true, false ].include?(votable)

    verdict = parsed["verdict_line"]
    fail_parse.("verdict_line is missing") unless verdict.is_a?(String) && verdict.strip.present?

    motion = parsed["rewritten_motion"]
    fail_parse.("rewritten_motion must be a string") unless motion.is_a?(String)
    fail_parse.("rewritten_motion is empty for a single proposal") if single && motion.strip.empty?

    questions = string_list(parsed["reader_questions"])
    fail_parse.("Expected 0-4 reader_questions") unless questions && questions.size <= 4

    edits = string_list(parsed["suggested_edits"])
    fail_parse.("Expected exactly 2 suggested_edits, got #{Array(parsed['suggested_edits']).size}") unless edits&.size == 2

    split = parsed.fetch("split_into", [])
    fail_parse.("split_into must be a list") unless split.is_a?(Array)
    if single
      fail_parse.("split_into must be empty for a single proposal") if split.any?
    else
      unless split.size.between?(2, 4) && split.all? { |p| p.is_a?(Hash) && p["name"].to_s.strip.present? && p["motion"].to_s.strip.present? }
        fail_parse.("Expected 2-4 split_into entries with a name and a motion")
      end
    end
    split = split.map { |p| { "name" => p["name"].strip, "motion" => p["motion"].strip } }

    result = {
      single_proposal:  single,
      votable:          votable,
      verdict_line:     verdict.strip,
      rewritten_motion: motion.strip,
      reader_questions: questions,
      suggested_edits:  edits,
      split_into:       split
    }

    output_text = [ verdict, motion, *questions, *edits, *split.flat_map(&:values) ].join("\n")
    if PersonNameCheck.found_in(output_text, @proposal.input_text).any?
      fail_parse.("The response named a person from your draft, so it was not shown")
    end

    result
  rescue JSON::ParserError => e
    raise ParseError.new("JSON parse failed: #{e.message.truncate(120)}", raw: raw)
  end

  # An array of non-blank strings, stripped; nil when the value is anything else.
  def string_list(value)
    return nil unless value.is_a?(Array) && value.all? { |v| v.is_a?(String) && v.strip.present? }
    value.map(&:strip)
  end
end
