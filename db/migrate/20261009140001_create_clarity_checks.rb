class CreateClarityChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :clarity_checks, id: :uuid do |t|
      t.references :proposal, type: :uuid, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.text     :gemini_raw
      t.string   :failure_reason
      t.datetime :generated_at

      t.boolean :single_proposal, null: false, default: false
      t.boolean :votable,         null: false, default: false
      t.text    :verdict_line
      t.text    :rewritten_motion
      t.jsonb   :reader_questions, null: false, default: []
      t.jsonb   :suggested_edits,  null: false, default: []
      t.jsonb   :split_into,       null: false, default: []

      t.timestamps null: false
    end
    add_index :clarity_checks, :status
  end
end
