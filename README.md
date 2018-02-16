# cf-zero-downtime-deploy

This script deploys cloud foundry app using blue-green deployment approach to ensure 100% uptime. The script was tested with Pivotal Cloud Foundry, but will work with any other CF environment as well. The script spins up second container instance just for brief amount of time keeping hosting costs low.

## Usage
```
  cf-zero-downtime-deploy.sh -n appname -d domain [-s string-to-check-for-health] [-h health-check-route] [-t https(s)] [-p "cf push params"]
  -n  application name already deployed to CF
  -d  domain i.e. cf-staging.mydomain.com
  -s  text to check for on the healh check page
  -h  health check route; default is /
  -t  protocol for healthcheck; default is https
  -p  cf push params
```

### Example
```
./cf-zero-downtime-deploy.sh -n my-awesome-app -d cf-staging.coolapps.io -s "Status: OK" -h "/ping" -t https -p "-b my-buildpack -m 256M"
```

## Installation

Before running the script make sure your app is deployed and running using `cf push` command. This is needed just for the very first deployment.

```
curl https://raw.githubusercontent.com/FreshRealm/cf-zero-downtime-deploy/master/cf-zero-downtime-deploy.sh | sudo tee -a ./cf-zero-downtime-deploy.sh
sudo chmod +x ./cf-zero-downtime-deploy.sh
```

## How it works

Let's assume there is a `my-awesome-app` app running on `coolapps.io` domain accessible via `https://my-awesome-app.coolapps.io`. There is a `/hello` route that is used for monitoring and app status reporting.

When deploying new version of `my-awesome-app` the deployment script creates random 6 chracter app-id that is attached to the app name - spinning up new container that listens on `https://my-awesome-app-q7V9wa.coolapps.io`. When the new app is succesfully deployed, current production route is mapped to it making the app temporarily load balanced between the old and new version. However, the old app route is unmapped immediately making all new requests to go to the new app. The old application is deleted and new app is renamed from `my-awesome-app-q7V9wa` to `my-awesome-app`.

### Error handling
When there is an error during the deployment, new app is automatically renamed to my-awesome-app-q7V9wa-failed giving you a chance to see the logs for further investigation. 

### Smoke tests
Smoke tests are preliminary testing to reveal simple failures in software deployment. Simple way is to create **/ping** page that connects to database, or other resources to ensure that external dependencies are accessible before turning the app into production mode. 

Providing `-h` flag for route and `-s` flag for search string will run the smoke test after deployment and abort mapping production routes if it fails. Further providing -t http will run the smoke test on non-secure url.

__Note__: 
Using custom domains on CF requires DNS configuration with CNAME record for each app pointing to the default CF load balancer endpoint. Using `*` in CNAME record might not work for all browsers or operating systems resulting into DNS lookup failure for `my-awesome-app-q7V9wa.coolapps.io` url. 
As a workaround, the script gets IP address of the current app and uses that to load new app with new hostname on old IP address.


## References

* [Blue Green Deploy Docs](https://docs.cloudfoundry.org/devguide/deploy-apps/blue-green.html)
* [CF Cli](https://docs.cloudfoundry.org/cf-cli/cf-help.html)
* [CF Smoke Tests](https://github.com/cloudfoundry/cf-smoke-tests)