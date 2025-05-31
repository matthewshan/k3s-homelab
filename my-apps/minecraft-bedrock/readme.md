# Minecraft Bedrock

## How to interact with server

Send commands

```sh
kubectl exec -n mc-bedrock mc-bedrock-stateful-set-0 -- send-command yourcommand
```

View server logs

```sh
kubectl logs -n mc-bedrock mc-bedrock-stateful-set-0
```

## How to Load a world

This process assumes you are managing this application with Argo CD.

1. Stop the pods
   - Locate the Kubernetes manifest file for the `mc-bedrock-stateful-set` (or Deployment) in your Git repository (e.g., `my-apps/minecraft-bedrock/manifest.yaml`).
   - Edit the file and change `spec.replicas` to `0`.
   - Commit and push this change to your Git repository.
   - Argo CD will sync this change and scale down the pods.
   - Example snippet from the manifest:
     ```yaml
     spec:
       replicas: 0 # Set to 0 to stop, 1 (or more) to start
     ```

2. Access the Volume Data via Longhorn and VM:
   a. **In Longhorn UI:**
      - Navigate to "Volumes".
      - Find the volume associated with your Minecraft server. The PersistentVolumeClaim (PVC) name for a StatefulSet pod is typically `<volumeClaimTemplate.name>-<StatefulSet.name>-<pod-index>`. For your setup (assuming `mc-bedrock-stateful-set` and `mc-data` volume claim template), this will be `mc-data-mc-bedrock-stateful-set-0`. The Longhorn Volume name in the UI will match this PVC name.
      - Select the volume and click "Attach". Choose the VM/node where you want to access the files (e.g., `k3s-ctl`) and confirm.
      - **Note:** The Longhorn UI will display the "Device Path" or "Path on Node" once attached. This is the path you'll use in the next steps (e.g., `/dev/longhorn/pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
   b. **On your VM/Node (via SSH):**
      - SSH into the VM you attached the volume to (e.g., `ssh pip@k3s-ctl`).
      - List the devices in `/dev/longhorn/` to confirm or find the device name if you didn't note it from the UI:

        ```bash
        ls -la /dev/longhorn/
        ```

        You should see an entry corresponding to the "Device Path" shown in the Longhorn UI, for example:
        `brw-rw----  1 root disk 8, 48 May 29 16:11 pvc-28046ad7-d257-461c-b1b7-cf121e7b2f17`
        Sometimes, Longhorn might also create a more user-friendly symlink like `/dev/longhorn/mc-data-mc-bedrock-stateful-set-0`. If it exists, you can use that too. Otherwise, use the `pvc-<uuid>` name.

      - Create a temporary mount point (if it doesn't already exist):

        ```bash
        sudo mkdir -p /mnt/minecraft_data
        ```

      - Mount the Longhorn volume. Replace `<device-name-from-longhorn>` with the actual device name (e.g., `pvc-28046ad7-d257-461c-b1b7-cf121e7b2f17` or `mc-data-mc-bedrock-stateful-set-0` if the symlink exists):

        ```bash
        sudo mount /dev/longhorn/<device-name-from-longhorn> /mnt/minecraft_data
        ```

      - You can now access your Minecraft server files (worlds, server.properties, etc.) in `/mnt/minecraft_data`. For example, to list files: `ls -la /mnt/minecraft_data/worlds/`.
      - **Important:** After you're done managing the files, unmount the directory:

        ```bash
        cd ~ # Ensure you are not in /mnt/minecraft_data
        sudo umount /mnt/minecraft_data
        ```

   c. **In Longhorn UI (again):**
      - Go back to the volume details and click "Detach". This makes the volume available for Kubernetes to use again.

3. (Optional) If you created a temporary mount point directory, you can remove it from your VM:
   ```bash
   sudo rmdir /mnt/minecraft_data
   ```

4. Start the pods:
   - Edit the Kubernetes manifest file for the `mc-bedrock-stateful-set` (or Deployment) in your Git repository (e.g., `my-apps/minecraft-bedrock/stateful-set.yaml`).
   - Change `spec.replicas` back to `1`.
   - Commit and push this change to your Git repository.
   - Argo CD will sync this change and restart your server.
     ```yaml
     spec:
       replicas: 1 # Set back to 1 (or more) to start
     ```