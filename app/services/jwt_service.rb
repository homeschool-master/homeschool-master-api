# frozen_string_literal: true

class JwtService
  ALGORITHM = 'HS256'

  class << self
    def encode(payload, exp: nil)
      payload[:exp] = exp || access_token_expiry
      payload[:iat] = Time.now.to_i

      JWT.encode(payload, secret_key, ALGORITHM)
    end

    def encode_refresh_token(teacher_id)
      payload = {
        teacher_id: teacher_id,
        type: 'refresh',
        exp: refresh_token_expiry,
        iat: Time.now.to_i,
        jti: SecureRandom.uuid
      }

      JWT.encode(payload, secret_key, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, secret_key, true, { algorithm: ALGORITHM })
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature, JWT::DecodeError
      nil
    end

    def decode_refresh_token(token)
      decoded = decode(token)
      return nil unless decoded
      return nil unless decoded[:type] == 'refresh'

      decoded
    end

    private

    def secret_key
      ENV.fetch('JWT_SECRET_KEY') { Rails.application.credentials.secret_key_base }
    end

    def access_token_expiry
      Time.now.to_i + ENV.fetch('JWT_ACCESS_TOKEN_EXPIRY', 3600).to_i
    end

    def refresh_token_expiry
      Time.now.to_i + ENV.fetch('JWT_REFRESH_TOKEN_EXPIRY', 2_592_000).to_i
    end
  end
end
