## Sidecars

Sidecars are additional operating system processes that are run in the same container as a [process](#processes).

#### Use cases for sidecars

Sidecars are useful for any app processes that need to communicate with another within the same container or are otherwise dependent on each other. Some use cases are:
  
- Two or more processes that require access to a shared file
- An Application Performance Monitoring (APM) tool that attaches to a dependent app's processes
- Two or more processes that communicate via a local socket
  

#### Steps to create a sidecar
The recommended way to create sidecars for your app is with an [App Manifest](#app-manifest).

```yaml
 sidecars:
  - name: authenticator
    process_types: [ 'web', 'worker' ]
    command: bundle exec run-authenticator
  - name: performance monitor
      process_types: [ 'web' ]
      command: bundle exec run-performance-monitor
```


- **name** is a user defined identifier (unique per app)
- **process_types** is a list of app processes the sidecar will attach to. You can attach multiple sidecars to each process type your app uses
- **command** is the command used to start the sidecar

#### Current Limitations
- Start and stop order of app processes and their sidecars is undefined
- App processes and Sidecar processes are codependent: if either crashes or exits, the other will as well 
- Sidecars are currently not independently scalable (memory / disk) and share resources with the main app process and other sidecars within that container
- Sidecars only support PID based health checks; HTTP health-checks for sidecars are not currently supported

