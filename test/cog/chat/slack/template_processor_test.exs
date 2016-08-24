defmodule Cog.Chat.Slack.TemplateProcessorTest do
  use ExUnit.Case

  alias Cog.Chat.Slack.TemplateProcessor

  test "processes a list of directives" do
    directives = [
      %{name: "text",
        text: "This is a rendering test. First, let's try italics: "},
      %{name: "italic",
        text: "I'm italic text!"},
      %{name: "text",
        text: "\nThat was fun; now let's do bold: "},
      %{name: "bold",
        text: "BEHOLD! BOLD!"},
      %{name: "text",
        text: "\nFascinating. How about some fixed width text?  "},
      %{name: "fixed_width",
        text: "BEEP BOOP... I AM A ROBOT... BEEP BOOP"},
      %{name: "text",
        text: "\nWow, good stuff. And now... AN ASCII TABLE!\n\n"},
      %{name: "table",
        columns: ["Member", "Instrument"],
        rows: [["Geddy Lee", "Vocals, Bass, Keyboards"],
               ["Alex Lifeson", "Guitar"],
               ["Neal Peart", "Drums, Percussion"]]},
      %{name: "text",
        text: "\nHow do you like them apples?"}]

    rendered = TemplateProcessor.render(directives)
    expected = """
    This is a rendering test. First, let's try italics: _I'm italic text!_
    That was fun; now let's do bold: *BEHOLD! BOLD!*
    Fascinating. How about some fixed width text?  ```BEEP BOOP... I AM A ROBOT... BEEP BOOP```
    Wow, good stuff. And now... AN ASCII TABLE!

    ```+--------------+-------------------------+
    | Member       | Instrument              |
    +--------------+-------------------------+
    | Geddy Lee    | Vocals, Bass, Keyboards |
    | Alex Lifeson | Guitar                  |
    | Neal Peart   | Drums, Percussion       |
    +--------------+-------------------------+
    ```
    How do you like them apples?
    """ |> String.trim
    assert expected == rendered
  end
end
