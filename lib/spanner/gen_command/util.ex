defmodule Spanner.GenCommand.Util do

  def format_error_message(command, error, stacktrace) do
    """

    It appears that the `#{command}` command crashed while executing, with the following error:

   ```#{inspect error}```

   Here is the stacktrace at the point where the crash occurred. This information can help the authors of the command determine the ultimate cause for the crash.

   ```#{inspect stacktrace, pretty: true}```
   """
  end
end
