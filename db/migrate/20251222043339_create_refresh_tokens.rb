class CreateRefreshTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :refresh_tokens do |t|
      t.references :teacher, null: false, foreign_key: true
      t.string :token
      t.string :jti
      t.datetime :expires_at
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
