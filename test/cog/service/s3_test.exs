defmodule Cog.Services.S3Test do
  use ExUnit.Case, async: true
  import Cog.Services.S3

  test "populated bucket if it's the correct bucketname" do
    assert [name: 'mybucket', creation_date: 'Do not care'] = desired_bucket([name: 'mybucket', creation_date: 'Do not care'], "mybucket")
  end

  test "returning an empty bucket if bucketname does not match" do
    assert [] = desired_bucket([name: 'notmybucket', creation_date: 'Huh'], "mybucket")
  end

  test "returning a filtered bucket from a list of buckets" do
    bucket_res = [buckets: [[name: 'mybucket', creation_date: 'Do not care'], 
                            [name: 'notmybucket', creation_date: 'Huh'],
                            [name: 'memebucket', creation_date: 'YepYep']]]
    assert [[[name: 'mybucket', creation_date: 'Do not care'], [], []]] = filter_bucket(bucket_res, "mybucket")
  end

  test "returning an error if a bucket is not received" do
    assert [:error, 'Expect some error during the test'] = filter_bucket([:error, 'Expect some error during the test'], "somebucket")
  end
end
