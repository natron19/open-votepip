FactoryBot.define do
  factory :proposal do
    association :user
    title            { "Saturday hours for the tool library" }
    body             { "The tool library opens from 9am to noon every Saturday from April through October, staffed by two volunteers per shift." }
    problem          { "Most members work weekdays and can only borrow tools on weekends." }
    decider          { "whole_community" }
    deadline_or_cost { "Starts in April; no cost beyond volunteer time" }
  end
end
