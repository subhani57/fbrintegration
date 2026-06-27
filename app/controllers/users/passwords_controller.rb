module Users
  class PasswordsController < Devise::PasswordsController
    layout 'auth'
  end
end
