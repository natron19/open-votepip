class CreateProposals < ActiveRecord::Migration[8.1]
  def change
    create_table :proposals, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :title,            null: false
      t.text   :body,             null: false
      t.text   :problem,          null: false
      t.string :decider,          null: false
      t.string :deadline_or_cost

      t.timestamps null: false
    end
  end
end
