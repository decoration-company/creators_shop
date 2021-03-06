require 'base64'
require 'openssl'
require 'jwt/decode'
require 'jwt/error'
require 'jwt/json'

# JSON Web Token implementation
#
# Should be up to date with the latest spec:
# https://tools.ietf.org/html/rfc7519#section-4.1.5
module JWT
  extend JWT::Json

  NAMED_CURVES = {
    'prime256v1' => 'ES256',
    'secp384r1' => 'ES384',
    'secp521r1' => 'ES512'
  }

  module_function

  def sign(algorithm, msg, key)
    if %w(HS256 HS384 HS512).include?(algorithm)
      sign_hmac(algorithm, msg, key)
    elsif %w(RS256 RS384 RS512).include?(algorithm)
      sign_rsa(algorithm, msg, key)
    elsif %w(ES256 ES384 ES512).include?(algorithm)
      sign_ecdsa(algorithm, msg, key)
    else
      fail NotImplementedError, 'Unsupported signing method'
    end
  end

  def sign_rsa(algorithm, msg, private_key)
    private_key.sign(OpenSSL::Digest.new(algorithm.sub('RS', 'sha')), msg)
  end

  def sign_ecdsa(algorithm, msg, private_key)
    key_algorithm = NAMED_CURVES[private_key.group.curve_name]
    if algorithm != key_algorithm
      fail IncorrectAlgorithm, "payload algorithm is #{algorithm} but #{key_algorithm} signing key was provided"
    end

    digest = OpenSSL::Digest.new(algorithm.sub('ES', 'sha'))
    asn1_to_raw(private_key.dsa_sign_asn1(digest.digest(msg)), private_key)
  end

  def verify_rsa(algorithm, public_key, signing_input, signature)
    public_key.verify(OpenSSL::Digest.new(algorithm.sub('RS', 'sha')), signature, signing_input)
  end

  def verify_ecdsa(algorithm, public_key, signing_input, signature)
    key_algorithm = NAMED_CURVES[public_key.group.curve_name]
    if algorithm != key_algorithm
      fail IncorrectAlgorithm, "payload algorithm is #{algorithm} but #{key_algorithm} verification key was provided"
    end

    digest = OpenSSL::Digest.new(algorithm.sub('ES', 'sha'))
    public_key.dsa_verify_asn1(digest.digest(signing_input), raw_to_asn1(signature, public_key))
  end

  def sign_hmac(algorithm, msg, key)
    OpenSSL::HMAC.digest(OpenSSL::Digest.new(algorithm.sub('HS', 'sha')), key, msg)
  end

  def base64url_encode(str)
    Base64.encode64(str).tr('+/', '-_').gsub(/[\n=]/, '')
  end

  def encoded_header(algorithm = 'HS256', header_fields = {})
    header = { 'typ' => 'JWT', 'alg' => algorithm }.merge(header_fields)
    base64url_encode(encode_json(header))
  end

  def encoded_payload(payload)
    base64url_encode(encode_json(payload))
  end

  def encoded_signature(signing_input, key, algorithm)
    if algorithm == 'none'
      ''
    else
      signature = sign(algorithm, signing_input, key)
      base64url_encode(signature)
    end
  end

  def encode(payload, key, algorithm = 'HS256', header_fields = {})
    algorithm ||= 'none'
    segments = []
    segments << encoded_header(algorithm, header_fields)
    segments << encoded_payload(payload)
    segments << encoded_signature(segments.join('.'), key, algorithm)
    segments.join('.')
  end

  def decode(jwt, key = nil, verify = true, custom_options = {}, &keyfinder)
    fail(JWT::DecodeError, 'Nil JSON web token') unless jwt

    options = {
      verify_expiration: true,
      verify_not_before: true,
      verify_iss: false,
      verify_iat: false,
      verify_jti: false,
      verify_aud: false,
      verify_sub: false,
      leeway: 0
    }

    merged_options = options.merge(custom_options)

    decoder = Decode.new jwt, key, verify, merged_options, &keyfinder
    header, payload, signature, signing_input = decoder.decode_segments
    decoder.verify

    fail(JWT::DecodeError, 'Not enough or too many segments') unless header && payload

    if verify
      algo, key = signature_algorithm_and_key(header, key, &keyfinder)
      if merged_options[:algorithm] && algo != merged_options[:algorithm]
        fail JWT::IncorrectAlgorithm, 'Expected a different algorithm'
      end
      verify_signature(algo, key, signing_input, signature)
    end

    [payload, header]
  end

  def signature_algorithm_and_key(header, key, &keyfinder)
    key = keyfinder.call(header) if keyfinder
    [header['alg'], key]
  end

  def verify_signature(algo, key, signing_input, signature)
    if %w(HS256 HS384 HS512).include?(algo)
      fail(JWT::VerificationError, 'Signature verification raised') unless secure_compare(signature, sign_hmac(algo, signing_input, key))
    elsif %w(RS256 RS384 RS512).include?(algo)
      fail(JWT::VerificationError, 'Signature verification raised') unless verify_rsa(algo, key, signing_input, signature)
    elsif %w(ES256 ES384 ES512).include?(algo)
      fail(JWT::VerificationError, 'Signature verification raised') unless verify_ecdsa(algo, key, signing_input, signature)
    else
      fail JWT::VerificationError, 'Algorithm not supported'
    end
  rescue OpenSSL::PKey::PKeyError
    raise JWT::VerificationError, 'Signature verification raised'
  ensure
    OpenSSL.errors.clear
  end

  # From devise
  # constant-time comparison algorithm to prevent timing attacks
  def secure_compare(a, b)
    return false if a.nil? || b.nil? || a.empty? || b.empty? || a.bytesize != b.bytesize
    l = a.unpack "C#{a.bytesize}"

    res = 0
    b.each_byte { |byte| res |= byte ^ l.shift }
    res == 0
  end

  def raw_to_asn1(signature, private_key)
    byte_size = (private_key.group.degree + 7) / 8
    r = signature[0..(byte_size - 1)]
    s = signature[byte_size..-1]
    OpenSSL::ASN1::Sequence.new([r, s].map { |int| OpenSSL::ASN1::Integer.new(OpenSSL::BN.new(int, 2)) }).to_der
  end

  def asn1_to_raw(signature, public_key)
    byte_size = (public_key.group.degree + 7) / 8
    OpenSSL::ASN1.decode(signature).value.map { |value| value.value.to_s(2).rjust(byte_size, "\x00") }.join
  end

  def base64url_decode(str)
    Decode.base64url_decode(str)
  end
end
