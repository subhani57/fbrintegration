module Users
  class SessionsController < Devise::SessionsController
    layout 'auth'
  end
end
