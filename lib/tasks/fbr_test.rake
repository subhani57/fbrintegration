# frozen_string_literal: true

namespace :fbr do
  desc 'Run sandbox scenario tests for a taxpayer (email required)'
  task :test_scenarios, [:email] => :environment do |_t, args|
    email = args[:email] || ENV['FBR_TEST_USER_EMAIL']
    user = User.taxpayers.find_by(email: email)
    unless user
      puts "Taxpayer not found: #{email}"
      exit 1
    end

    results = Fbr::SandboxTestInvoicesService.new(user).call
    results.each do |r|
      icon = r.success ? '✓' : (r.skipped? ? '↷' : '✗')
      puts "#{icon} #{r.scenario_id}: #{r.error_message || 'ok'}"
    end
  end

  desc 'Show recent FBR test invoices'
  task show_results: :environment do
    Invoice.where("test_data->>'sandbox_test' = 'true'").order(created_at: :desc).limit(20).each do |inv|
      puts "#{inv.scenario_id} #{inv.invoice_number} — #{inv.fbr_status || inv.status}"
    end
  end
end
