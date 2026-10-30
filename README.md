# ElasticSearch extension for Preside

This is an extension for the Preside Platform that provides APIs and a methodolgy for integrating full-text search with ElasticSearch.

## Installation

From the webroot of your application:

```
box install preside-ext-elasticsearch
```

## ElasticSearch engine versions

A single release of the extension supports multiple ElasticSearch engine versions. Set the version of the engine you are using, either with an environment variable:

```
ELASTICSEARCH_VERSION=1.7
```

or in your application's `Config.cfc`:

```cfc
settings.elasticSearchConfig.engineVersion = "1.7";
```

The default is `6.3`. Currently supported versions:

| Version | Dialect | Notes |
|---------|---------|-------|
| `1.7`   | `Es1Dialect` | One mapping per document type. `query_string` searches. The `fuzziness` and `prefixLength` search arguments are ignored. |
| `6.3`   | `Es6Dialect` | A single `doc` mapping, with the document type stored in a `type` keyword field. `multi_match` searches. |

The extension uses the dialect registered for the highest version that is less than or equal to the configured version, so `6.8` uses the `6.3` dialect. The admin search engine page shows the configured version next to the version reported by the server, and warns when their major versions differ.

Changing the engine version requires an application reload, followed by a rebuild of your search indexes.

### Supporting a new ElasticSearch version

Everything that differs between engine versions lives in a "dialect" component in `services/dialects/`. To support a new version:

1. Create a dialect that extends the closest existing dialect (e.g. `Es7Dialect extends Es6Dialect`), overriding only what has changed.
2. Register it in `config/Config.cfc` (`settings.elasticSearchConfig.dialects[ "7.10" ] = "Es7Dialect"`). Applications can also register their own dialects using a full component path.
3. Add specs for the new version to the unit tests.

### Other settings

| Setting (`settings.elasticSearchConfig.*`) | Default | Description |
|---|---|---|
| `indexPageSize` | `100` | Number of records sent to ElasticSearch in each batch when rebuilding an index. |
| `searchPageSize` | `10` | Default page size for `search()`. On ElasticSearch 1.x this falls back to `indexPageSize`, if that is set, for compatibility with the 1.x releases of this extension. |
| `groupByRecordIdOnly` | `false` | Group by the record ID instead of using Preside's `autoGroupBy` when fetching records for indexing. |
| `indexExpiryUnit` / `indexExpiryMeasure` | `d` / `1` | How long an index rebuild can run before it is considered to have timed out. |

The extension also adds a scheduled task, *Rebuild search indexes*, which runs daily at 4am.

## Documentation

Documentation is a work in progress. For now, we intend to use the [Github Wiki](https://github.com/pixl8/preside-ext-elasticsearch/wiki) and could do with all the help we can get. Contributions very welcome!

## Versioning

We use [SemVer](https://semver.org) for versioning. As of **7.0**, the extension is universal and covers multiple versions of ElasticSearch.

For the versions available, see the [tags on this repository](https://github.com/pixl8/preside-ext-elasticsearch/releases). Project releases can also be found and installed from [Forgebox](https://forgebox.io/view/preside-ext-elasticsearch)

## License

This project is licensed under the GPLv2 License - see the [LICENSE.txt](https://github.com/pixl8/Preside-CMS/blob/master/LICENSE.txt) file for details.

## Authors

The project is maintained by [The Pixl8 Group](https://www.pixl8.co.uk). The lead developer is [Dominic Watson](https://github.com/DominicWatson).

## Code of conduct

We are a small, friendly and professional community. For the eradication of doubt, we publish a simple [code of conduct](https://github.com/pixl8/preside-ext-elasticsearch/blob/master/CODE_OF_CONDUCT.md) and expect all contributors, users and passers-by to observe it.