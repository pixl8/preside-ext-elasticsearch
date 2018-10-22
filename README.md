# PresideCMS Extension: ElasticSearch

This is an extension for PresideCMS that provides APIs and a methodolgy for integrating full-text search with ElasticSearch.

Documentation is a work in progress, please visit the [PresideCMS slack channel](https://presidecms-slack.herokuapp.com/) for direct help with using this extension :).

## Installation

Install the extension to your application via either of the methods detailed below (Git submodule / CommandBox) and then enable the extension by opening up the Preside developer console and entering:

    extension enable preside-ext-elasticsearch
    reload all

### Git Submodule method

From the root of your application, type the following command:

    git submodule add https://github.com/pixl8/preside-ext-elasticsearch.git application/extensions/preside-ext-elasticsearch

### CommandBox (box.json) method

From the root of your application, type the following command:

    box install pixl8/preside-ext-elasticsearch#v1.1.9

