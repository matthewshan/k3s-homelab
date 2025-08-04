# dockerconfig.json

Set the secret value as follows. Password can be a PAT (personal access token)

```json
{
    "auths": {
        "gitea": {
            "auth": "base64(username:password)"
        }
    }
}
```

Powershell for converting to base64
```ps1
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("username:password"))
```

Kubectl Secret
```sh
kubectl create secret generic gitea-pull-secret --from-file=dockerconfig.json --type=kubernetes.io/dockerconfig.json --namespace=minecraft
```