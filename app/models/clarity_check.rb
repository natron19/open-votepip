class ClarityCheck < ApplicationRecord
  belongs_to :proposal
  has_one :user, through: :proposal

  STATUSES = %w[pending completed failed].freeze

  validates :status, inclusion: { in: STATUSES }

  def completed? = status == "completed"
  def failed?    = status == "failed"

  # The draft was edited after this check ran.
  def stale?
    generated_at.present? && proposal.updated_at > generated_at
  end

  def to_markdown
    lines = []
    lines << "# Clarity check: #{proposal.title}"
    lines << ""
    lines << "_Generated #{generated_at&.strftime('%Y-%m-%d') || 'unknown'} by #{ENV.fetch('APP_NAME', 'VotePIP Demo')}. " \
             "AI-generated: a first read, not a ruling. It does not judge whether the idea is good._"
    lines << ""
    lines << "- **One proposal?** #{single_proposal ? 'Yes' : 'No'}"
    lines << "- **Can be voted up or down as written?** #{votable ? 'Yes' : 'No'}"
    lines << ""
    lines << verdict_line.to_s
    lines << ""
    if rewritten_motion.present?
      lines << "## Rewritten motion"
      lines << ""
      lines << "> #{rewritten_motion}"
      lines << ""
    end
    if split_into.any?
      lines << "## Split into #{split_into.size} proposals"
      lines << ""
      split_into.each_with_index do |part, i|
        lines << "#{i + 1}. **#{part['name']}**: #{part['motion']}"
      end
      lines << ""
    end
    if reader_questions.any?
      lines << "## A reader might still ask"
      lines << ""
      reader_questions.each { |q| lines << "- #{q}" }
      lines << ""
    end
    lines << "## Suggested edits"
    lines << ""
    suggested_edits.each { |e| lines << "- #{e}" }
    lines << ""
    lines << "## The draft"
    lines << ""
    lines << "**#{proposal.title}**"
    lines << ""
    lines << proposal.body
    lines << ""
    lines << "_Problem it solves:_ #{proposal.problem}"
    lines << ""
    lines << "_Who decides:_ #{proposal.decider_label}"
    lines << "_Deadline or cost:_ #{proposal.deadline_or_cost}" if proposal.deadline_or_cost.present?
    lines.join("\n") + "\n"
  end

  def markdown_filename
    slug = proposal.title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "").presence || "proposal"
    "#{slug}-clarity-check.md"
  end
end
