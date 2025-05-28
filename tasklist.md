# Task list

## Minecraft
- Get minecraft server working in WAN
  - VPS
  - DNS
- Minecraft server backups. Try deleting the stateful set and see what happens

## Other

- Local DNS
- Review and Cleanup of unwanted applications


## notes on file management

`kubectl exec -n mc-bedrock -it mc-bedrock-stateful-set-0 -- ls -la`

`kubectl exec -n mc-bedrock -it mc-bedrock-stateful-set-0 -- /bin/sh`

`kubectl cp mc-bedrock-stateful-set-0:/data ./mc-test -n mc-bedrock`

files

- db/
- level.dat
- level.dat_old
- levelname.txt


`data/worlds/Bedrock level`


`kubectl cp ./mc-load 'mc-bedrock-stateful-set-0:/data/worlds/Bedrock level' -n mc-bedrock`