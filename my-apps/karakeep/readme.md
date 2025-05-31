# Karakeep

## Secrets

Apply the following secrets for first time set up

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: karakeep-secrets
  namespace: karakeep
type: Opaque
data:
  NEXTAUTH_SECRET: ""
  MEILI_MASTER_KEY: ""
  NEXT_PUBLIC_SECRET: ""
EOF
```

Then set the secret values.

If you need to convert to base64, here is a powershell command

```ps1
[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("yourSecretHere"))
```