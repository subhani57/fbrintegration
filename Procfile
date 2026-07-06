release: bundle exec rails db:migrate && bundle exec rails fbr:reference_data:warm_hs_codes
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
