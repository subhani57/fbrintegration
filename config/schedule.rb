# config/schedule.rb
every :day, at: '2:00am' do
  runner 'FbrSyncJob.perform_later'
end

every 15.minutes do
  runner 'DashboardStatsJob.perform_later'
end

every :day, at: '3:00am' do
  runner 'CleanupLogsJob.perform_later'
end

every :month, at: 'start of the month at 6am' do
  runner 'MonthlyReportJob.perform_later'
end

every :day, at: '8:00am' do
  runner 'AdminAlertsJob.perform_later'
end