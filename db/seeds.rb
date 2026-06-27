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
