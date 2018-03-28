const util = require('util');
const exec = util.promisify(require('child_process').exec);

async function getAllRoutes() {
  const { stdout, stderr } = await exec('cf routes');
  if (stderr || !stdout) {
    console.error('Error downloading routes', stderr);
    process.exit(1);
  }
  return stdout.split('\n');
}

async function selectSpace(space) {
  const { stdout, stderr } = await exec('cf t -s ' + space);
  if (stderr) {
    console.error('Error selecting space', stderr);
    process.exit(1);
  }
}

async function deleteRoutes(routes) {
  for (const route of routes) {
    const parts = route.split(/\s+/);
    if (parts[1] && !parts[3]) {
      const command = `cf delete-route ${parts[2]} --hostname ${parts[1]} -f`;
      console.log(command);
      await exec(command);
    }
  }
}

var args = process.argv.slice(2);
if (!args[0]) {
  console.log('Provide CF space - test|staging|epic|production');
  process.exit(1);
}

selectSpace(args[0]).then(() => {
  return getAllRoutes()
}).then((routes) => {
  return deleteRoutes(routes);
}).catch((err) => {
  console.error(err);
  process.exit(1);
});