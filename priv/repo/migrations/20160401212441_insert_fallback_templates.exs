defmodule Cog.Repo.Migrations.InsertFallbackTemplates do
  use Ecto.Migration
  alias Cog.Models.Template
  alias Cog.Repo

  def change do
    # That extra newline is there for a reason. Mustache spec strips newlines
    # following a standalone partial. No idea why.
    Repo.insert!(%Template{
      name: "json",
      adapter: "slack",
      source: """
      ```
      {{> json}}

      ```
      """
    })

    Repo.insert!(%Template{
      name: "json",
      adapter: "hipchat",
      source: """
      /code
      {{> json}}
      """
    })

    Repo.insert!(%Template{
      name: "raw",
      adapter: "any",
      source: """
      {{> json}}
      """
    })

    Repo.insert!(%Template{
      name: "json",
      adapter: "any",
      source: """
      {{> json}}
      """
    })

    Repo.insert!(%Template{
      name: "text",
      adapter: "any",
      source: """
      {{> text}}
      """
    })
  end
end
