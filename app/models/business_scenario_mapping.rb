class BusinessScenarioMapping < ApplicationRecord
  validates :business_nature, :sector, presence: true
  validates :business_nature, uniqueness: { scope: :sector }
end
