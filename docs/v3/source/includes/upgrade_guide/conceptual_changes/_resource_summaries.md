### Resource Summaries

V2 provided several endpoints that returned rolled-up summaries (e.g.
`/v2/spaces/:guid/summary` for a space summary, or
`/v2/organizations/:guid/summary` for an organization summary). These endpoints
have been largely removed from V3 because they were expensive for Cloud
Controller to compute and because they often returned more information than
clients actually needed. They were convenient, so it was easy for clients to
rely on them even when they only needed a few pieces of information.

In V3, to enable better API performance overall, these usage patterns are
deliberately disallowed. Instead, clients are encouraged to think more carefully
about which information they really need and to fetch that information with
multiple API calls and/or by making use of the [`include`
parameter](#including-associated-resources) on certain endpoints.

In V2, summary endpoints provided a way to fetch all resources associated with a
parent resource. In V3, fetch the summary though the associated resource and
filter by the parent resource. See below for examples of summaries in V3.

#### Replacing the space summary endpoint

- To fetch all apps in a space, use `GET /v3/apps?space_guids=<space-guid>`.
  Passing `include=space` will include the space resource in the response body.
- To fetch all service instances in a space use `GET
  /v3/service_instances?space_guids=<space-guid>`. You may be able to pass the
  experimental `fields` parameter to include related information in the response
  body.

#### Replacing the user summary endpoint

- The user summary was useful for finding organizations and spaces where a user
had roles. In V3, with the introduction of the role resource, you can use `GET
/v3/roles?user_guids=<user-guid>` to list a user's roles. Passing
`include=space,organization` will include the relevant spaces and organizations
in the response body.

#### Usage summary endpoints

There are still a couple of endpoints in V3 that provide a basic summary of
instance and memory usage. See the [org summary](#get-usage-summary) and
[platform summary](#get-platform-usage-summary) endpoints.
