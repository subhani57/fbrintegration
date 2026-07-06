# frozen_string_literal: true

class DefaultTaxpayersToProductionFbrEnvironment < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :preferred_fbr_environment, from: 'sandbox', to: 'production'

    execute <<~SQL.squish
      UPDATE users
      SET preferred_fbr_environment = 'production'
      WHERE role = 'taxpayer' AND preferred_fbr_environment = 'sandbox'
    SQL
  end

  def down
    change_column_default :users, :preferred_fbr_environment, from: 'production', to: 'sandbox'
  end
end
