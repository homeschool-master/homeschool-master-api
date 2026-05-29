class AddEmailChangeToTeachers < ActiveRecord::Migration[7.1]
  def change
    add_column :teachers, :pending_email, :string
    add_column :teachers, :email_change_token, :string
    add_column :teachers, :email_change_sent_at, :datetime
    add_index :teachers, :email_change_token, unique: true
  end
end
