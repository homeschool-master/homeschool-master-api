class CreateRefreshTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :refresh_tokens, id: :uuid do |t|
      t.references :teacher, null: false, foreign_key: true, type: :uuid
      t.string :token, null: false
      t.string :jti, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end
    
    add_index :refresh_tokens, :token, unique: true
    add_index :refresh_tokens, :jti, unique: true
    add_index :refresh_tokens, :expires_at
  end
end
