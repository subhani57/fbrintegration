namespace :admin do
  desc "Reset an admin user's password (ADMIN_EMAIL, ADMIN_PASSWORD env vars)"
  task reset_password: :environment do
    email = ENV.fetch("ADMIN_EMAIL", "admin@gmail.com")
    password = ENV["ADMIN_PASSWORD"].presence || SecureRandom.hex(8)

    user = User.find_by!(email: email)
    unless user.admin?
      abort "User #{email} is not an admin (role: #{user.role})."
    end

    user.update!(password: password, password_confirmation: password, approved: true)
    puts "Password reset for #{email}"
    puts "New password: #{password}" unless ENV["ADMIN_PASSWORD"].present?
  end
end
