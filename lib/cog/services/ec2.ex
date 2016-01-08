defmodule Cog.Services.EC2 do
  require Logger
  use Cog.GenService
  import Cog.Service.Helper
  @doc """
  When using this service, you must have the following env variables set:
    export AWS_ACCESS_KEY_ID=<Your AWS Access Key>
    export AWS_SECRET_ACCESS_KEY=<Your AWS Secret Access Key>
  """

  import Record
  defrecord :ec2_instance_spec, Record.extract(:ec2_instance_spec, from_lib: "erlcloud/include/erlcloud_ec2.hrl")

  def service_init(_opts) do
    ec2_access_info = Application.get_env(:cog, :aws_service)
    access_key_id = case Keyword.get(ec2_access_info, :aws_access_key_id) do
      nil -> nil
      info -> String.to_char_list(info)
    end
    secret_access_key = case Keyword.get(ec2_access_info, :aws_secret_access_key) do
      nil -> nil
      info -> String.to_char_list(info)
    end
    :erlcloud_ec2.configure(access_key_id, secret_access_key)
    {:ok, :configured}
  end

  def handle_message(command, req, state) do
    response = case command do
      "list" -> do_listing(req.parameters) |> parse_response
      "launch" -> launch_instance(req.parameters["ami"], req.parameters["key"], req.parameters["type"], req.parameters["zone"])
      "terminate" -> do_terminate(req.parameters["instance-id"])
      "tag" -> do_tag(req.parameters["options"]["instance-id"], req.parameters["args"])
      "untag" -> do_untag(req.parameters["options"]["instance-id"], req.parameters["args"])
      _ -> "Unknown EC2 command #{command}"
    end

    {:reply, response, req, state}
  end

  defp do_listing(%{"tag" => tag}) do
    case String.split(tag, ":", parts: 2) do
      [key] -> describe_instances([], ["tag-key": [key]])
      [key, value] -> describe_instances([], ["tag-key": [key], "tag-value": [value]])
    end
  end
  defp do_listing(_) do
    describe_instances([], [])
  end

  defp do_untag(instance_id, tags) do
    tags = Enum.map(tags, &gather_tag_pair(&1))
    case untag_instance([instance_id], tags) do
      {:ok, _} -> untag_response(tags, instance_id)
      error -> parse_response(error)
    end
  end

  defp do_tag(instance_id, tags) do
    tags = Enum.map(tags, &gather_tag_pair(&1))
    case tag_instance([instance_id], tags) do
      {:ok, _} -> "Tagged EC2 instance #{instance_id} with #{inspect tags}"
      error -> parse_response(error)
    end
  end

  defp do_terminate(instance_id) do
    case terminate_instance(instance_id) do
      {:ok, _} -> "Terminated instance #{instance_id}"
      error -> parse_response(error)
    end
  end

  defp untag_response([], instance_id), do: "Removed all tags from EC2 instance #{instance_id}"
  defp untag_response(tags, instance_id), do: "Removed the following tags from EC2 instance #{instance_id}: #{inspect tags}"

  def gather_tag_pair(tag) do
    case String.split(tag, ":", parts: 2) do
      [value] -> {"Name", value}
      [key, value] -> {key, value}
    end
  end

  def launch_instance(ami, key, type, zone) do
    create_instance_spec(ami, key, type, zone)
    |> run_instances
    |> parse_response
  end

  defp parse_response({:ok, []}), do: []
  defp parse_response({:ok, response}), do: format_entries(response)
  defp parse_response({:error, {:socket_error, _}}), do: "Unable to connect to EC2 service. Please be sure `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set."
  defp parse_response({:error, {_, _, _, reason}}), do: "Unable to complete the command. Reason: #{reason}"
  defp parse_response(_), do: "Oops. Something went wrong."

  # Using Records - which from my understanding is not recommended
  def create_instance_spec(ami, key, type, zone) do
    ec2_instance_spec(
      image_id: ami,
      key_name: key,
      instance_type: type,
      availability_zone: zone
    )
  end

  defp describe_instances(instance_ids, query) do
    :erlcloud_ec2.describe_instances(instance_ids, query)
  end

  defp run_instances(instance_spec) do
    :erlcloud_ec2.run_instances(instance_spec)
  end

  defp terminate_instance(instance_id) do
    :erlcloud_ec2.terminate_instances([instance_id])
  end

  defp tag_instance(instance_ids, tags) do
    :erlcloud_ec2.create_tags(instance_ids, tags)
  end

  defp untag_instance(instance_ids, tags) do
    :erlcloud_ec2.delete_tags(instance_ids, tags)
  end
end
