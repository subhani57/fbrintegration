module Admin
  class BaseController < ApplicationController
    include RoleAuthorization

    layout 'admin'

    before_action :authenticate_user!
    before_action :ensure_admin!
  end
end
