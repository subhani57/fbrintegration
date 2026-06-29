# frozen_string_literal: true

module BuyerVerifications
  class CacheService
    def initialize(user)
      @user = user
    end

    def verify(ntn)
      cached = BuyerVerificationCache.fresh.for_ntn(ntn).where(user: @user).order(verified_on: :desc).first
      return cached.response_data.symbolize_keys if cached

      result = Fbr::BuyerVerificationService.new(@user).verify(ntn)
      BuyerVerificationCache.store!(user: @user, ntn: ntn, result: result) if result[:success]
      result
    end
  end
end
