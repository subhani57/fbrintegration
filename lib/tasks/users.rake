# frozen_string_literal: true

namespace :users do
  desc "Clone a user account and related data (SOURCE_EMAIL, TARGET_EMAIL, optional TARGET_PASSWORD, REPLACE_TARGET=true)"
  task clone: :environment do
    source_email = ENV.fetch('SOURCE_EMAIL')
    target_email = ENV.fetch('TARGET_EMAIL')
    password = ENV['TARGET_PASSWORD']
    replace_target = ActiveModel::Type::Boolean.new.cast(ENV['REPLACE_TARGET'])

    result = Users::Clone.call(
      source_email: source_email,
      target_email: target_email,
      password: password,
      replace_target: replace_target
    )

    target = result[:target]
    summary = result[:summary]

    puts "Cloned #{source_email} -> #{target.email} (user ##{target.id})"
    puts "Login password: #{result[:password]}" unless ENV['TARGET_PASSWORD'].present?
    puts 'Summary:'
    summary.each do |key, count|
      puts "  #{key}: #{count}"
    end
  rescue Users::Clone::Error => e
    abort e.message
  end
end
