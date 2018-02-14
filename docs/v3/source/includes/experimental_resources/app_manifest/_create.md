### Apply an app manifest

```
Example Request
```

```shell
curl "https://api.example.org/v3/apps/[guid]/actions/apply_manifest" \
  -X POST \
  -H "Authorization: bearer [token]" \
  -H "Content-type: application/x-yaml" \
  --data-binary @/path/to/manifest.yml
```

```
Example Response
```

```http
HTTP/1.1 202 Accepted
Location: https://api.example.org/v3/jobs/[guid]
```

#### Definition
`POST /v3/apps/:guid/actions/apply_manifest`

#### Allowed Roles
 |
--- | ---
Space Developer |
Admin |
