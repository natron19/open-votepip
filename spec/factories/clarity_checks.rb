FactoryBot.define do
  factory :clarity_check do
    association :proposal
    status       { "pending" }
    generated_at { nil }
    gemini_raw   { nil }

    trait :completed do
      status           { "completed" }
      generated_at     { Time.current }
      gemini_raw       { "{}" }
      single_proposal  { true }
      votable          { true }
      verdict_line     { "This is one proposal, and members can answer it yes or no." }
      rewritten_motion { "That the tool library opens from 9am to noon every Saturday from April through October." }
      reader_questions { [ "Who covers a shift when a volunteer cannot come?" ] }
      suggested_edits  { [ "Say whether the hours start in the first week of April.", "Name who keeps the volunteer list." ] }
      split_into       { [] }
    end

    trait :bundled do
      completed
      single_proposal  { false }
      votable          { false }
      verdict_line     { "This is two proposals: repainting the lobby and a bike rule." }
      rewritten_motion { "" }
      split_into do
        [
          { "name" => "Repaint the lobby", "motion" => "That the co-op repaints the lobby before winter." },
          { "name" => "No bikes in the hallway", "motion" => "That bikes may not be left in the hallway." }
        ]
      end
    end

    trait :failed do
      status         { "failed" }
      generated_at   { Time.current }
      gemini_raw     { "malformed response" }
      failure_reason { "JSON parse failed: unexpected token" }
    end
  end
end
