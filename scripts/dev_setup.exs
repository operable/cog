import Cog.Support.ModelUtilities
alias Cog.Repo
use Cog.Models

users = [
  user("chris", last_name: "Maier"),
  user("imbriaco", first_name: "Mark", last_name: "Imbriaco"),
  user("kevsmith", first_name: "Kevin", last_name: "Smith"),
  user("latitia", last_name: "Haskins"),
  user("mpeck", first_name: "Matt", last_name: "Peck"),
  user("shelton", last_name: "Davis"),
  user("vanstee", first_name: "Patrick", last_name: "Van Stee")
]

users
|> Enum.map(&with_chat_handle_for(&1, "Slack"))

permissions = Repo.all(Permission)
for user <- users do
  Enum.each(permissions, &Permittable.grant_to(user, &1))
end
