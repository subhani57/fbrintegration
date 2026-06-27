# frozen_string_literal: true

if defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = false
  Bullet.bullet_logger = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
  Bullet.raise = false
end
