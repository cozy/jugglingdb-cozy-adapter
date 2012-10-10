## About

*cozy-jugglindb-data* is an adapter for
[JugglingDB](https://github.com/1602/jugglingdb "JugglingDB") required by
cozy applications to use the Cozy Data System.

## Setup for RailwayJS

First add it to your project dependencies (package.json file), or install it 
directly:

    npm install jugglingdb-cozy-adapter

Then in your *config/database.json* file, add this:

    { 
        "driver":   "jugglingdb-cozy-adapter"
        "url": "http://localhost:7000"
    }

Url parameter is optional. Of course to work correctly, the adapter required
Cozy Data System and CouchDB up and running.

## Usage

Check 
[test file](https://github.com/mycozycloud/jugglingdb-cozy-adapter/blob/master/tests.coffee)
for documented usage of methods available in this adapter.
