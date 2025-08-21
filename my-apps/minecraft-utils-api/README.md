
# Minecraft Utils API

Be VERY careful about exposing this to the internet....

# Secrets

```bash
kubectl create secret generic minecraft-utils-api-secret --namespace minecraft-utils-api --from-literal=IpAddress="" --from-literal=RconPort="" --from-literal=RconPassword=""
```
