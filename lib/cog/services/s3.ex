defmodule Cog.Services.S3 do
  require Logger
  use Cog.GenService
  import Cog.Service.Helper
  @doc """
  When using this service, you must have the following env variables set:
    export AWS_ACCESS_KEY_ID=<Your AWS Access Key>
    export AWS_SECRET_ACCESS_KEY=<Your AWS Secret Access Key>
  """

  def service_init(_opts) do
    s3_access_info = Application.get_env(:cog, :aws_service)
    access_key_id = case Keyword.get(s3_access_info, :aws_access_key_id) do
      nil -> nil
      info -> String.to_char_list(info)
    end
    secret_access_key = case Keyword.get(s3_access_info, :aws_secret_access_key) do
      nil -> nil
      info -> String.to_char_list(info)
    end
    :erlcloud_s3.configure(access_key_id, secret_access_key)
    {:ok, :configured}
  end

  def handle_message(command, req, state) do
    response = case command do
      "list" -> list_buckets(req.parameters)
      "create" -> create_bucket(req.parameters["args"])
      "destroy" -> destroy_bucket(req.parameters["args"])
      "read" -> read_object(req.parameters["bucket"], req.parameters["file-key"])
      "write" -> write_object(req.parameters["bucket"], req.parameters["file-key"], req.parameters["content"])
      "remove" -> remove_object(req.parameters["bucket"], req.parameters["file-key"])
      _ -> "Unknown S3 command #{command}"
    end
    |> parse_response
    {:reply, response, req, state}
  end

  defp parse_response([buckets: []]), do: []
  defp parse_response([buckets: buckets]), do: format_entries(buckets)
  defp parse_response([[[name: _, creation_date: _]=result|_]|_]), do: format_entries(result)
  defp parse_response([name: _, prefix: _, marker: _, delimiter: _, max_keys: _, is_truncated: _, common_prefixes: _, contents: _]=result) do
    format_entries(result)
  end
  defp parse_response([etag: _, content_length: _, content_type: _, content_encoding: _, delete_marker: _, version_id: _, content: _]=result) do
    format_entries(result)
  end
  defp parse_response([version_id: _]), do: :ok
  defp parse_response([delete_marker: _, version_id: _]), do: :ok
  defp parse_response(:ok), do: :ok
  defp parse_response({:aws_error, {:socket_error, _}}), do: "Unable to connect to S3 service. Please be sure `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set."
  defp parse_response({:error, {_, _, _, reason}}), do: "Unable to complete the command. Reason: #{reason}"
  defp parse_response(res) do
    # Since error handling is not so great with s3 code, log any output that gets here
    Logger.debug("Received results: '#{res}'")
    "Oops. Something went wrong."
  end

  def desired_bucket([name: name, creation_date: _]=bucket, desired_name) do
    case name == String.to_char_list(desired_name) do
      true -> bucket
      false -> []
    end
  end

  def filter_bucket(bucket_res, tag) do
    for bucket_list <- bucket_res do
      case bucket_list do
        {:buckets, buckets} ->
          for bucket <- buckets, do: desired_bucket(bucket, tag)
        error -> error
      end
    end
  end

  def list_buckets(%{"show-obj" => bucket_name}) do
    :erlcloud_s3.list_objects(String.to_char_list(bucket_name))
  end
  def list_buckets(%{"tag" => tag}) do
    results = :erlcloud_s3.list_buckets()
    filter_bucket(results, tag)
  end
  def list_buckets(_) do
    :erlcloud_s3.list_buckets()
  end

  def create_bucket([]), do: "Please supply an all lowercase, unique name for the bucket that you want to create."
  def create_bucket([bucket_name|_]) do
    :erlcloud_s3.create_bucket(String.to_char_list(bucket_name))
  end

  def destroy_bucket([]), do: "Please supply an all lowercase, unique name for the bucket that you want to destroy."
  def destroy_bucket([bucketName|_]) do
    :erlcloud_s3.delete_bucket(String.to_char_list(bucketName))
  end

  def read_object(bucketName, filekey) do
    :erlcloud_s3.get_object(String.to_char_list(bucketName), String.to_char_list(filekey))
  end

  def write_object(bucketName, filekey, content) do
    :erlcloud_s3.put_object(String.to_char_list(bucketName), String.to_char_list(filekey), String.to_char_list(content))
  end

  def remove_object(bucketName, filekey) do
    :erlcloud_s3.delete_object(String.to_char_list(bucketName), String.to_char_list(filekey))
  end
end
