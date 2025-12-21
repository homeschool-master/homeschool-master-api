class CreateTeachers < ActiveRecord::Migration[7.1]
  def change
    create_table :teachers do |t|
      t.string :first_name
      t.string :last_name
      t.string :nickname
      t.string :email
      t.string :phone
      t.boolean :newsletter_subscribed
      t.string :password_digest
      t.string :profile_image_url
      t.datetime :email_verified_at
      t.string :email_verification_token
      t.string :password_reset_token
      t.datetime :password_reset_sent_at
      t.boolean :is_active

      t.timestamps
    end
  end
end
