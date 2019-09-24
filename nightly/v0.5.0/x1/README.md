# Nightly testnet

This Nightly Testnet was triggered to test v0.5.0 and is deployment .

## How to connect to this ephemeral testnet

1. download [v0.5.0](https://github.com/input-output-hk/jormungandr/releases/v0.5.0) or later;
2. prepare your [node configuration file](https://input-output-hk.github.io/jormungandr/quickstart/02_passive_node.html#the-node-configuration)
   (it is possible there have been changes in the documentation since this release);
3. start jormungandr with the node's configuration file and the appropriate `genesis-block-hash`

### Genesis Block Hash

This is the hash that you need to use when signing transactions or to start the node

`7ddb2b877cf75b150d000ade08e277ce74d4411290fa6c47a71c27e38e7d8aa4`

### start suggestion

```js
jormungandr \
    --genesis-block-hash 7ddb2b877cf75b150d000ade08e277ce74d4411290fa6c47a71c27e38e7d8aa4 \
    --trusted-peer <ADD TRUSTED PEER ADDRESS HERE>
```

### Example configuration file

If you want to add REST API monitoring, use:

```yaml
rest:
  listen: "127.0.0.1:8080"
```

# Info

Jormungandr v0.5.0

* full version: `jormungandr 0.5.0 (HEAD-98922c7, release, macos [x86_64]) - [rustc 1.37.0 (eae3437df 2019-08-13)]`
* md5: `e0ab518a2cc7afb5fef404126df8316e`

jcli v0.5.0

* full version: `jcli 0.5.0 (HEAD-98922c7, release, macos [x86_64]) - [rustc 1.37.0 (eae3437df 2019-08-13)]`
* md5: `54ffadd87867d846cc07a8aeb1d8b6e0`

