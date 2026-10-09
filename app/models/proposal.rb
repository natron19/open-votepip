class Proposal < ApplicationRecord
  belongs_to :user
  has_many :clarity_checks, dependent: :destroy
  has_one :latest_clarity_check,
          -> { order(generated_at: :desc, created_at: :desc) },
          class_name: "ClarityCheck"

  DECIDERS = %w[whole_community governing_body delegate].freeze

  # Form label, and the phrase the AI template receives as {{decider}}.
  DECIDER_LABELS = {
    "whole_community" => "The whole community votes on it",
    "governing_body"  => "The governing body decides it",
    "delegate"        => "A delegate carries it to a wider body"
  }.freeze

  DECIDER_PROMPTS = {
    "whole_community" => "the whole community votes on it directly",
    "governing_body"  => "the governing body decides it",
    "delegate"        => "a delegate carries it to a wider body"
  }.freeze

  validates :title,            presence: true, length: { maximum: 120 }
  validates :body,             presence: true, length: { in: 20..3000 }
  validates :problem,          presence: true, length: { in: 10..1000 }
  validates :decider,          presence: true, inclusion: { in: DECIDERS }
  validates :deadline_or_cost, length: { maximum: 200 }

  def decider_label
    DECIDER_LABELS.fetch(decider, decider.to_s.humanize)
  end

  # Variables for the votepip_motion_v1 template. Nothing about the author is sent.
  def ai_variables
    {
      title:            title,
      body:             body,
      problem:          problem,
      decider:          DECIDER_PROMPTS.fetch(decider),
      deadline_or_cost: deadline_or_cost.presence || "Not stated"
    }
  end

  # The text the PersonNameCheck reads for names the output must not repeat.
  def input_text
    [ title, body, problem, deadline_or_cost ].compact.join("\n")
  end
end
