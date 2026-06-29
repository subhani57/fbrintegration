# db/seeds.rb
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

[
  { name: 'Basic', slug: 'basic', monthly_fee: 1000, invoice_limit: nil, features: { 'api_access' => true, 'bulk_export' => true } },
  { name: 'Pro', slug: 'pro', monthly_fee: 2500, invoice_limit: 500, features: { 'api_access' => true, 'bulk_export' => true, 'recurring' => true, 'connectors' => true } },
  { name: 'Enterprise', slug: 'enterprise', monthly_fee: 5000, invoice_limit: nil, features: { 'api_access' => true, 'bulk_export' => true, 'recurring' => true, 'connectors' => true, 'accountant' => true, 'priority_support' => true } }
].each do |attrs|
  plan = SubscriptionPlan.find_or_initialize_by(slug: attrs[:slug])
  plan.assign_attributes(attrs)
  plan.save!
end
puts "✅ Subscription plans seeded"

default_plan = SubscriptionPlan.default
if default_plan
  User.taxpayers.where(subscription_plan_id: nil).update_all(subscription_plan_id: default_plan.id)
  puts "✅ Default plan assigned to taxpayers without a plan"
end
