defprotocol Carrier.Signature do

  @doc "Signs a JSON object using `Carrier.Credentials`"
  def sign(creds, obj)

  @doc "Verify JSON object signature"
  def verify(creds, obj)

end
