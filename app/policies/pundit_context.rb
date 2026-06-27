# frozen_string_literal: true

class PunditContext
  attr_reader :user, :params

  def initialize(user, params = {})
    @user = user
    @params = params
  end
end
