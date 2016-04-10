defmodule Cog.Repo.Migrations.InsertErrorTemplates do
  use Ecto.Migration
  alias Cog.Models.Template
  alias Cog.Repo

  def change do
    Repo.insert!(%Template{
      name: "unregistered_user",
      adapter: "any",
      source: """
      {{mention_name}}: I'm sorry, but either I don't have a Cog account for you, or your {{display_name}} chat handle has not been registered. Currently, only registered users can interact with me.

      You'll need to ask a Cog administrator to fix this situation and to register your {{display_name}} handle. {{#user_creators?}}The following users can help you right here in chat:{{#user_creators}} {{.}}{{/user_creators}}{{/user_creators?}}
      """
    })

    Repo.insert!(%Template{
      name: "error",
      adapter: "any",
      source: """
      An error has occurred.

      At `{{started}}`, {{initiator}} initiated the following pipeline, assigned the unique ID `{{id}}`:

          `{{{pipeline_text}}}`

      {{#planning_failure}}
      The pipeline failed planning the invocation:

          `{{{planning_failure}}}`

      {{/planning_failure}}
      {{#execution_failure}}
      The pipeline failed executing the command:

          `{{{execution_failure}}}`

      {{/execution_failure}}
      The specific error was:

          {{{error_message}}}

      """
    })
  end
end
