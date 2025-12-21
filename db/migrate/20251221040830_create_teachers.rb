class CreateTeachers < ActiveRecord::Migration[7.1]
  def change
    create_table :teachers, id: :uuid do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :nickname
      t.string :email, null: false
      t.string :phone
      t.boolean :newsletter_subscribed, default: false
      t.string :password_digest, null: false
      t.string :profile_image_url
      t.datetime :email_verified_at
      t.string :email_verification_token
      t.string :password_reset_token
      t.datetime :password_reset_sent_at
      t.boolean :is_active, default: true

      t.timestamps
    end
    
    add_index :teachers, :email, unique: true
    add_index :teachers, :email_verification_token, unique: true
    add_index :teachers, :password_reset_token, unique: true
    add_index :teachers, :is_active
  end
end
