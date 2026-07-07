# frozen_string_literal: true

# Long-lived cookie sessions so users stay signed in and each browser keeps its
# own session (logging in elsewhere does not sign out other devices).
Rails.application.config.session_store :cookie_store,
  key: "_#{Rails.application.class.module_parent_name.underscore}_session",
  expire_after: 20.years,
  secure: Rails.env.production?,
  same_site: :lax
