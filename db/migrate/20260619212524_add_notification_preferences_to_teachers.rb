class AddNotificationPreferencesToTeachers < ActiveRecord::Migration[7.1]
  def change
    add_column :teachers, :notify_account_updates, :boolean, default: true, null: false
    add_column :teachers, :notify_product_updates, :boolean, default: true, null: false
    add_column :teachers, :notify_homeschool_resources, :boolean, default: true, null: false
  end
end
