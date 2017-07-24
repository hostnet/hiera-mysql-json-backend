[![Gem Version](https://badge.fury.io/rb/hiera-mysql-json-backend.png)](http://badge.fury.io/rb/hiera-mysql-json-backend)

## hiera-mysql-json-backend

Alternate MySQL backend for Hiera with json support

This is a backend for Hiera based on
[hiera-mysql-backend](https://github.com/Telmo/hiera-mysql-backend).

### What makes this backend different from the other mysql backends

This backend differs from
[hiera-mysql](https://github.com/crayfishx/hiera-mysql) and 
[hiera-mysql-backend](https://github.com/Telmo/hiera-mysql-backend) in that it
expects queries to return json. This json is then parsed and the resulting data
structure is given back to the lookup.

### Usage

Puppet client:

`/opt/puppetlabs/puppet/bin/gem install hiera-mysql-json-backend mysql2`

Puppet server:

`/opt/puppetlabs/bin/puppetserver gem install hiera-mysql-json-backend-jruby jdbc-mysql`

### Configuring hiera

The backend is configured like any other in the hiera.conf. Here is the
simplest possible example:

```yaml
---
:backends:
  - yaml
  - mysql_json

:yaml:
  :datadir: /etc/puppet/hieradata

:mysql_json:
  :datadir: /etc/puppet/hieradata

:hierarchy:
  - "%{::clientcert}"
  - "%{::custom_location}"
  - common

:logger: console
```

This will cause it to try to connect on localhost:3306 with no username and
password. This will probably not work. The following options can be set:

* `host`: mysql host (string)
* `port`: mysql port (int)
* `user`: mysql user (string)
* `pass`: mysql password (string)
* `database`: mysql database name (string)
* `datadir`: root of your `mysql_json` hierarchy (string)
* `only_for`: only perform queries if conditions in this section are met (hash)
* `ignore_json_parse_errors`: Do not raise an exception when the database
  contains invalid json (boolean, defaults to false)

A more complete example might contain:

```yaml
:mysql_json:
  :datadir: /etc/puppet/hierasql
  :host: db042.example.com
  :user: puppetserver
  :pass: secret123
  :port: 3306
  :ignore_json_parse_errors: true # why why why...
  :only_for:
    :fqdn:
      - '^vagrant.+'
      - '^node\d+\.someservice\.example\.com$'
    :domain:
      - '^vagrant.+

```

This will perform lookups if any of the given conditions are met:

* The nodes fqdn fact starts with 'vagrant'
* The nodes fqdn fact looks like node01.someservice.example.com
* The nodes domain fact starts with 'vagrant'

Any node fact may be used to build these conditions.

Note that putting something in the list that always matches makes the whole
`only_for` block useless.

### Defining queries

Queries are defined in he poorly named sql files. These  are really yaml files
where the key is the lookup key and the value is the SQL statement (it accepts
interpolation)

As of version 0.0.4 you can also add connection information to these sql files,
this allows you to connect to different databases. This is optional if no
connection information is found it will use the default defined in your
hiera.yaml config.

Lets assume your _datadir_ is `/etc/puppet/hieradata/` and your hierarchy for
hiera just have a common. hiera-mysql-backend would look for
/etc/puppet/hieradata/common.sql the common.sql would look like:

```yaml
---
# This is optional, if not present it will use the default connection info from hiera.yaml
:dbconfig:
  :host: database.example.com
  :user: hieratest
  :pass: sekret
  :database: testhieradb
  :port: 44445

applications: SELECT value FROM applications WHERE host='%{fqdn}';
```

If `host` is not defined it will use `localhost` as default.

If `port` is not defined it will use the default `3306` mysql port

Running `hiera applications` would run the query against the configured
database, parse the result as json and return the resulting data structure. If
all you want is a string, strings are valid json, too.


### Error handling

When encountering invalid json, it will raise an exception, which would in turn
cause catalog compilation to fail. You can disable this behaviour by setting
`ignore_json_parse_errors`.

When no results are returned by your query, it will return nil.

When multiple results are returned by your query, it will return nil. A future
version will introduce `ignore_multiple_results`, defaulting to true, to make
it possible to trigger a catalog compilation in this case.


## Known issues

1. Multiple results are currently silently ignored.
1. It always return an Array of hashes regardless of the number of items returned. (I did this on purpose because it is what I needed but I may be persuaded to do otherwise)
2. This README is poorly written.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
