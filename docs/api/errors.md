# API Design Guide

## Errors

When a request responds with an error, it should always include the appropriate
HTTP status code for that error.

The error response should always include a top level of resource of `errors`
as an array. The errors array should contain only objects that match the error
format.

The response may optionally include other resources at the top level alongside
the `errors` array.

## Error Object

The following fields are required:

* `code` - an identifier for the type of error. Example: `application_error`,
  `invalid_submission`, `cog_error`

* `message` - a human readable error message. This will likely be displayed directly
  to the user so it should be worded properly.

The following fields are required in the object, but can be empty:

* `param` - if the error is directly tied to an attribute on a resource, include the
  resource attribute. For example, if user creation fails because the user's email
  is invalid, then `param` would be "email".

  If the param is given, you can assume that the message will be displayed
  alongside the param so it does not have to be included in the message. Eg:
  "Email is invalid". In this case, `param` would be "email" and `message`
  would be "is invalid".

* `id` - a unique identifier to the error

* `url` - a link that could be provided to the user for clarification on how to
  resolve the error
