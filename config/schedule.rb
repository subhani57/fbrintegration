# config/schedule.rb
# Install with: whenever --update-crontab
# Jobs run synchronously in the cron process (no Sidekiq worker required).

every :day, at: '2:00am' do
  runner 'FbrSyncJob.perform_now'
end

every 15.minutes do
  runner 'DashboardStatsJob.perform_now'
end

every :day, at: '3:00am' do
  runner 'CleanupLogsJob.perform_now'
end

every :month, at: 'start of the month at 6am' do
  runner 'MonthlyReportJob.perform_now'
end

every :day, at: '8:00am' do
  runner 'AdminAlertsJob.perform_now'
end

every :day, at: '9:00am' do
  runner 'SubscriptionReminderJob.perform_now'
end

every :day, at: '6:00am' do
  runner 'RecurringInvoiceJob.perform_now'
end
