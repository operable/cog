defmodule Cog.Adapters.HipChat.Config do
  use Cog.Adapters.Config,
    key: Cog.Adapters.HipChat,
    schema: [xmpp:
               [{:jid, [:required], :xmpp_jid},
                {:password, [:required], :xmpp_password},
                {:nickname, [:required], :xmpp_nickname},
                {:resource, [:required], :xmpp_resource},
                {:rooms, [:required, :split], :xmpp_rooms},
                {:handlers, :hardcode, [{Cog.Adapters.HipChat.XMPPHandler, %{}}]}],
             api:
               [{:token, [:required], :api_token},
                {:mention_name, [:required]}]]
end
