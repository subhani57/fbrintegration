# frozen_string_literal: true

require 'rails_helper'

RSpec.describe System::HealthCheck do
  describe '.redis_status' do
    it 'returns ok when Redis responds to PING' do
      client = instance_double(RedisClient, call: 'PONG')
      allow(described_class).to receive(:redis_client).and_return(client)

      expect(described_class.redis_status).to eq(ok: true, ping: 'PONG')
    end

    it 'returns error details when Redis is unreachable' do
      allow(described_class).to receive(:redis_client).and_raise(RedisClient::CannotConnectError, 'connection refused')

      expect(described_class.redis_status).to eq(ok: false, error: 'connection refused')
    end
  end
end
