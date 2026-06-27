# db/seeds.rb
# Seed FBR Scenarios
FbrScenario.destroy_all

FbrScenario::SCENARIOS.each do |scenario_id, description|
  FbrScenario.create!(
    scenario_id: scenario_id,
    name: description,
    description: description,
    active: true
  )
end

puts "✅ Seeded #{FbrScenario.count} scenarios"

# Seed Business Mappings
BusinessScenarioMapping.destroy_all

# Sample mappings based on FBR documentation
mappings = [
  {
    business_nature: 'Manufacturer',
    sector: 'All Other Sectors',
    scenario_ids: ['SN001', 'SN002', 'SN005', 'SN006', 'SN007', 'SN015', 'SN016', 'SN017', 'SN021', 'SN022', 'SN024']
  },
  {
    business_nature: 'Retailer',
    sector: 'All Other Sectors',
    scenario_ids: ['SN001', 'SN002', 'SN005', 'SN006', 'SN007', 'SN015', 'SN016', 'SN017', 'SN021', 'SN022', 'SN024', 'SN026', 'SN027', 'SN028', 'SN008']
  },
  {
    business_nature: 'Service Provider',
    sector: 'Services',
    scenario_ids: ['SN018', 'SN019']
  }
]

mappings.each do |mapping|
  BusinessScenarioMapping.create!(mapping)
end

puts "✅ Seeded #{BusinessScenarioMapping.count} business mappings"

admin_email = ENV.fetch("ADMIN_EMAIL", "admin@gmail.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "Admin123456")

admin = User.find_or_initialize_by(email: admin_email)
admin.assign_attributes(
  password: admin_password,
  password_confirmation: admin_password,
  role: "admin",
  approved: true
)
admin.save!
puts "✅ Admin user ready: #{admin_email} (password from ADMIN_PASSWORD env or default Admin123456)"